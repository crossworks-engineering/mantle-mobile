// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_prefs_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads + updates push preferences (per-trigger toggles + quiet hours). On
/// first load it adopts the device's IANA timezone so quiet hours are in local
/// time. Updates are optimistic (state reflects the change immediately, then
/// reconciles with the server's response).

@ProviderFor(PushPrefsController)
final pushPrefsControllerProvider = PushPrefsControllerProvider._();

/// Loads + updates push preferences (per-trigger toggles + quiet hours). On
/// first load it adopts the device's IANA timezone so quiet hours are in local
/// time. Updates are optimistic (state reflects the change immediately, then
/// reconciles with the server's response).
final class PushPrefsControllerProvider
    extends $AsyncNotifierProvider<PushPrefsController, PushPreferences> {
  /// Loads + updates push preferences (per-trigger toggles + quiet hours). On
  /// first load it adopts the device's IANA timezone so quiet hours are in local
  /// time. Updates are optimistic (state reflects the change immediately, then
  /// reconciles with the server's response).
  PushPrefsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushPrefsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushPrefsControllerHash();

  @$internal
  @override
  PushPrefsController create() => PushPrefsController();
}

String _$pushPrefsControllerHash() =>
    r'7192a6c1440da3aaf8d12e7b508e663a04584f44';

/// Loads + updates push preferences (per-trigger toggles + quiet hours). On
/// first load it adopts the device's IANA timezone so quiet hours are in local
/// time. Updates are optimistic (state reflects the change immediately, then
/// reconciles with the server's response).

abstract class _$PushPrefsController extends $AsyncNotifier<PushPreferences> {
  FutureOr<PushPreferences> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PushPreferences>, PushPreferences>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PushPreferences>, PushPreferences>,
              AsyncValue<PushPreferences>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
