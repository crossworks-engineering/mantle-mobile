// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'color_theme_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the selected color-theme id (one of `kMantleThemes`). Loads it from
/// [SettingsRepository] on build and writes through on change, so the choice
/// survives restarts. The UI falls back to the default theme while the first
/// load is in flight. Mirrors [ThemeModeController].

@ProviderFor(ColorThemeController)
final colorThemeControllerProvider = ColorThemeControllerProvider._();

/// Owns the selected color-theme id (one of `kMantleThemes`). Loads it from
/// [SettingsRepository] on build and writes through on change, so the choice
/// survives restarts. The UI falls back to the default theme while the first
/// load is in flight. Mirrors [ThemeModeController].
final class ColorThemeControllerProvider
    extends $AsyncNotifierProvider<ColorThemeController, String> {
  /// Owns the selected color-theme id (one of `kMantleThemes`). Loads it from
  /// [SettingsRepository] on build and writes through on change, so the choice
  /// survives restarts. The UI falls back to the default theme while the first
  /// load is in flight. Mirrors [ThemeModeController].
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
    r'd796888a6986846b484007d91e843173ecbd4cea';

/// Owns the selected color-theme id (one of `kMantleThemes`). Loads it from
/// [SettingsRepository] on build and writes through on change, so the choice
/// survives restarts. The UI falls back to the default theme while the first
/// load is in flight. Mirrors [ThemeModeController].

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
