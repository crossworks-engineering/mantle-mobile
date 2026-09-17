// Data-layer test: the repository against a REAL Drift database, run in-memory
// so it's fast and isolated (no file, no simulator). This exercises the actual
// SQL — the highest-confidence way to test persistence.

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/features/settings/settings_repository.dart';
import 'package:jackdaw/theme/mantle_theme.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SettingsRepository(db);
  });
  tearDown(() => db.close());

  test('defaults to ThemeMode.system when nothing is stored', () async {
    expect(await repo.themeMode(), ThemeMode.system);
  });

  test('persists and reads back the theme mode', () async {
    await repo.setThemeMode(ThemeMode.dark);
    expect(await repo.themeMode(), ThemeMode.dark);

    await repo.setThemeMode(ThemeMode.light);
    expect(await repo.themeMode(), ThemeMode.light);
  });

  test('color theme defaults to jackdaw and round-trips', () async {
    expect(await repo.colorTheme(), MantleTheme.defaultId);
    expect(MantleTheme.defaultId, 'jackdaw');

    await repo.setColorTheme('cosmic-night');
    expect(await repo.colorTheme(), 'cosmic-night');
  });

  test('color theme falls back to default when the stored id is unknown',
      () async {
    await repo.setColorTheme('a-theme-that-was-removed');
    expect(await repo.colorTheme(), MantleTheme.defaultId);
    expect(await repo.colorThemeOverride(), isNull);
  });

  test('the brain theme is the default until the phone picks its own',
      () async {
    await repo.setBrainColorTheme('pinnacle');
    expect(await repo.colorTheme(), 'pinnacle');
    expect(await repo.colorThemeOverride(), isNull);

    await repo.setColorTheme('mono');
    expect(await repo.colorTheme(), 'mono');

    await repo.clearColorThemeOverride();
    expect(await repo.colorTheme(), 'pinnacle');

    await repo.setBrainColorTheme(null);
    expect(await repo.brainColorTheme(), isNull);
    expect(await repo.colorTheme(), MantleTheme.defaultId);
  });

  test('a retired pick falls through to the brain, not the default', () async {
    await repo.setBrainColorTheme('claude');
    await repo.setColorTheme('a-theme-that-was-removed');
    expect(await repo.colorTheme(), 'claude');
  });

  test('account email is null until set, normalised, and cleared to null',
      () async {
    expect(await repo.accountEmail(), isNull);
    await repo.setAccountEmail('  Owner@Example.com ');
    expect(await repo.accountEmail(), 'owner@example.com');
    await repo.clearAccountEmail();
    expect(await repo.accountEmail(), isNull);
  });

  test('alarm rationale is unshown until marked', () async {
    expect(await repo.alarmRationaleShown(), isFalse);
    await repo.setAlarmRationaleShown();
    expect(await repo.alarmRationaleShown(), isTrue);
  });

  test('random mode defaults to off with the default interval', () async {
    expect(await repo.randomThemeEnabled(), isFalse);
    expect(await repo.randomInterval(), SettingsRepository.defaultRandomInterval);
    expect(await repo.lastRandomAtMs(), 0);
  });

  test('random mode settings round-trip', () async {
    await repo.setRandomThemeEnabled(true);
    await repo.setRandomInterval(const Duration(hours: 6));
    await repo.setLastRandomAtMs(1750000000000);

    expect(await repo.randomThemeEnabled(), isTrue);
    expect(await repo.randomInterval(), const Duration(hours: 6));
    expect(await repo.lastRandomAtMs(), 1750000000000);
  });
}
