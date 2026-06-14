import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'push_notifier.dart';

// Keys shared with the foreground isolate via FlutterForegroundTask's data store.
const _kBaseUrl = 'directPushBaseUrl';
const _kToken = 'directPushToken';
const _serviceId = 4242;

/// The **direct connection** push transport (no-Google Android, §9.3). Runs a
/// foreground service whose isolate holds the app's SSE stream
/// (`/api/assistant/stream`) open and posts a local notification on each
/// outbound turn — straight from the user's own Mantle over TLS, so there's no
/// relay, no FCM, no ntfy, and no sealed-box crypto. Android only.
class DirectPush {
  const DirectPush();

  /// Whether the foreground service is currently running.
  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

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

  /// Start the service with the current server URL + bearer token.
  Future<void> start({required String baseUrl, required String token}) async {
    await FlutterForegroundTask.saveData(key: _kBaseUrl, value: baseUrl);
    await FlutterForegroundTask.saveData(key: _kToken, value: token);

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

  Future<void> stop() => FlutterForegroundTask.stopService();
}

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

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final baseUrl = await FlutterForegroundTask.getData<String>(key: _kBaseUrl);
    final token = await FlutterForegroundTask.getData<String>(key: _kToken);
    if (baseUrl == null || baseUrl.isEmpty || token == null || token.isEmpty) {
      await FlutterForegroundTask.stopService();
      return;
    }
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
        if (e.response?.statusCode == 401) {
          await FlutterForegroundTask.stopService(); // token invalid — give up
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
        await PushNotifier.showPlain(
          title: name,
          body: _teaser((last?['text'] as String?) ?? ''),
          deepLink: '/chat/$agentSlug',
        );
        return;
      }
    } catch (_) {
      /* couldn't fetch — skip; the app reconciles on next open */
    }
  }

  String _teaser(String text, [int max = 140]) {
    final s = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.length > max ? '${s.substring(0, max - 1)}…' : s;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _cancel?.cancel();
    _dio?.close(force: true);
  }
}
