// ChatRepository offline machinery: read cache (network-first, cache on
// connectivity failure), send-queue (enqueue on offline, flush oldest-first
// with the original idempotency keys), and the offline-error classifier.
// Real in-memory Drift + mocked ChatApi.

import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/chat/chat_api.dart';
import 'package:mantle_companion/data/chat/chat_message.dart';
import 'package:mantle_companion/data/chat/chat_repository.dart';
import 'package:mantle_companion/data/db/app_database.dart';
import 'package:mocktail/mocktail.dart';

class MockChatApi extends Mock implements ChatApi {}

const _slug = 'saskia';

DioException _offline() => DioException(
      requestOptions: RequestOptions(path: '/api/assistant/turn'),
      type: DioExceptionType.connectionError,
    );

DioException _serverError() => DioException(
      requestOptions: RequestOptions(path: '/api/assistant/turn'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/api/assistant/turn'),
        statusCode: 500,
      ),
    );

Map<String, dynamic> _row(String id, {String text = 'hello'}) => {
      'id': id,
      'direction': 'outbound',
      'text': text,
      'createdAt':
          DateTime.utc(2026, 7, 1).add(Duration(minutes: int.parse(id.substring(1)))).toIso8601String(),
    };

ChatMessage _parsed(Map<String, dynamic> j) => ChatMessage(
      id: j['id'] as String,
      direction: MessageDirection.outbound,
      text: (j['text'] as String?) ?? '',
      createdAt: DateTime.parse(j['createdAt'] as String),
    );

