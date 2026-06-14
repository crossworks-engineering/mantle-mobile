import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/push/apns_bridge.dart';
import 'package:mantle_companion/data/push/push_api.dart';
import 'package:mantle_companion/data/push/push_keys.dart';
import 'package:mantle_companion/features/settings/push/push_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockPushApi extends Mock implements PushApi {}

class MockPushKeyStore extends Mock implements PushKeyStore {}

class MockApnsBridge extends Mock implements ApnsBridge {}

void main() {
  late MockPushApi api;
  late MockPushKeyStore keys;
  late MockApnsBridge bridge;

  setUp(() {
    api = MockPushApi();
    keys = MockPushKeyStore();
    bridge = MockApnsBridge();
    // Defaults for build()/_load(): disconnected, no devices.
    when(() => keys.subscriptionId()).thenAnswer((_) async => null);
    when(() => api.list()).thenAnswer((_) async => <PushDevice>[]);
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        pushApiProvider.overrideWithValue(api),
        apnsBridgeProvider.overrideWithValue(bridge),
        pushKeyStoreProvider.overrideWith((ref) async => keys),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('connect runs permission → keypair → connect → enroll → subscribe', () async {
    when(() => bridge.requestPermissionAndToken()).thenAnswer((_) async => 'apns-token');
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
    when(() => bridge.requestPermissionAndToken()).thenAnswer((_) async => null);

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
