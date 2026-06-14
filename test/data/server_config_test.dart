import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/db/app_database.dart';
import 'package:mantle_companion/data/db/database_provider.dart';
import 'package:mantle_companion/data/server/server_config.dart';

void main() {
  group('normalizeBaseUrl', () {
    test('trims whitespace and trailing slashes', () {
      expect(normalizeBaseUrl('  https://m.example.com/  '), 'https://m.example.com');
      expect(normalizeBaseUrl('https://m.example.com///'), 'https://m.example.com');
      expect(normalizeBaseUrl('https://m.example.com'), 'https://m.example.com');
    });
  });

  test('ServerConfig defaults to null, then persists a normalized URL', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(await container.read(serverConfigProvider.future), isNull);

    await container
        .read(serverConfigProvider.notifier)
        .setUrl('https://m.example.com/');

    expect(container.read(serverConfigProvider).value, 'https://m.example.com');
  });
}
