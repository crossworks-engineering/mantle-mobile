import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'apns_bridge.g.dart';

/// Bridge to the native iOS APNs registration (see ios/Runner/AppDelegate.swift).
/// There's no Flutter plugin for raw APNs tokens without Firebase, so we use a
/// tiny MethodChannel: request notification permission, register with APNs, and
/// return the device token. Android (FCM) is wired separately in M4.
class ApnsBridge {
  const ApnsBridge();

  static const _channel = MethodChannel('mantle/push');

  /// Request notification permission and register with APNs. Resolves to the
  /// hex APNs device token, or null if the user denied permission or
  /// registration failed.
  Future<String?> requestPermissionAndToken() async {
    try {
      return await _channel.invokeMethod<String>('requestAuthorizationAndRegister');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null; // not iOS / channel not wired (e.g. unit tests)
    }
  }

  /// Whether notification permission is currently granted.
  Future<bool> isAuthorized() async {
    try {
      return await _channel.invokeMethod<bool>('isAuthorized') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
ApnsBridge apnsBridge(Ref ref) => const ApnsBridge();
