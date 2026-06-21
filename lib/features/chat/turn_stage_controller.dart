import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/chat/chat_message.dart';
import '../../data/chat/chat_repository.dart';
import 'chat_controller.dart';

part 'turn_stage_controller.g.dart';

const _pollInterval = Duration(milliseconds: 900);

/// Streams the responder's coarse stage label ("Thinking…", "Searching the
/// web…", …) while a send is in flight on [agentSlug]'s thread, by polling
/// `GET /api/assistant/turn/stage` every ~900ms — mirroring the web's stage
/// indicator. The turn itself is a single atomic POST (no token streaming), so
/// this just animates the wait.
///
/// Emits null between mapped steps (the typing bubble then shows dots only) and
/// stops polling the moment the optimistic `sending` message resolves. The
/// `sending` flag is read from [ChatController] via `select`, so this provider
/// rebuilds — and tears its poll loop down — as soon as the turn lands.
/// autoDispose: only runs while the thread is on screen.
@riverpod
Stream<String?> turnStage(Ref ref, String agentSlug) async* {
  final chat = ref.watch(chatControllerProvider(agentSlug));
  final sending =
      chat.value?.messages.any((m) => m.status == MessageStatus.sending) ??
          false;
  if (!sending) {
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
