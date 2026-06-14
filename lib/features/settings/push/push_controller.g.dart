// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives push notifications setup. `build()` reflects current state (is THIS
/// device connected + the owner's device list); [connect]/[disconnect] run the
/// one-tap flow against Mantle + the relay (push-notifications.md §5.1).

@ProviderFor(PushController)
final pushControllerProvider = PushControllerProvider._();

/// Drives push notifications setup. `build()` reflects current state (is THIS
/// device connected + the owner's device list); [connect]/[disconnect] run the
/// one-tap flow against Mantle + the relay (push-notifications.md §5.1).
final class PushControllerProvider
    extends $AsyncNotifierProvider<PushController, PushState> {
  /// Drives push notifications setup. `build()` reflects current state (is THIS
  /// device connected + the owner's device list); [connect]/[disconnect] run the
  /// one-tap flow against Mantle + the relay (push-notifications.md §5.1).
  PushControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushControllerHash();

  @$internal
  @override
  PushController create() => PushController();
}

String _$pushControllerHash() => r'f341e06539b848e7ab3badb0510404ec3b15a32b';

/// Drives push notifications setup. `build()` reflects current state (is THIS
/// device connected + the owner's device list); [connect]/[disconnect] run the
/// one-tap flow against Mantle + the relay (push-notifications.md §5.1).

abstract class _$PushController extends $AsyncNotifier<PushState> {
  FutureOr<PushState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PushState>, PushState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PushState>, PushState>,
              AsyncValue<PushState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
