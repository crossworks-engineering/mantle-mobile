// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the app's theme mode: loads it from [SettingsRepository] on build and
/// writes through on every change, so the choice survives restarts. Exposed as
/// an `AsyncValue<ThemeMode>` — the UI falls back to [ThemeMode.system] while
/// the first load is in flight.

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

/// Owns the app's theme mode: loads it from [SettingsRepository] on build and
/// writes through on every change, so the choice survives restarts. Exposed as
/// an `AsyncValue<ThemeMode>` — the UI falls back to [ThemeMode.system] while
/// the first load is in flight.
final class ThemeModeControllerProvider
    extends $AsyncNotifierProvider<ThemeModeController, ThemeMode> {
  /// Owns the app's theme mode: loads it from [SettingsRepository] on build and
  /// writes through on every change, so the choice survives restarts. Exposed as
  /// an `AsyncValue<ThemeMode>` — the UI falls back to [ThemeMode.system] while
  /// the first load is in flight.
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();
}

String _$themeModeControllerHash() =>
    r'b41ef505deae25d96c2a133479e4a3961525c614';

/// Owns the app's theme mode: loads it from [SettingsRepository] on build and
/// writes through on every change, so the choice survives restarts. Exposed as
/// an `AsyncValue<ThemeMode>` — the UI falls back to [ThemeMode.system] while
/// the first load is in flight.

abstract class _$ThemeModeController extends $AsyncNotifier<ThemeMode> {
  FutureOr<ThemeMode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeMode>, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeMode>, ThemeMode>,
              AsyncValue<ThemeMode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
