import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'settings_repository.dart';

part 'color_theme_controller.g.dart';

/// Owns the selected color-theme id (one of `kMantleThemes`). Loads it from
/// [SettingsRepository] on build and writes through on change, so the choice
/// survives restarts. The UI falls back to the default theme while the first
/// load is in flight. Mirrors [ThemeModeController].
@riverpod
class ColorThemeController extends _$ColorThemeController {
  @override
  Future<String> build() {
    return ref.watch(settingsRepositoryProvider).colorTheme();
  }

  /// Persist [id], then reflect it in state immediately.
  Future<void> select(String id) async {
    await ref.read(settingsRepositoryProvider).setColorTheme(id);
    if (ref.mounted) state = AsyncData(id);
  }
}
