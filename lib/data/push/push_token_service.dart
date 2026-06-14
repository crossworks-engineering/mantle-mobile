import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'apns_bridge.dart';

part 'push_token_service.g.dart';

/// One OS push token + the platform it came from.
typedef PushToken = ({String platform, String token});

/// Resolves the OS push token for the running platform: APNs on iOS (via the
/// native bridge), FCM on Android (via firebase_messaging). Requests
/// notification permission as part of the call.
class PushTokenService {
  PushTokenService(this._apns);

  final ApnsBridge _apns;

  /// Request permission and return `(platform, token)`, or null if the user
  /// declined or no token is available.
  Future<PushToken?> requestToken() async {
    if (Platform.isIOS) {
      final token = await _apns.requestPermissionAndToken();
      return token == null ? null : (platform: 'ios', token: token);
    }
    if (Platform.isAndroid) {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
      final token = await messaging.getToken();
      return token == null ? null : (platform: 'android', token: token);
    }
    return null;
  }
}

@Riverpod(keepAlive: true)
PushTokenService pushTokenService(Ref ref) => PushTokenService(ref.watch(apnsBridgeProvider));
