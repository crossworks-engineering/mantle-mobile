// ChatController (per-agent family): history load, scroll-up paging, optimistic
// send — with a mocked repository.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/chat/chat_api.dart';
import 'package:mantle_companion/data/chat/chat_message.dart';
import 'package:mantle_companion/data/chat/chat_repository.dart';
import 'package:mantle_companion/features/chat/chat_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

const _slug = 'saskia';

ChatMessage _msg(String id, MessageDirection d, String t, {DateTime? at}) =>
    ChatMessage(id: id, direction: d, text: t, createdAt: at ?? DateTime(2026));

/// A full page of distinct outbound messages, oldest-first, timestamped in
/// ascending order so paging cursors are meaningful.
List<ChatMessage> _page(String prefix, int n) => [
      for (var i = 0; i < n; i++)
        _msg('$prefix$i', MessageDirection.outbound, '$prefix$i',
            at: DateTime(2026, 1, 1).add(Duration(minutes: i))),
    ];

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2000)));

  late MockChatRepository repo;
  setUp(() => repo = MockChatRepository());

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  // One stub branching on the cursor: null `before` → latest page, else older.
  void stubHistory(List<ChatMessage> latest, [List<ChatMessage>? older]) {
    when(() => repo.history(
          before: any(named: 'before'),
          limit: any(named: 'limit'),
          agentSlug: any(named: 'agentSlug'),
        )).thenAnswer((inv) async =>
        inv.namedArguments[#before] == null ? latest : (older ?? latest));
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

  test('send appends the user message then the assistant reply', () async {
    stubHistory(<ChatMessage>[]);
    when(() => repo.send(any(), agentSlug: any(named: 'agentSlug'))).thenAnswer(
      (_) async => TurnResult(
        inbound: _msg('i1', MessageDirection.inbound, 'hey'),
        outbound: _msg('o1', MessageDirection.outbound, 'reply'),
      ),
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
    when(() => repo.send(any(), agentSlug: any(named: 'agentSlug')))
        .thenThrow(Exception('network down'));

    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    await c.read(chatControllerProvider(_slug).notifier).send('hey');

    final list = c.read(chatControllerProvider(_slug)).value!.messages;
    expect(list, hasLength(1));
    expect(list[0].status, MessageStatus.failed);
  });

  test('send ignores blank input', () async {
    stubHistory(<ChatMessage>[]);
    final c = makeContainer();
    await c.read(chatControllerProvider(_slug).future);
    await c.read(chatControllerProvider(_slug).notifier).send('   ');
    expect(c.read(chatControllerProvider(_slug)).value!.messages, isEmpty);
    verifyNever(() => repo.send(any(), agentSlug: any(named: 'agentSlug')));
  });
}
