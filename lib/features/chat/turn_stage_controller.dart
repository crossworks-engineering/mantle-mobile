import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/chat/chat_message.dart';
import '../../data/chat/chat_repository.dart';
import 'chat_controller.dart';

part 'turn_stage_controller.g.dart';

const _pollInterval = Duration(milliseconds: 900);

/// Streams the responder's coarse stage label ("Thinking…", "Searching the
/// web…", …) while a send is in flight on [agentSlug]'s thread, by polling
/// `GET /api/assistant/turn/stage` every ~900ms — mirroring the web's stage
/// indicator. This is the FALLBACK for the legacy blocking path; when live
/// streaming is on the label rides the SSE bus on [ChatState.active] instead, so
/// this poller stands down (yields null) to avoid redundant requests.
///
/// Emits null between mapped steps (the typing bubble then shows dots only) and
/// stops polling the moment the optimistic `sending` message resolves. The state
/// is read from [ChatController], so this provider rebuilds — and tears its poll
/// loop down — as soon as the turn lands. autoDispose: only runs on screen.
@riverpod
Stream<String?> turnStage(Ref ref, String agentSlug) async* {
  final chat = ref.watch(chatControllerProvider(agentSlug)).value;
  final sending =
      chat?.messages.any((m) => m.status == MessageStatus.sending) ?? false;
  // A streamed turn carries its own live label — don't also poll.
  if (!sending || chat?.active != null) {
    yield null;
    return;
  }

  final repo = ref.watch(chatRepositoryProvider);
  while (true) {
    try {
      yield await repo.turnStage();
    } catch (_) {
      // Network blip — keep the last label and try again next tick.
    }
    await Future<void>.delayed(_pollInterval);
  }
}