void main() {
  late MockChatApi api;
  late AppDatabase db;
  late ChatRepository repo;

  setUp(() {
    api = MockChatApi();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ChatRepository(api, db);
    when(() => api.messageFromHistory(any())).thenAnswer(
      (inv) => _parsed(inv.positionalArguments.single as Map<String, dynamic>),
    );
  });

  tearDown(() async => db.close());

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('history read cache', () {
    test('a fetched latest page is cached and served when offline', () async {
      when(() => api.fetchHistoryRaw(
            before: any(named: 'before'),
            limit: any(named: 'limit'),
            agentSlug: _slug,
          )).thenAnswer((_) async => [_row('m0'), _row('m1')]);

      final online = await repo.history(agentSlug: _slug);
      expect(online.fromCache, isFalse);
      expect(online.messages.map((m) => m.id), ['m0', 'm1']);

      // Network dies — same call now serves the cache, flagged.
      when(() => api.fetchHistoryRaw(
            before: any(named: 'before'),
            limit: any(named: 'limit'),
            agentSlug: _slug,
          )).thenThrow(_offline());

      final offline = await repo.history(agentSlug: _slug);
      expect(offline.fromCache, isTrue);
      expect(offline.messages.map((m) => m.id), ['m0', 'm1']);
    });

    test('an empty cache rethrows the network error', () async {
      when(() => api.fetchHistoryRaw(
            before: any(named: 'before'),
            limit: any(named: 'limit'),
            agentSlug: _slug,
          )).thenThrow(_offline());

      expect(() => repo.history(agentSlug: _slug),
          throwsA(isA<DioException>()));
    });

    test('a server error (non-offline) never serves the cache', () async {
      when(() => api.fetchHistoryRaw(
            before: any(named: 'before'),
            limit: any(named: 'limit'),
            agentSlug: _slug,
          )).thenAnswer((_) async => [_row('m0')]);
      await repo.history(agentSlug: _slug);

      when(() => api.fetchHistoryRaw(
            before: any(named: 'before'),
            limit: any(named: 'limit'),
            agentSlug: _slug,
          )).thenThrow(_serverError());

      expect(() => repo.history(agentSlug: _slug),
          throwsA(isA<DioException>()));
    });

    test('the cache prunes to the newest rows per agent', () async {
      final many = [
        for (var i = 0; i < AppDatabase.chatCacheKeep + 40; i++) _row('m$i'),
      ];
      when(() => api.fetchHistoryRaw(
            before: any(named: 'before'),
            limit: any(named: 'limit'),
            agentSlug: _slug,
          )).thenAnswer((_) async => many);
      await repo.history(agentSlug: _slug, limit: many.length);

      final cached = await db.cachedChatRows(_slug);
      expect(cached, hasLength(AppDatabase.chatCacheKeep));
    });
  });

  group('send queue', () {
    void stubSendOffline() {
      when(() => api.sendTurn(
            any(),
            agentSlug: any(named: 'agentSlug'),
            attachment: any(named: 'attachment'),
            cancelToken: any(named: 'cancelToken'),
            idempotencyKey: any(named: 'idempotencyKey'),
            location: any(named: 'location'),
          )).thenThrow(_offline());
    }

    test('a text-only offline send enqueues under its idempotency key',
        () async {
      stubSendOffline();

      await expectLater(
        repo.send('hi there',
            agentSlug: _slug, idempotencyKey: 'turn-key-1'),
        throwsA(isA<TurnQueuedOffline>()
            .having((e) => e.turnId, 'turnId', 'turn-key-1')),
      );

      final rows = await db.outboxTurnsFor(_slug);
      expect(rows.single.id, 'turn-key-1');
      expect(rows.single.body, 'hi there');
    });

    test('a server 500 does NOT enqueue (existing failed path)', () async {
      when(() => api.sendTurn(
            any(),
            agentSlug: any(named: 'agentSlug'),
            attachment: any(named: 'attachment'),
            cancelToken: any(named: 'cancelToken'),
            idempotencyKey: any(named: 'idempotencyKey'),
            location: any(named: 'location'),
          )).thenThrow(_serverError());

      await expectLater(
        repo.send('hi', agentSlug: _slug, idempotencyKey: 'k'),
        throwsA(isA<DioException>()),
      );
      expect(await db.outboxTurnsFor(_slug), isEmpty);
    });

    test('flushOutbox replays oldest-first with the original keys and stops '
        'at a connectivity failure', () async {
      await db.enqueueOutboxTurn(id: 'k1', agentSlug: _slug, body: 'first');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.enqueueOutboxTurn(id: 'k2', agentSlug: _slug, body: 'second');

      final sent = <String>[];
      when(() => api.sendTurn(
            any(),
            agentSlug: any(named: 'agentSlug'),
            attachment: any(named: 'attachment'),
            cancelToken: any(named: 'cancelToken'),
            idempotencyKey: any(named: 'idempotencyKey'),
            location: any(named: 'location'),
          )).thenAnswer((inv) async {
        final key = inv.namedArguments[#idempotencyKey] as String;
        if (key == 'k2') throw _offline();
        sent.add(key);
        return const TurnAccepted('k1');
      });

      final delivered = await repo.flushOutbox(_slug);
      expect(delivered, 1);
      expect(sent, ['k1']);
      // k1 delivered and removed; k2 still queued for the next flush.
      final remaining = await db.outboxTurnsFor(_slug);
      expect(remaining.single.id, 'k2');
    });

    test('a poisoned row (server rejects) is dropped after maxAttempts',
        () async {
      await db.enqueueOutboxTurn(id: 'bad', agentSlug: _slug, body: 'nope');
      when(() => api.sendTurn(
            any(),
            agentSlug: any(named: 'agentSlug'),
            attachment: any(named: 'attachment'),
            cancelToken: any(named: 'cancelToken'),
            idempotencyKey: any(named: 'idempotencyKey'),
            location: any(named: 'location'),
          )).thenThrow(_serverError());

      await repo.flushOutbox(_slug); // attempt 1 — kept
      expect(await db.outboxTurnsFor(_slug), hasLength(1));
      await repo.flushOutbox(_slug); // attempt 2 — kept
      expect(await db.outboxTurnsFor(_slug), hasLength(1));
      await repo.flushOutbox(_slug); // attempt 3 — dropped
      expect(await db.outboxTurnsFor(_slug), isEmpty);
    });
  });

  group('isOfflineError', () {
    test('classifies connectivity vs server errors', () {
      expect(isOfflineError(_offline()), isTrue);
      expect(
        isOfflineError(DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.unknown,
          error: const SocketException('down'),
        )),
        isTrue,
      );
      expect(isOfflineError(_serverError()), isFalse);
      expect(
        isOfflineError(DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.receiveTimeout,
        )),
        isFalse, // server may have the turn — the idempotent retry covers it
      );
      expect(isOfflineError(Exception('other')), isFalse);
    });
  });
}
