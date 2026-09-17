// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'color_theme_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the colour-theme id the app paints (one of `kMantleThemes`). Loads it
/// from [SettingsRepository] on build — a pick made on this phone, else the
/// brain's own theme, else the default — and writes through on change, so the
/// choice survives restarts. The UI falls back to the default theme while the
/// first load is in flight. Mirrors [ThemeModeController].

@ProviderFor(ColorThemeController)
final colorThemeControllerProvider = ColorThemeControllerProvider._();

/// Owns the colour-theme id the app paints (one of `kMantleThemes`). Loads it
/// from [SettingsRepository] on build — a pick made on this phone, else the
/// brain's own theme, else the default — and writes through on change, so the
/// choice survives restarts. The UI falls back to the default theme while the
/// first load is in flight. Mirrors [ThemeModeController].
final class ColorThemeControllerProvider
    extends $AsyncNotifierProvider<ColorThemeController, String> {
  /// Owns the colour-theme id the app paints (one of `kMantleThemes`). Loads it
  /// from [SettingsRepository] on build — a pick made on this phone, else the
  /// brain's own theme, else the default — and writes through on change, so the
  /// choice survives restarts. The UI falls back to the default theme while the
  /// first load is in flight. Mirrors [ThemeModeController].
  ColorThemeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'colorThemeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$colorThemeControllerHash();

  @$internal
  @override
  ColorThemeController create() => ColorThemeController();
}

String _$colorThemeControllerHash() =>
    r'5383ff188d1f2df5e46a469ee37df9425d2a7efd';

/// Owns the colour-theme id the app paints (one of `kMantleThemes`). Loads it
/// from [SettingsRepository] on build — a pick made on this phone, else the
/// brain's own theme, else the default — and writes through on change, so the
/// choice survives restarts. The UI falls back to the default theme while the
/// first load is in flight. Mirrors [ThemeModeController].

abstract class _$ColorThemeController extends $AsyncNotifier<String> {
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

/// Whether the phone follows the brain's theme (no pick of its own).

@ProviderFor(colorThemeFollowsBrain)
final colorThemeFollowsBrainProvider = ColorThemeFollowsBrainProvider._();

/// Whether the phone follows the brain's theme (no pick of its own).

final class ColorThemeFollowsBrainProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether the phone follows the brain's theme (no pick of its own).
  ColorThemeFollowsBrainProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'colorThemeFollowsBrainProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$colorThemeFollowsBrainHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return colorThemeFollowsBrain(ref);
  }
}

String _$colorThemeFollowsBrainHash() =>
    r'd646164f005899247076522a945423304cdc0d64';

/// The brain's theme id as last synced, null when unknown. Invalidated by
/// [BrainAppearanceSync] when a sync stores a new value.

@ProviderFor(brainColorTheme)
final brainColorThemeProvider = BrainColorThemeProvider._();

/// The brain's theme id as last synced, null when unknown. Invalidated by
/// [BrainAppearanceSync] when a sync stores a new value.

final class BrainColorThemeProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The brain's theme id as last synced, null when unknown. Invalidated by
  /// [BrainAppearanceSync] when a sync stores a new value.
  BrainColorThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brainColorThemeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brainColorThemeHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return brainColorTheme(ref);
  }
}

String _$brainColorThemeHash() => r'7221d48a98ac94b954ed81f13f973bcb0e2090de';
