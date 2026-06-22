import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/profile/profile_api.dart';
import 'package:mantle_companion/features/settings/push/reminder_channel_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileApi extends Mock implements ProfileApi {}

void main() {
  late MockProfileApi api;

  setUp(() {
    api = MockProfileApi();
    when(() => api.getReminderChannel()).thenAnswer((_) async => 'telegram');
  });

  test('select flips optimistically and persists via the API', () async {
    when(() => api.setReminderChannel('mobile')).thenAnswer((_) async => 'mobile');

    final container = ProviderContainer(overrides: [profileApiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);

    expect(await container.read(reminderChannelControllerProvider.future), 'telegram');

    await container.read(reminderChannelControllerProvider.notifier).select('mobile');

    expect(container.read(reminderChannelControllerProvider).value, 'mobile');
    verify(() => api.setReminderChannel('mobile')).called(1);
  });

  test('select is a no-op when the channel is unchanged', () async {
    final container = ProviderContainer(overrides: [profileApiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);

    await container.read(reminderChannelControllerProvider.future); // loads 'telegram'
    await container.read(reminderChannelControllerProvider.notifier).select('telegram');

    verifyNever(() => api.setReminderChannel(any()));
  });
}
