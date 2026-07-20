// ChatController (per-agent family): history load, scroll-up paging, optimistic
// send (legacy + live streaming) — with a mocked repository.

import 'dart:async';

import 'package:dio/dio.dart'
    show CancelToken, DioException, DioExceptionType, RequestOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/chat/chat_api.dart';
import 'package:mantle_companion/data/chat/chat_message.dart';
import 'package:mantle_companion/data/chat/chat_repository.dart';
import 'package:mantle_companion/data/chat/conversation_stream.dart';
import 'package:mantle_companion/data/db/app_database.dart';
import 'package:mantle_companion/data/chat/turn_event.dart';
import 'package:mantle_companion/features/chat/chat_controller.dart';
import 'package:mantle_companion/features/settings/settings_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

const _slug = 'saskia';

ChatMessage _msg(String id, MessageDirection d, String t, {DateTime? at}) =>
    ChatMessage(id: id, direction: d, text: t, createdAt: at ?? DateTime(2026));

TurnEvent _ev(int seq, String type, Map<String, dynamic> data, {int round = 0}) =>
    TurnEvent(v: 1, turnId: 'turn-1', seq: seq, round: round, type: type, data: data);

/// A full page of distinct outbound messages, oldest-first, timestamped in
/// ascending order so paging cursors are meaningful.
List<ChatMessage> _page(String prefix, int n) => [
      for (var i = 0; i < n; i++)
        _msg('$prefix$i', MessageDirection.outbound, '$prefix$i',
            at: DateTime(2026, 1, 1).add(Duration(minutes: i))),
    ];

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2000));
    registerFallbackValue(CancelToken());
  });

  late MockChatRepository repo;
  late MockSettingsRepository settings;
  setUp(() {
    repo = MockChatRepository();
    settings = MockSettingsRepository();
    // Location sharing off by default — send() reads this and attaches nothing.
    when(() => settings.locationSharing()).thenAnswer((_) async => false);
    // Offline machinery: empty outbox and nothing to flush unless a test
    // stubs otherwise.
    when(() => repo.queuedTurns(any())).thenAnswer((_) async => const []);
    when(() => repo.flushOutbox(any())).thenAnswer((_) async => 0);
  });

  // The controller now always passes a (real) cancelToken to repo.send, so the
  // stubs match on it. Helper keeps the matcher noise out of each test.
  When<Future<SendTurnResponse>> whenSend() => when(() => repo.send(
        any(),
        agentSlug: any(named: 'agentSlug'),
        attachment: any(named: 'attachment'),
        cancelToken: any(named: 'cancelToken'),
        idempotencyKey: any(named: 'idempotencyKey'),
        location: any(named: 'location'),
      ));

  // Pump real microtasks until [pred] holds (or a cap), for stepping a streamed
  // turn that's driven through a StreamController.
  Future<void> pumpUntil(
    ProviderContainer c,
    bool Function(ChatState) pred,
  ) async {
    for (var i = 0; i < 50; i++) {
      final s = c.read(chatControllerProvider(_slug)).value;
      if (s != null && pred(s)) return;
      await Future<void>.delayed(Duration.zero);
    }
  }

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        settingsRepositoryProvider.overrideWithValue(settings),
        // No live SSE in unit tests — an empty stream keeps the listen inert.
        conversationEventsProvider.overrideWith(
          (ref) => const Stream<ConversationEvent>.empty(),
        ),
      ],
    );
    // Keep the autoDispose provider alive across the test's async gaps (a turn
    // streamed through pumpUntil yields to the loop, which would otherwise let
    // the provider dispose mid-flight).
    c.listen(chatControllerProvider(_slug), (_, _) {});
    addTearDown(c.dispose);
    return c;
  }

  // One stub branching on the cursor: null `before` → latest page, else older.
  void stubHistory(List<ChatMessage> latest, [List<ChatMessage>? older]) {
    when(() => repo.history(
          before: any(named: 'before'),
          limit: any(named: 'limit'),
          agentSlug: any(named: 'agentSlug'),
        )).thenAnswer((inv) async => HistoryPage(
        messages:
            inv.namedArguments[#before] == null ? latest : (older ?? latest)));
  }

  test('build loads the latest page; hasMore when a full page returns', () async {
    stubHistory(_page('a', chatPageSize));

    final c = makeContainer();
    final state = await c.read(chatControllerProvider(_slug).future);

    expect(state.messages, hasLength(chatPageSize));
    expect(state.hasMore, isTrue);
    expect(state.loadingMore, isFalse);
  });

  test('a short first page sets hasMore = false', () async {
    stubHistory(_page('a', 3));

    final c = makeContainer();
    final state = await c.read(chatControllerProvider(_slug).future);

    expect(state.messages, hasLength(3));
    expect(state.hasMore, isFalse);
  });

  test('loadMore prepends the older page, paged from the oldest cursor', () async {
    final first = _page('new', chatPageSize);
    final older = _page('old', chatPageSize);
    stubHistory(first, older);

    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    await c.read(chatControllerProvider(_slug).notifier).loadMore();

    final state = c.read(chatControllerProvider(_slug)).value!;
    expect(state.messages, hasLength(chatPageSize * 2));
    expect(state.messages.first.id, 'old0');
    expect(state.messages.last.id, 'new${chatPageSize - 1}');
    expect(state.hasMore, isTrue);

    final cursors = verify(() => repo.history(
          before: captureAny(named: 'before'),
          limit: any(named: 'limit'),
          agentSlug: any(named: 'agentSlug'),
        )).captured;
    expect(cursors, [null, first.first.createdAt]);
  });

  test('loadMore is a no-op when there is nothing older', () async {
    stubHistory(_page('a', 3));

    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    await c.read(chatControllerProvider(_slug).notifier).loadMore();

    expect(c.read(chatControllerProvider(_slug)).value!.messages, hasLength(3));
    verify(() => repo.history(
          before: any(named: 'before'),
          limit: any(named: 'limit'),
          agentSlug: any(named: 'agentSlug'),
        )).called(1);
  });

  test('loadMore de-dupes overlapping ids across pages', () async {
    final first = _page('a', chatPageSize);
    final older = [..._page('b', chatPageSize - 1), first.first];
    stubHistory(first, older);

    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    await c.read(chatControllerProvider(_slug).notifier).loadMore();

    final ids = c.read(chatControllerProvider(_slug)).value!.messages.map((m) => m.id);
    expect(ids.length, ids.toSet().length);
  });

  test('queued turns render as TRAILING bubbles and flush-on-open replaces '
      'them with the delivered server rows', () async {
    final turn = OutboxTurn(
      id: 'k1',
      agentSlug: _slug,
      body: 'written offline',
      locationJson: null,
      createdAt: DateTime(2026, 1, 2),
      attempts: 0,
    );
    var queuedCalls = 0;
    when(() => repo.queuedTurns(any()))
        .thenAnswer((_) async => queuedCalls++ == 0 ? [turn] : const []);
    final canonical = [
      _msg('i1', MessageDirection.inbound, 'written offline',
          at: DateTime(2026, 1, 3)),
      _msg('o1', MessageDirection.outbound, 'reply',
          at: DateTime(2026, 1, 3, 0, 0, 1)),
    ];
    var histCalls = 0;
    when(() => repo.history(
          before: any(named: 'before'),
          limit: any(named: 'limit'),
          agentSlug: any(named: 'agentSlug'),
        )).thenAnswer((_) async => HistoryPage(
        messages: histCalls++ == 0 ? <ChatMessage>[] : canonical));
    when(() => repo.flushOutbox(any())).thenAnswer((_) async => 1);

    final c = makeContainer();
    final first = await c.read(chatControllerProvider(_slug).future);
    expect(first.messages.single.status, MessageStatus.queued);
    expect(first.messages.single.text, 'written offline');

    // Let the build-scheduled flush deliver + refetch.
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    final after = c.read(chatControllerProvider(_slug)).value!;
    expect(after.messages.map((m) => m.id), ['i1', 'o1']);
    expect(
      after.messages.any((m) => m.status == MessageStatus.queued),
      isFalse,
    );
    verify(() => repo.flushOutbox(_slug)).called(1);
  });

  test('a fully offline build with an empty cache but queued turns shows '
      'the queue, not the error screen', () async {
    final turn = OutboxTurn(
      id: 'k1',
      agentSlug: _slug,
      body: 'still queued',
      locationJson: null,
      createdAt: DateTime(2026, 1, 2),
      attempts: 0,
    );
    when(() => repo.queuedTurns(any())).thenAnswer((_) async => [turn]);
    when(() => repo.history(
          before: any(named: 'before'),
          limit: any(named: 'limit'),
          agentSlug: any(named: 'agentSlug'),
        )).thenThrow(Exception('offline, no cache'));

    final c = makeContainer();
    final state = await c.read(chatControllerProvider(_slug).future);

    expect(state.offline, isTrue);
    expect(state.messages.single.status, MessageStatus.queued);
    expect(state.hasMore, isFalse);
  });

  test('send appends the user message then the assistant reply', () async {
    stubHistory(<ChatMessage>[]);
    whenSend().thenAnswer(
      (_) async => TurnCompleted(TurnResult(
        inbound: _msg('i1', MessageDirection.inbound, 'hey'),
        outbound: _msg('o1', MessageDirection.outbound, 'reply'),
      )),
    );

    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    await c.read(chatControllerProvider(_slug).notifier).send('hey');

    final list = c.read(chatControllerProvider(_slug)).value!.messages;
    expect(list, hasLength(2));
    expect(list[0].id, 'i1');
    expect(list[0].status, MessageStatus.sent);
    expect(list[1].id, 'o1');
  });

  test('send marks the user message failed on error', () async {
    stubHistory(<ChatMessage>[]);
    whenSend().thenThrow(Exception('network down'));

    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    await c.read(chatControllerProvider(_slug).notifier).send('hey');

    final list = c.read(chatControllerProvider(_slug)).value!.messages;
    expect(list, hasLength(1));
    expect(list[0].status, MessageStatus.failed);
  });

  test('send drops the bubble and returns cancelled when the request is aborted',
      () async {
    stubHistory(<ChatMessage>[]);
    whenSend().thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/assistant/turn'),
        type: DioExceptionType.cancel,
      ),
    );

    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    final outcome =
        await c.read(chatControllerProvider(_slug).notifier).send('oops');

    expect(outcome, SendOutcome.cancelled);
    // The optimistic bubble is removed (not left as a failed message).
    expect(c.read(chatControllerProvider(_slug)).value!.messages, isEmpty);
  });

  test('retry resends a failed message and replaces it on success', () async {
    stubHistory(<ChatMessage>[]);
    // First attempt fails → one failed bubble.
    whenSend().thenThrow(Exception('offline'));

    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    final notifier = c.read(chatControllerProvider(_slug).notifier);
    await notifier.send('hello');

    final failed = c.read(chatControllerProvider(_slug)).value!.messages.single;
    expect(failed.status, MessageStatus.failed);

    // Connection's back — retry succeeds.
    whenSend().thenAnswer((_) async => TurnCompleted(TurnResult(
          inbound: _msg('i1', MessageDirection.inbound, 'hello'),
          outbound: _msg('o1', MessageDirection.outbound, 'hi'),
        )));

    final outcome = await notifier.retry(failed);

    expect(outcome, SendOutcome.sent);
    final list = c.read(chatControllerProvider(_slug)).value!.messages;
    expect(list.map((m) => m.id), containsAll(<String>['i1', 'o1']));
    expect(list.where((m) => m.status == MessageStatus.failed), isEmpty);
  });

  test('send ignores blank input', () async {
    stubHistory(<ChatMessage>[]);
    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    await c.read(chatControllerProvider(_slug).notifier).send('   ');
    expect(c.read(chatControllerProvider(_slug)).value!.messages, isEmpty);
    verifyNever(() => repo.send(
          any(),
          agentSlug: any(named: 'agentSlug'),
          attachment: any(named: 'attachment'),
          cancelToken: any(named: 'cancelToken'),
          idempotencyKey: any(named: 'idempotencyKey'),
          location: any(named: 'location'),
        ));
  });

  test('streaming: send types the reply out and reconciles to the durable rows',
      () async {
    // History: empty on build, the canonical rows on the reconcile read.
    final canonical = [
      _msg('i1', MessageDirection.inbound, 'hey',
          at: DateTime(2026, 1, 1, 10)),
      _msg('o1', MessageDirection.outbound, 'Hello there',
          at: DateTime(2026, 1, 1, 10, 0, 1)),
    ];
    var historyCalls = 0;
    when(() => repo.history(
          before: any(named: 'before'),
          limit: any(named: 'limit'),
          agentSlug: any(named: 'agentSlug'),
        )).thenAnswer(
        (_) async => HistoryPage(
            messages: historyCalls++ == 0 ? <ChatMessage>[] : canonical));

    whenSend().thenAnswer((_) async => const TurnAccepted('turn-1'));
    when(() => repo.streamTurn(any(), cancelToken: any(named: 'cancelToken')))
        .thenAnswer((_) => Stream.fromIterable([
              _ev(0, 'turn-start', {'inboundId': 'i1', 'outboundId': 'o1'}),
              _ev(1, 'status', {'label': 'Thinking…'}),
              // Intermediate-round text is discarded when the final round opens.
              _ev(2, 'text-delta', {'text': 'tool noise'}, round: 0),
              _ev(3, 'text-delta', {'text': 'Hello '}, round: 1),
              _ev(4, 'text-delta', {'text': 'there'}, round: 1),
              _ev(5, 'done', {'status': 'complete'}),
            ]));

    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    final outcome =
        await c.read(chatControllerProvider(_slug).notifier).send('hey');

    expect(outcome, SendOutcome.sent);
    final state = c.read(chatControllerProvider(_slug)).value!;
    expect(state.active, isNull); // reconciled — the streaming view is cleared
    expect(state.messages.map((m) => m.id), ['i1', 'o1']);
    expect(state.messages.last.text, 'Hello there');
    verifyNever(() => repo.cancelTurn(any()));
  });

  test(
      'streaming: trail upserts by stepId, tools tally, reasoning + token estimate',
      () async {
    final canonical = [
      _msg('i1', MessageDirection.inbound, 'hey',
          at: DateTime(2026, 1, 1, 10)),
      _msg('o1', MessageDirection.outbound, 'Hi',
          at: DateTime(2026, 1, 1, 10, 0, 1)),
    ];
    var historyCalls = 0;
    when(() => repo.history(
          before: any(named: 'before'),
          limit: any(named: 'limit'),
          agentSlug: any(named: 'agentSlug'),
        )).thenAnswer(
        (_) async => HistoryPage(
            messages: historyCalls++ == 0 ? <ChatMessage>[] : canonical));

    whenSend().thenAnswer((_) async => const TurnAccepted('turn-1'));

    final events = StreamController<TurnEvent>();
    addTearDown(() => events.close());
    when(() => repo.streamTurn(any(), cancelToken: any(named: 'cancelToken')))
        .thenAnswer((_) => events.stream);

    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    final notifier = c.read(chatControllerProvider(_slug).notifier);
    final sendFuture = notifier.send('hey');

    // A grounded status line starts the trail…
    events.add(_ev(0, 'status',
        {'label': 'Working on it…', 'stepId': 's1', 'kind': 'compute'}));
    await pumpUntil(c, (s) => s.active?.steps.length == 1);

    // …and its narrated upgrade replaces it IN PLACE (same stepId).
    events.add(_ev(1, 'status',
        {'label': 'Crunching your numbers…', 'stepId': 's1', 'kind': 'compute'}));
    await pumpUntil(
        c, (s) => s.active?.steps.first.label == 'Crunching your numbers…');
    var active = c.read(chatControllerProvider(_slug)).value!.active!;
    expect(active.steps, hasLength(1));
    expect(active.stageLabel, 'Crunching your numbers…');

    // A consecutive duplicate label collapses; a distinct step appends.
    events.add(_ev(2, 'status', {'label': 'Crunching your numbers…'}));
    events.add(_ev(3, 'status', {'label': 'Searching the web…', 'kind': 'web'}));
    await pumpUntil(c, (s) => s.active?.steps.length == 2);
    active = c.read(chatControllerProvider(_slug)).value!.active!;
    expect(active.steps.map((s) => s.label),
        ['Crunching your numbers…', 'Searching the web…']);

    // Tool events feed the live tally (ok:false = a failure).
    events.add(_ev(4, 'tool-start', {'name': 'web_search'}));
    events.add(_ev(5, 'tool-end', {'name': 'web_search', 'ok': false}));
    await pumpUntil(c, (s) => s.active?.toolsFailed == 1);
    active = c.read(chatControllerProvider(_slug)).value!.active!;
    expect(active.toolsStarted, 1);
    expect(active.toolsDone, 1);
    expect(active.toolsRunning, 0);

    // Reasoning accumulates (kept out of the reply) and counts toward the
    // chars/4 token estimate: 'pondering...' = 12 chars → 3.
    events.add(_ev(6, 'reasoning-delta', {'text': 'pondering...'}));
    await pumpUntil(c, (s) => s.active?.reasoning == 'pondering...');
    active = c.read(chatControllerProvider(_slug)).value!.active!;
    expect(active.reply, isEmpty);
    expect(active.tokens, 3);
    expect(active.tokensApprox, isTrue);

    // The visible reply streams; done reports the real token total.
    events.add(_ev(7, 'text-delta', {'text': 'Hi'}, round: 1));
    await pumpUntil(c, (s) => s.active?.reply == 'Hi');
    events.add(_ev(8, 'done', {'status': 'complete', 'tokensOut': 42}));

    final outcome = await sendFuture;
    expect(outcome, SendOutcome.sent);
    final state = c.read(chatControllerProvider(_slug)).value!;
    expect(state.active, isNull); // reconciled — the streaming view is cleared
    expect(state.messages.map((m) => m.id), ['i1', 'o1']);
  });

  test('streaming: stop aborts server-side, keeps the partial, returns cancelled',
      () async {
    final canonical = [
      _msg('i1', MessageDirection.inbound, 'hey',
          at: DateTime(2026, 1, 1, 10)),
      _msg('o1', MessageDirection.outbound, 'Par',
          at: DateTime(2026, 1, 1, 10, 0, 1)),
    ];
    var historyCalls = 0;
    when(() => repo.history(
          before: any(named: 'before'),
          limit: any(named: 'limit'),
          agentSlug: any(named: 'agentSlug'),
        )).thenAnswer(
        (_) async => HistoryPage(
            messages: historyCalls++ == 0 ? <ChatMessage>[] : canonical));

    whenSend().thenAnswer((_) async => const TurnAccepted('turn-1'));

    final events = StreamController<TurnEvent>();
    addTearDown(() => events.close());
    when(() => repo.streamTurn(any(), cancelToken: any(named: 'cancelToken')))
        .thenAnswer((_) => events.stream);
    // The runner aborts and finalizes the partial → emits `done`.
    when(() => repo.cancelTurn(any())).thenAnswer((_) async {
      events.add(_ev(3, 'done', {'status': 'complete'}));
    });

    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    final notifier = c.read(chatControllerProvider(_slug).notifier);

    final sendFuture = notifier.send('hey');
    events.add(_ev(0, 'turn-start', {'inboundId': 'i1', 'outboundId': 'o1'}));
    await pumpUntil(c, (s) => s.active?.outboundId == 'o1');
    events.add(_ev(1, 'text-delta', {'text': 'Par'}, round: 1));
    await pumpUntil(c, (s) => s.active?.reply == 'Par');

    await notifier.stopTurn();
    final outcome = await sendFuture;

    expect(outcome, SendOutcome.cancelled);
    verify(() => repo.cancelTurn('turn-1')).called(1);
    final state = c.read(chatControllerProvider(_slug)).value!;
    expect(state.active, isNull);
    expect(state.messages.map((m) => m.id), ['i1', 'o1']);
  });
}
