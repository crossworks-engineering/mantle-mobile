import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';

/// The header that names this phone build to the brain: `1.15.0+27`, the
/// store version and the build number after `+`.
///
/// A brain from the workspaces release (W7e) serves a login that is not an
/// Admin user only to a build at or above its minimum (27). Without the
/// header it answers a member's QR claim with 426 "update the app". Sent on
/// every request so any route can tell which build is asking.
const kMobileBuildHeader = 'X-Jackdaw-Mobile';

/// This build's header value, read once from the bundle. Null when the
/// bundle cannot be read (a unit test without the platform channel): the
/// request then goes without the header, which a brain reads as an older
/// build, never as a newer one.
class MobileBuild {
  MobileBuild._();

  static Future<String?>? _value;

  static Future<String?> header() => _value ??= _read();

  static Future<String?> _read() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final build = info.buildNumber.trim();
      if (version.isEmpty) return build.isEmpty ? null : build;
      return build.isEmpty ? version : '$version+$build';
    } catch (_) {
      return null;
    }
  }

  /// Answer [value] instead of the bundle's (null: no header at all).
  @visibleForTesting
  static void debugOverride(String? value) => _value = Future.value(value);

  /// Read the bundle again on the next request.
  @visibleForTesting
  static void debugReset() => _value = null;
}

/// Adds [kMobileBuildHeader] to every request of the client it is put on.
class MobileBuildInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final value = await MobileBuild.header();
    if (value != null && value.isNotEmpty) {
      options.headers[kMobileBuildHeader] = value;
    }
    handler.next(options);
  }
}
