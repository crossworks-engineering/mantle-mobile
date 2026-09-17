import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'settings_repository.dart';

part 'color_theme_controller.g.dart';

/// Owns the colour-theme id the app paints (one of `kMantleThemes`). Loads it
/// from [SettingsRepository] on build — a pick made on this phone, else the
/// brain's own theme, else the default — and writes through on change, so the
/// choice survives restarts. The UI falls back to the default theme while the
/// first load is in flight. Mirrors [ThemeModeController].
@riverpod
class ColorThemeController extends _$ColorThemeController {
  @override
  Future<String> build() {
    return ref.watch(settingsRepositoryProvider).colorTheme();
  }

  /// Persist [id] as this phone's own pick, then reflect it in state
  /// immediately. From now on it wins over the brain's theme.
  Future<void> select(String id) async {
    await ref.read(settingsRepositoryProvider).setColorTheme(id);
    if (!ref.mounted) return;
    state = AsyncData(id);
    ref.invalidate(colorThemeFollowsBrainProvider);
  }

  /// Drop this phone's pick and show the brain's theme (or the default when
  /// the brain has none).
  Future<void> followBrain() async {
    await ref.read(settingsRepositoryProvider).clearColorThemeOverride();
    if (!ref.mounted) return;
    ref.invalidate(colorThemeFollowsBrainProvider);
    await reload();
  }

  /// Re-resolve the id from the repository without passing through a loading
  /// state (which would flash the default theme for a frame). Called by the
  /// brain sync after it stores a new brain theme.
  Future<void> reload() async {
    final id = await ref.read(settingsRepositoryProvider).colorTheme();
    if (ref.mounted) state = AsyncData(id);
  }
}

/// Whether the phone follows the brain's theme (no pick of its own).
@riverpod
Future<bool> colorThemeFollowsBrain(Ref ref) async =>
    await ref.watch(settingsRepositoryProvider).colorThemeOverride() == null;

/// The brain's theme id as last synced, null when unknown. Invalidated by
/// [BrainAppearanceSync] when a sync stores a new value.
@riverpod
Future<String?> brainColorTheme(Ref ref) =>
    ref.watch(settingsRepositoryProvider).brainColorTheme();
