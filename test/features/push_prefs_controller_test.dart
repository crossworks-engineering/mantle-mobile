import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/push/push_api.dart';
import 'package:mantle_companion/features/settings/push/push_prefs_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockPushApi extends Mock implements PushApi {}

const _loaded = PushPreferences(assistantMessages: true, approvals: true);

void main() {
  late MockPushApi api;

  setUp(() {
    api = MockPushApi();
    when(() => api.getPreferences()).thenAnswer((_) async => _loaded);
  });

  test('save applies the patch optimistically and calls the API', () async {
    when(() => api.updatePreferences({'approvals': false})).thenAnswer(
      (_) async => const PushPreferences(assistantMessages: true, approvals: false),
    );

    final container = ProviderContainer(overrides: [pushApiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);

    final loaded = await container.read(pushPrefsControllerProvider.future);
    expect(loaded.approvals, isTrue);

    await container.read(pushPrefsControllerProvider.notifier).save({'approvals': false});

    expect(container.read(pushPrefsControllerProvider).value!.approvals, isFalse);
    verify(() => api.updatePreferences({'approvals': false})).called(1);
  });
}
