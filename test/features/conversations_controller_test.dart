// ConversationsController: loads the inbox, markRead zeroes unread optimistically.
// Plus AgentConversation model parsing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/agents/agent.dart';
import 'package:jackdaw/data/chat/conversation_stream.dart';
import 'package:jackdaw/data/conversations/conversation_models.dart';
import 'package:jackdaw/data/conversations/conversations_api.dart';
import 'package:jackdaw/features/conversations/conversations_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockConversationsApi extends Mock implements ConversationsApi {}

AgentConversation _conv(String slug, {int unread = 0}) => AgentConversation(
      agent: Agent(slug: slug, name: slug),
      lastText: 'hello from $slug',
      lastDirection: 'outbound',
      lastAt: DateTime(2026),
      unreadCount: unread,
    );

void main() {
  late MockConversationsApi api;
  setUp(() => api = MockConversationsApi());

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        conversationsApiProvider.overrideWithValue(api),
        // No live SSE in unit tests — an empty stream keeps the listen inert.
        conversationEventsProvider.overrideWith(
          (ref) => const Stream<ConversationEvent>.empty(),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(conversationsControllerProvider, (_, _) {});
    return c;
  }

  test('build loads the inbox', () async {
    when(() => api.list()).thenAnswer((_) async => [_conv('a'), _conv('b', unread: 2)]);

    final c = make();
    final list = await c.read(conversationsControllerProvider.future);

    expect(list, hasLength(2));
    expect(list[1].hasUnread, isTrue);
  });

  test('markRead zeroes the unread for that agent and calls the API', () async {
    when(() => api.list()).thenAnswer((_) async => [_conv('a', unread: 3), _conv('b', unread: 1)]);
    when(() => api.markRead(any())).thenAnswer((_) async {});

    final c = make();
    await c.read(conversationsControllerProvider.future);
    await c.read(conversationsControllerProvider.notifier).markRead('a');

    final list = c.read(conversationsControllerProvider).value!;
    expect(list.firstWhere((x) => x.agent.slug == 'a').unreadCount, 0);
    expect(list.firstWhere((x) => x.agent.slug == 'b').unreadCount, 1);
    verify(() => api.markRead('a')).called(1);
  });

  group('AgentConversation model', () {
    test('fromJson parses agent, preview, unread, avatar presence', () {
      final c = AgentConversation.fromJson({
        'slug': 'saskia',
        'name': 'Saskia',
        'avatar': {'style': 'beam', 'seed': 'x'},
        'lastMessage': {
          'text': 'on it',
          'direction': 'outbound',
          'createdAt': '2026-06-13T10:00:00.000Z',
        },
        'unreadCount': 4,
      });
      expect(c.agent.name, 'Saskia');
      expect(c.agent.hasAvatar, isTrue);
      expect(c.lastText, 'on it');
      expect(c.lastFromUser, isFalse);
      expect(c.unreadCount, 4);
      expect(c.hasUnread, isTrue);
    });

    test('fromJson tolerates a null lastMessage and missing avatar', () {
      final c = AgentConversation.fromJson({
        'slug': 'reflector',
        'name': 'Reflector',
        'avatar': null,
        'lastMessage': null,
      });
      expect(c.lastText, isNull);
      expect(c.lastAt, isNull);
      expect(c.agent.hasAvatar, isFalse);
      expect(c.unreadCount, 0);
      expect(c.hasUnread, isFalse);
    });
  });
}
