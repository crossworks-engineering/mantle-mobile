import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';

part 'push_api.g.dart';

/// One enrolled device as Mantle reports it (metadata only).
class PushDevice {
  const PushDevice({required this.id, required this.platform, this.label});
  final String id;
  final String platform; // 'ios' | 'android'
  final String? label;
}

/// Talks to Mantle's `/api/push/*` endpoints (over the authed [Dio]) and, for
/// the one enrollment hop, directly to the relay's `/enroll` (with a bare client
/// so the Mantle bearer never leaves the host).
class PushApi {
  PushApi(this._dio);

  final Dio _dio;

  /// `POST /api/push/connect` → `{ticket, relayUrl}`. Mantle lazily generates +
  /// registers its instance token with the relay and mints a short-lived
  /// enrollment ticket bound to this device's OS push token.
  Future<({String ticket, String relayUrl})> connect({
    required String platform,
    required String osPushToken,
    required String publicKey,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/push/connect',
      data: {'platform': platform, 'osPushToken': osPushToken, 'publicKey': publicKey},
    );
    final d = res.data ?? const {};
    return (ticket: d['ticket'] as String, relayUrl: d['relayUrl'] as String);
  }

  /// `POST <relayUrl>/enroll` → `{routingToken, deviceId}`. A direct call to the
  /// relay, not Mantle — uses a fresh [Dio] with no auth interceptor so the
  /// Mantle bearer isn't sent to the relay.
  Future<({String routingToken, String? deviceId})> enroll({
    required String relayUrl,
    required String ticket,
    required String platform,
    required String osPushToken,
  }) async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
    final res = await dio.post<Map<String, dynamic>>(
      '$relayUrl/enroll',
      data: {'ticket': ticket, 'platform': platform, 'osPushToken': osPushToken},
    );
    final d = res.data ?? const {};
    return (routingToken: d['routingToken'] as String, deviceId: d['deviceId'] as String?);
  }

  /// `POST /api/push/subscriptions` — hand Mantle the relay routing token + the
  /// device public key so it can seal + send. Returns the subscription id.
  Future<String> subscribe({
    required String routingToken,
    required String publicKey,
    required String platform,
    String? label,
    String? deviceId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/push/subscriptions',
      data: {
        'routingToken': routingToken,
        'publicKey': publicKey,
        'platform': platform,
        'label': ?label,
        'deviceId': ?deviceId,
      },
    );
    return (res.data?['id'] as String?) ?? '';
  }

  /// `GET /api/push/subscriptions` — the owner's enrolled devices (metadata).
  Future<List<PushDevice>> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/push/subscriptions');
    final list = (res.data?['devices'] as List?) ?? const [];
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return PushDevice(
        id: m['id'] as String,
        platform: m['platform'] as String,
        label: m['label'] as String?,
      );
    }).toList();
  }

  /// `DELETE /api/push/subscriptions/:id` — unpair a device (Mantle also tells
  /// the relay to drop its row).
  Future<void> unsubscribe(String id) => _dio.delete('/api/push/subscriptions/$id');
}

@Riverpod(keepAlive: true)
PushApi pushApi(Ref ref) => PushApi(ref.watch(dioProvider));
