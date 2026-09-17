// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brain_appearance_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps the phone's idea of the brain's colour theme fresh: on sign-in and
/// on every foreground resume it reads the public `GET /api/appearance` and
/// stores `colorTheme`. A theme the owner sets on the web therefore shows on
/// the phone the next time it comes to the front — unless the phone has a
/// pick of its own, which wins (see [SettingsRepository.colorTheme]).
///
/// keepAlive + watched once from the app root, like the alarm sync — nothing
/// reads its (void) value. Failures are silent: offline or a pre-appearance
/// server leaves whatever was last stored.

@ProviderFor(BrainAppearanceSync)
final brainAppearanceSyncProvider = BrainAppearanceSyncProvider._();

/// Keeps the phone's idea of the brain's colour theme fresh: on sign-in and
/// on every foreground resume it reads the public `GET /api/appearance` and
/// stores `colorTheme`. A theme the owner sets on the web therefore shows on
/// the phone the next time it comes to the front — unless the phone has a
/// pick of its own, which wins (see [SettingsRepository.colorTheme]).
///
/// keepAlive + watched once from the app root, like the alarm sync — nothing
/// reads its (void) value. Failures are silent: offline or a pre-appearance
/// server leaves whatever was last stored.
final class BrainAppearanceSyncProvider
    extends $NotifierProvider<BrainAppearanceSync, void> {
  /// Keeps the phone's idea of the brain's colour theme fresh: on sign-in and
  /// on every foreground resume it reads the public `GET /api/appearance` and
  /// stores `colorTheme`. A theme the owner sets on the web therefore shows on
  /// the phone the next time it comes to the front — unless the phone has a
  /// pick of its own, which wins (see [SettingsRepository.colorTheme]).
  ///
  /// keepAlive + watched once from the app root, like the alarm sync — nothing
  /// reads its (void) value. Failures are silent: offline or a pre-appearance
  /// server leaves whatever was last stored.
  BrainAppearanceSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brainAppearanceSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brainAppearanceSyncHash();

  @$internal
  @override
  BrainAppearanceSync create() => BrainAppearanceSync();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$brainAppearanceSyncHash() =>
    r'eee5bcca82bb2acdaf0d13581b558510e0ac6c46';

/// Keeps the phone's idea of the brain's colour theme fresh: on sign-in and
/// on every foreground resume it reads the public `GET /api/appearance` and
/// stores `colorTheme`. A theme the owner sets on the web therefore shows on
/// the phone the next time it comes to the front — unless the phone has a
/// pick of its own, which wins (see [SettingsRepository.colorTheme]).
///
/// keepAlive + watched once from the app root, like the alarm sync — nothing
/// reads its (void) value. Failures are silent: offline or a pre-appearance
/// server leaves whatever was last stored.

abstract class _$BrainAppearanceSync extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
