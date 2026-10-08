import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/auth_failure.dart';
import '../auth/token_store.dart';
import 'notification_tap.dart';
import 'push_notifier.dart';
import 'push_text.dart';

part 'direct_push_service.g.dart';

// Keys shared with the foreground isolate via FlutterForegroundTask's data
// store. That store is plain SharedPreferences, so ONLY the server address
// goes through it; the bearer is read by the isolate straight from secure
// storage ([TokenStore.readDirect]).
const _kBaseUrl = 'directPushBaseUrl';
// Which login's stream this is. Not a secret: it only names the secure-storage
// item the service reads the bearer from.
const _kSessionId = 'directPushSessionId';

/// The key an earlier version used to hand the bearer to the isolate through
/// the plain store. Scrubbed on every start and stop so an upgraded install
/// does not keep a cleartext copy around.
const _kLegacyToken = 'directPushToken';
const _serviceId = 4242;

/// The **direct connection** push transport (no-Google Android, §9.3). Runs a
/// foreground service whose isolate holds the app's SSE stream
/// (`/api/assistant/stream`) open and posts a local notification on each
/// outbound turn — straight from the user's own Mantle over TLS, so there's no
/// relay, no FCM, no ntfy, and no sealed-box crypto. Android only.
class DirectPush {
  const DirectPush();

  /// The direct connection exists on Android only.
  bool get supported => Platform.isAndroid;

  /// Whether the foreground service is currently running.
  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  /// Whether the service is running for exactly this login on this brain, so
  /// a start that would only restart it can be skipped.
  Future<bool> isRunningFor({
    required String baseUrl,
    required String sessionId,
  }) async {
    if (!await FlutterForegroundTask.isRunningService) return false;
    final url = await FlutterForegroundTask.getData<String>(key: _kBaseUrl);
    final id = await FlutterForegroundTask.getData<String>(key: _kSessionId);
    return url == baseUrl && id == sessionId;
  }

  /// True when a build from before several logins started the service: it
  /// left the address in the service's store but no login id, and the
  /// service stops itself at its next start for want of one. [stop] clears
  /// the store, so an address without an id means the person had it on.
  Future<bool> startedByOlderBuild() async {
    final url = await FlutterForegroundTask.getData<String>(key: _kBaseUrl);
    final id = await FlutterForegroundTask.getData<String>(key: _kSessionId);
    return (url != null && url.isNotEmpty) && (id == null || id.isEmpty);
  }

  /// Request the runtime bits the foreground service needs (notifications +
  /// battery-optimization exemption). Best-effort.
  Future<void> requestPermissions() async {
    final p = await FlutterForegroundTask.checkNotificationPermission();
    if (p != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  /// Start the service against [baseUrl]. The isolate reads the bearer from
  /// secure storage itself, so nothing secret is written here.
  Future<void> start({required String baseUrl, required String sessionId}) async {
    await FlutterForegroundTask.removeData(key: _kLegacyToken);
    await FlutterForegroundTask.saveData(key: _kBaseUrl, value: baseUrl);
    await FlutterForegroundTask.saveData(key: _kSessionId, value: sessionId);

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mantle_direct',
        channelName: 'Background connection',
        channelDescription: 'Keeps Mantle connected to deliver notifications without Google Play.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Mantle connected',
      notificationText: 'Listening for your assistant.',
      callback: startDirectPushCallback,
    );
  }

  /// Stop the service and forget everything it was given, so a stopped
  /// service cannot auto-restart on boot against a session that has ended.
  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    await FlutterForegroundTask.clearAllData();
  }
}

/// The direct-connection transport. A provider so tests can replace the
/// platform plugin with a fake.
@Riverpod(keepAlive: true)
DirectPush directPush(Ref ref) => const DirectPush();

/// Foreground-isolate entry point. Top-level + AOT-entry annotated.
@pragma('vm:entry-point')
void startDirectPushCallback() {
  FlutterForegroundTask.setTaskHandler(_DirectPushTaskHandler());
}

