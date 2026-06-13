import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'settings_repository.dart';

part 'theme_mode_controller.g.dart';

/// Owns the app's theme mode: loads it from [SettingsRepository] on build and
/// writes through on every change, so the choice survives restarts. Exposed as
/// an `AsyncValue<ThemeMode>` — the UI falls back to [ThemeMode.system] while
/// the first load is in flight.
@riverpod
class ThemeModeController extends _$ThemeModeController {
  @override
  Future<ThemeMode> build() {
    return ref.watch(settingsRepositoryProvider).themeMode();
  }

  /// Persist [mode], then reflect it in state immediately.
  Future<void> setMode(ThemeMode mode) async {
    await ref.read(settingsRepositoryProvider).setThemeMode(mode);
    state = AsyncData(mode);
  }

  /// Cycle system → light → dark → system, persisting each step.
  Future<void> cycle() async {
    final current = state.value ?? ThemeMode.system;
    final next = switch (current) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setMode(next);
  }
}
