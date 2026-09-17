// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_channel_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads + sets where event reminders are delivered ('telegram' | 'mobile').
///
/// The value auto-follows the last surface the user messaged on (tracked
/// server-side); this controller exposes a manual override that holds until the
/// next message on the other channel supersedes it. Updates are optimistic:
/// the selection flips immediately, then reconciles with the server's response.

@ProviderFor(ReminderChannelController)
final reminderChannelControllerProvider = ReminderChannelControllerProvider._();

/// Loads + sets where event reminders are delivered ('telegram' | 'mobile').
///
/// The value auto-follows the last surface the user messaged on (tracked
/// server-side); this controller exposes a manual override that holds until the
/// next message on the other channel supersedes it. Updates are optimistic:
/// the selection flips immediately, then reconciles with the server's response.
final class ReminderChannelControllerProvider
    extends $AsyncNotifierProvider<ReminderChannelController, String> {
  /// Loads + sets where event reminders are delivered ('telegram' | 'mobile').
  ///
  /// The value auto-follows the last surface the user messaged on (tracked
  /// server-side); this controller exposes a manual override that holds until the
  /// next message on the other channel supersedes it. Updates are optimistic:
  /// the selection flips immediately, then reconciles with the server's response.
  ReminderChannelControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderChannelControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderChannelControllerHash();

  @$internal
  @override
  ReminderChannelController create() => ReminderChannelController();
}

String _$reminderChannelControllerHash() =>
    r'e68dfab31fcf73550a2b3950f492a50986e1919a';

/// Loads + sets where event reminders are delivered ('telegram' | 'mobile').
///
/// The value auto-follows the last surface the user messaged on (tracked
/// server-side); this controller exposes a manual override that holds until the
/// next message on the other channel supersedes it. Updates are optimistic:
/// the selection flips immediately, then reconciles with the server's response.

abstract class _$ReminderChannelController extends $AsyncNotifier<String> {
  FutureOr<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String>, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String>, String>,
              AsyncValue<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