/// Parse one SSE line → (agentSlug, direction). Inlined (not imported from the
/// Riverpod stream file) to keep the foreground isolate lean. Mirrors
/// data/chat/conversation_stream.dart's parseSseLine.
({String agentSlug, String direction})? _parseSse(String line) {
  if (!line.startsWith('data:')) return null;
  final body = line.substring(5).trim();
  if (body.isEmpty) return null;
  try {
    final j = jsonDecode(body);
    if (j is Map<String, dynamic>) {
      final slug = j['agentSlug'];
      if (slug is String && slug.isNotEmpty) {
        final dir = j['direction'];
        return (agentSlug: slug, direction: dir is String ? dir : '');
      }
    }
  } catch (_) {
    /* malformed — ignore */
  }
  return null;
}

class _DirectPushTaskHandler extends TaskHandler {
  CancelToken? _cancel;
  Dio? _dio;
  String? _sessionId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final baseUrl = await FlutterForegroundTask.getData<String>(key: _kBaseUrl);
    final sessionId =
        await FlutterForegroundTask.getData<String>(key: _kSessionId);
    final token = (sessionId == null || sessionId.isEmpty)
        ? null
        : await TokenStore.readDirect(sessionId);
    if (baseUrl == null || baseUrl.isEmpty || token == null || token.isEmpty) {
      // Signed out (or never signed in): nothing to listen for.
      await FlutterForegroundTask.stopService();
      return;
    }
    _sessionId = sessionId;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'Authorization': 'Bearer $token'},
      followRedirects: false,
      connectTimeout: const Duration(seconds: 15),
    ));
    _cancel = CancelToken();
    unawaited(_run());
  }

  Future<void> _run() async {
    var backoff = const Duration(seconds: 1);
    const maxBackoff = Duration(seconds: 30);
    while (!(_cancel?.isCancelled ?? true)) {
      try {
        final res = await _dio!.get<ResponseBody>(
          '/api/assistant/stream',
          options: Options(responseType: ResponseType.stream),
          cancelToken: _cancel,
        );
        backoff = const Duration(seconds: 1);
        final lines = res.data!.stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final line in lines) {
          final event = _parseSse(line);
          if (event != null && event.direction == 'outbound') {
            await _notify(event.agentSlug);
          }
        }
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) return;
        if (isAuthFailure(e)) {
          // Token revoked or expired — give up rather than reconnect forever.
          await FlutterForegroundTask.stopService();
          return;
        }
        /* transient — fall through to backoff */
      } catch (_) {
        /* unexpected — fall through to backoff */
      }
      await Future<void>.delayed(backoff);
      backoff = backoff * 2 > maxBackoff ? maxBackoff : backoff * 2;
    }
  }

  /// Fetch the agent's latest message and post a notification.
  Future<void> _notify(String agentSlug) async {
    try {
      final res = await _dio!.get<Map<String, dynamic>>('/api/assistant/conversations');
      final list = (res.data?['conversations'] as List?) ?? const [];
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        if (m['slug'] != agentSlug) continue;
        final name = (m['name'] as String?) ?? agentSlug;
        final last = m['lastMessage'] as Map<String, dynamic>?;
        // Same fallback as the FCM path: the SSE event fires on the reply's
        // pending insert too, when lastMessage.text is still empty.
        final text = pushNotificationText({'t': name, 'b': last?['text']});
        await PushNotifier.showPlain(
          title: text.title,
          body: text.body,
          // The stream is one login's: a tap opens the chat on that login.
          payload: NotificationTap(
            deepLink: '/chat/$agentSlug',
            sessionId: _sessionId,
          ).toPayload(),
        );
        return;
      }
    } catch (_) {
      /* couldn't fetch — skip; the app reconciles on next open */
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _cancel?.cancel();
    _dio?.close(force: true);
  }
}
