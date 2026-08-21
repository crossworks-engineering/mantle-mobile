// Provider test: the controller in isolation, with a mocktail-mocked
// repository overridden into a ProviderContainer. No DB, no I/O — pure logic.

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/features/settings/settings_repository.dart';
import 'package:jackdaw/features/settings/theme_mode_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  setUpAll(() => registerFallbackValue(ThemeMode.system));

  late MockSettingsRepository repo;

  setUp(() {
    repo = MockSettingsRepository();
    when(() => repo.themeMode()).thenAnswer((_) async => ThemeMode.system);
    when(() => repo.setThemeMode(any())).thenAnswer((_) async {});
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('build loads the persisted theme mode', () async {
    when(() => repo.themeMode()).thenAnswer((_) async => ThemeMode.dark);

    final container = makeContainer();
    final mode = await container.read(themeModeControllerProvider.future);

    expect(mode, ThemeMode.dark);
  });

  test('cycle advances system → light and writes through', () async {
    final container = makeContainer();
    await container.read(themeModeControllerProvider.future); // settle to system

    await container.read(themeModeControllerProvider.notifier).cycle();

    expect(
      container.read(themeModeControllerProvider).value,
      ThemeMode.light,
    );
    verify(() => repo.setThemeMode(ThemeMode.light)).called(1);
  });
}
