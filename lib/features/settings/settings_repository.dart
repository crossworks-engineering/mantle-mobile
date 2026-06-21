import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../theme/mantle_theme.dart';

part 'settings_repository.g.dart';

/// Reads and writes small device-local settings on top of the [AppDatabase]
/// key/value store. Pure logic over the data source — trivially unit-testable
/// with either a real in-memory DB or a mocked [AppDatabase].
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _themeModeKey = 'theme_mode';
  static const _colorThemeKey = 'color_theme';
  static const _randomThemeKey = 'random_theme_enabled';
  static const _randomIntervalKey = 'random_theme_interval_ms';
  static const _randomAtKey = 'random_theme_at_ms';
  static const _locationSharingKey = 'location_sharing';

  /// Default random-rotation cadence (12 hours), mirroring the web app.
  static const Duration defaultRandomInterval = Duration(hours: 12);

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

  /// The selected color-theme id, falling back to the default if unset or no
  /// longer present in the registry (e.g. a theme removed from the web app).
  Future<String> colorTheme() async {
    final raw = await _db.getSetting(_colorThemeKey);
    final exists = raw != null && kMantleThemes.any((t) => t.id == raw);
    return exists ? raw : MantleTheme.defaultId;
  }

  /// Persists the selected color-theme [id].
  Future<void> setColorTheme(String id) => _db.setSetting(_colorThemeKey, id);

  /// Whether random-rotation mode is on (default off).
  Future<bool> randomThemeEnabled() async =>
      await _db.getSetting(_randomThemeKey) == 'true';

  Future<void> setRandomThemeEnabled(bool enabled) =>
      _db.setSetting(_randomThemeKey, enabled.toString());

  /// The chosen reshuffle cadence, defaulting to [defaultRandomInterval].
  Future<Duration> randomInterval() async {
    final ms = int.tryParse(await _db.getSetting(_randomIntervalKey) ?? '');
    return ms != null && ms > 0
        ? Duration(milliseconds: ms)
        : defaultRandomInterval;
  }

  Future<void> setRandomInterval(Duration interval) =>
      _db.setSetting(_randomIntervalKey, interval.inMilliseconds.toString());

  /// Epoch-ms of the last random reshuffle (0 if never), so the timer survives
  /// restarts the way the web app does.
  Future<int> lastRandomAtMs() async =>
      int.tryParse(await _db.getSetting(_randomAtKey) ?? '') ?? 0;

  Future<void> setLastRandomAtMs(int epochMs) =>
      _db.setSetting(_randomAtKey, epochMs.toString());

  /// Whether to attach device location to outgoing messages (default off — the
  /// user must opt in, and the OS permission must also be granted).
  Future<bool> locationSharing() async =>
      await _db.getSetting(_locationSharingKey) == 'true';

  Future<void> setLocationSharing(bool enabled) =>
      _db.setSetting(_locationSharingKey, enabled.toString());
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
}
