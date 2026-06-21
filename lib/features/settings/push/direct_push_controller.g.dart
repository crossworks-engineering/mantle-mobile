// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'direct_push_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The direct-connection push transport (no-Google Android). State is whether
/// the foreground service is running; [enable]/[disable] start/stop it. Android
/// only — the UI hides it elsewhere.

@ProviderFor(DirectPushController)
final directPushControllerProvider = DirectPushControllerProvider._();

/// The direct-connection push transport (no-Google Android). State is whether
/// the foreground service is running; [enable]/[disable] start/stop it. Android
/// only — the UI hides it elsewhere.
final class DirectPushControllerProvider
    extends $AsyncNotifierProvider<DirectPushController, bool> {
  /// The direct-connection push transport (no-Google Android). State is whether
  /// the foreground service is running; [enable]/[disable] start/stop it. Android
  /// only — the UI hides it elsewhere.
  DirectPushControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directPushControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directPushControllerHash();

  @$internal
  @override
  DirectPushController create() => DirectPushController();
}

String _$directPushControllerHash() =>
    r'f57a60dc87daf2a92d3a76e1c50295413bac2ac5';

/// The direct-connection push transport (no-Google Android). State is whether
/// the foreground service is running; [enable]/[disable] start/stop it. Android
/// only — the UI hides it elsewhere.

abstract class _$DirectPushController extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
