import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/push/push_api.dart';
import 'package:jackdaw/data/push/push_keys.dart';
import 'package:jackdaw/data/push/push_token_service.dart';
import 'package:jackdaw/features/settings/push/push_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockPushApi extends Mock implements PushApi {}

class MockPushKeyStore extends Mock implements PushKeyStore {}

class MockPushTokenService extends Mock implements PushTokenService {}

void main() {
  late MockPushApi api;
  late MockPushKeyStore keys;
  late MockPushTokenService tokens;

  setUp(() {
    api = MockPushApi();
    keys = MockPushKeyStore();
    tokens = MockPushTokenService();
    // Defaults for build()/_load(): disconnected, no devices.
    when(() => keys.subscriptionId()).thenAnswer((_) async => null);
    when(() => api.list()).thenAnswer((_) async => <PushDevice>[]);
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        pushApiProvider.overrideWithValue(api),
        pushTokenServiceProvider.overrideWithValue(tokens),
        pushKeyStoreProvider.overrideWith((ref) async => keys),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('connect runs permission → keypair → connect → enroll → subscribe', () async {
    when(() => tokens.requestToken())
        .thenAnswer((_) async => (platform: 'ios', token: 'apns-token'));
    when(() => keys.ensureDeviceKeyPair()).thenAnswer((_) async => 'PUBKEY');
    when(() => api.connect(
          platform: any(named: 'platform'),
          osPushToken: any(named: 'osPushToken'),
          publicKey: any(named: 'publicKey'),
        )).thenAnswer((_) async => (ticket: 'tkt', relayUrl: 'https://relay.example'));
    when(() => api.enroll(
          relayUrl: any(named: 'relayUrl'),
          ticket: any(named: 'ticket'),
          platform: any(named: 'platform'),
          osPushToken: any(named: 'osPushToken'),
        )).thenAnswer((_) async => (routingToken: 'rt', deviceId: 'dev'));
    when(() => api.subscribe(
          routingToken: any(named: 'routingToken'),
          publicKey: any(named: 'publicKey'),
          platform: any(named: 'platform'),
          label: any(named: 'label'),
          deviceId: any(named: 'deviceId'),
        )).thenAnswer((_) async => 'sub-1');
    when(() => keys.setSubscriptionId(any())).thenAnswer((_) async {});

    final container = makeContainer();
    await container.read(pushControllerProvider.future); // initial build: disconnected

    // After enrollment the local subscription id exists → reload sees connected.
    when(() => keys.subscriptionId()).thenAnswer((_) async => 'sub-1');

    await container.read(pushControllerProvider.notifier).connect();

    final state = container.read(pushControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.value!.isConnected, isTrue);
    verify(() => keys.setSubscriptionId('sub-1')).called(1);
  });

  test('connect with declined permission surfaces a PushException', () async {
    when(() => tokens.requestToken()).thenAnswer((_) async => null);

    final container = makeContainer();
    await container.read(pushControllerProvider.future);

    await container.read(pushControllerProvider.notifier).connect();

    final state = container.read(pushControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<PushException>());
    verifyNever(() => api.connect(
          platform: any(named: 'platform'),
          osPushToken: any(named: 'osPushToken'),
          publicKey: any(named: 'publicKey'),
        ));
  });
}
