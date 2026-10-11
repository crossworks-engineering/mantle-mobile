// The attach button is offered only where the brain takes files: an Admin
// user chatting with an owner-surface assistant. A member's chat, and any
// assistant of a workspace other than Admin, take text.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/chat/chat_message.dart';
import 'package:jackdaw/data/chat/chat_repository.dart';
import 'package:jackdaw/data/chat/conversation_stream.dart';
import 'package:jackdaw/features/chat/chat_composer.dart';
import 'package:jackdaw/features/chat/chat_controller.dart';
import 'package:jackdaw/features/voice/voice_capture.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_voice_recorder.dart';
import '../helpers/pump_screen.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  Future<void> pump(WidgetTester tester, {required bool allow}) async {
    final repo = MockChatRepository();
    when(() => repo.history(
          before: any(named: 'before'),
          limit: any(named: 'limit'),
          agentSlug: any(named: 'agentSlug'),
        )).thenAnswer((_) async => const HistoryPage(messages: <ChatMessage>[]));
    when(() => repo.queuedTurns(any())).thenAnswer((_) async => const []);
    when(() => repo.flushOutbox(any())).thenAnswer((_) async => 0);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      conversationEventsProvider.overrideWith(
        (ref) => const Stream<ConversationEvent>.empty(),
      ),
      voiceRecorderFactoryProvider.overrideWithValue(FakeVoiceRecorder.new),
      voiceTranscriberProvider.overrideWithValue((_) async => ''),
    ]);
    container.listen(chatControllerProvider('team'), (_, _) {});
    await pumpScreen(
      tester,
      Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ChatComposer(
            provider: chatControllerProvider('team'),
            textController: TextEditingController(),
            agentName: 'Tess',
            allowAttachments: allow,
          ),
        ],
      ),
      container: container,
    );
  }

  testWidgets('a text-only chat offers no attach button', (tester) async {
    await pump(tester, allow: false);
    expect(find.bySemanticsLabel('Attach a photo or file'), findsNothing);
  });

  testWidgets('the owner surface keeps it', (tester) async {
    await pump(tester, allow: true);
    expect(find.bySemanticsLabel('Attach a photo or file'), findsOneWidget);
  });
}
