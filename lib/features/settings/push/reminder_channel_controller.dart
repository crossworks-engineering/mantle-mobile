import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/profile/profile_api.dart';

part 'reminder_channel_controller.g.dart';

/// Loads + sets where event reminders are delivered ('telegram' | 'mobile').
///
/// The value auto-follows the last surface the user messaged on (tracked
/// server-side); this controller exposes a manual override that holds until the
/// next message on the other channel supersedes it. Updates are optimistic:
/// the selection flips immediately, then reconciles with the server's response.
@riverpod
class ReminderChannelController extends _$ReminderChannelController {
  @override
  Future<String> build() async {
    return ref.read(profileApiProvider).getReminderChannel();
  }

  /// Pin reminders to [channel] ('telegram' | 'mobile').
  Future<void> select(String channel) async {
    if (state.value == channel) return;
    state = AsyncData(channel); // optimistic
    try {
      state = AsyncData(await ref.read(profileApiProvider).setReminderChannel(channel));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
