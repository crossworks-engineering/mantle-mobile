import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';

part 'settings_repository.g.dart';

/// Reads and writes small device-local settings on top of the [AppDatabase]
/// key/value store. Pure logic over the data source — trivially unit-testable
/// with either a real in-memory DB or a mocked [AppDatabase].
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _themeModeKey = 'theme_mode';

  /// The persisted theme mode, defaulting to [ThemeMode.system].
  Future<ThemeMode> themeMode() async {
    final raw = await _db.getSetting(_themeModeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Persists [mode] (stored as its enum name: `system` / `light` / `dark`).
  Future<void> setThemeMode(ThemeMode mode) {
    return _db.setSetting(_themeModeKey, mode.name);
  }
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
}
