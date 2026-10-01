// The home screen's last-message card: which message it picks, what it
// shows, and that it follows the inbox (so a message that arrived while the
// app was away shows without a manual refresh).

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/agents/agent.dart';
import 'package:jackdaw/data/chat/conversation_stream.dart';
import 'package:jackdaw/data/conversations/conversation_models.dart';
import 'package:jackdaw/data/conversations/conversations_api.dart';
import 'package:jackdaw/features/home/last_message_card.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_screen.dart';

class MockConversationsApi extends Mock implements ConversationsApi {}

AgentConversation conv(
  String slug, {
  String? text = 'hello',
  String direction = 'outbound',
  DateTime? at,
  int unread = 0,
}) =>
    AgentConversation(
      agent: Agent(slug: slug, name: slug[0].toUpperCase() + slug.substring(1)),
      lastText: text,
      lastDirection: direction,
      lastAt: at ?? DateTime.now().subtract(const Duration(minutes: 5)),
      unreadCount: unread,
    );

void main() {
  group('latestReceived', () {
    final t = DateTime.utc(2026, 10, 1, 9);

    test('the newest message that came FROM an agent, across agents', () {
      final picked = latestReceived([
        conv('saskia', at: t),
        conv('morph', at: t.add(const Duration(hours: 1))),
        conv('atlas', at: t.subtract(const Duration(days: 1))),
      ]);
      expect(picked!.agent.slug, 'morph');
    });

    test('a thread that ends on the person\'s own words is not "received"',
        () {
      final picked = latestReceived([
        conv('saskia', at: t),
        conv('morph', at: t.add(const Duration(hours: 1)), direction: 'inbound'),
      ]);
      expect(picked!.agent.slug, 'saskia');
    });

    test('nothing received is nothing to show', () {
      expect(latestReceived(const []), isNull);
      expect(latestReceived([conv('a', text: null)]), isNull);
      expect(latestReceived([conv('a', text: '   ')]), isNull);
      expect(latestReceived([conv('a', direction: 'inbound')]), isNull);
    });
  });

  group('the card', () {
    late MockConversationsApi api;
    late StreamController<ConversationEvent> events;

    setUp(() {
      api = MockConversationsApi();
      events = StreamController<ConversationEvent>.broadcast();
      addTearDown(events.close);
    });

    Future<void> pump(WidgetTester tester) => pumpScreen(
          tester,
          ListView(children: const [LastMessageCard(), Text('the controls')]),
          container: ProviderContainer(overrides: [
            conversationsApiProvider.overrideWithValue(api),
            conversationEventsProvider.overrideWith((ref) => events.stream),
          ]),
        );

    testWidgets('shows who, what (as markdown, not its source) and when',
        (tester) async {
      when(() => api.list()).thenAnswer(
        (_) async => [
          conv('saskia', text: '**Done.** The quote is filed.', unread: 1),
        ],
      );
      await pump(tester);

      expect(find.text('Saskia'), findsOneWidget);
      expect(find.textContaining('Done.', findRichText: true), findsOneWidget);
      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.text('5m'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      // To a screen reader the card is one button, in plain words.
      expect(
        find.bySemanticsLabel(
          'New message from Saskia: Done. The quote is filed.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a read message has no "New"; several unread are counted',
        (tester) async {
      when(() => api.list()).thenAnswer((_) async => [conv('saskia')]);
      await pump(tester);
      expect(find.text('New'), findsNothing);

      when(() => api.list())
          .thenAnswer((_) async => [conv('saskia', unread: 3)]);
      events.add(const ConversationEvent(agentSlug: 'saskia', direction: 'outbound'));
      await tester.pumpAndSettle();
      expect(find.text('3 new'), findsOneWidget);
    });

    testWidgets('takes no room when nothing was received', (tester) async {
      when(() => api.list()).thenAnswer(
        (_) async => [conv('saskia', direction: 'inbound')],
      );
      await pump(tester);

      expect(find.text('Saskia'), findsNothing);
      expect(tester.getTopLeft(find.text('the controls')).dy, 0);
    });

    testWidgets('a new message shows when the stream says a thread changed',
        (tester) async {
      when(() => api.list()).thenAnswer((_) async => [conv('saskia', text: 'First')]);
      await pump(tester);
      expect(find.textContaining('First', findRichText: true), findsOneWidget);

      when(() => api.list()).thenAnswer(
        (_) async => [
          conv('saskia', text: 'First'),
          conv('morph', text: 'Second, and newer', at: DateTime.now(), unread: 1),
        ],
      );
      events.add(const ConversationEvent(agentSlug: 'morph', direction: 'outbound'));
      await tester.pumpAndSettle();

      expect(find.text('Morph'), findsOneWidget);
      expect(find.textContaining('Second, and newer', findRichText: true),
          findsOneWidget);
    });

    testWidgets('a long message is cut, and says there is more',
        (tester) async {
      when(() => api.list()).thenAnswer(
        (_) async => [
          conv('saskia',
              text: List.generate(30, (i) => 'Line $i of a long reply.').join('\n\n')),
        ],
      );
      await pump(tester);

      expect(find.text('Open to read the rest'), findsOneWidget);
    });

    testWidgets('a huge message: only its head is stripped and rendered',
        (tester) async {
      // The strip rules are quadratic on unmatched brackets. The card cuts
      // the reply to its head before it strips (for the screen reader) and
      // before it renders, so a hostile reply cannot hang the home screen.
      when(() => api.list()).thenAnswer(
        (_) async => [
          conv('saskia', text: 'Start ${List.filled(50000, '[').join()}'),
        ],
      );
      final watch = Stopwatch()..start();
      await pump(tester);
      watch.stop();

      expect(find.text('Saskia'), findsOneWidget);
      expect(find.textContaining('Start', findRichText: true), findsWidgets);
      expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    });
  });
}
