import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/auth_failure.dart';
import '../../core/network/mobile_build.dart';
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

// Set by the app while it rotates a login's bearer (`<sessionId>|<ms>`), so
// the service does not connect with the token being replaced. Not a secret.
const _kRotating = 'directPushRotating';

// Set by the service while a send of its own is on its way with a login's
// bearer (`<sessionId>|<ms>`), cleared once its answer's headers are in. A
// rotation of that login waits for it to clear before the refresh is posted.
const _kSending = 'directPushSending';

/// How long a rotation waits for the service's send to have its answer. Past
/// it the refresh is skipped (the next start, switch or resume tries again).
const kSendWaitMax = Duration(seconds: 20);

/// How long a send of the service's waits for its answer's headers. One
/// that has none by then is cancelled, so its mark clears and a rotation
/// waiting on it is not held for good.
const kSendHeadersMax = Duration(seconds: 30);

/// How long a rotation marker holds the service at most. A refresh is over
/// well within it (its client times out in seconds); an app killed mid
/// refresh leaves a marker that simply ages out.
const kRotationPauseMax = Duration(seconds: 90);

/// The marker the app leaves while it rotates [sessionId]'s bearer.
@visibleForTesting
String rotationMarker(String sessionId, DateTime at) =>
    '$sessionId|${at.millisecondsSinceEpoch}';

/// Whether [marker] says [sessionId]'s bearer is being rotated right now.
/// The service's send mark has the same shape, and is read the same way.
@visibleForTesting
bool rotationPending(String? marker, String sessionId, DateTime now) {
  if (marker == null || marker.isEmpty) return false;
  final cut = marker.lastIndexOf('|');
  if (cut <= 0) return false;
  if (marker.substring(0, cut) != sessionId) return false;
  final ms = int.tryParse(marker.substring(cut + 1));
  if (ms == null) return false;
  final age = now.difference(DateTime.fromMillisecondsSinceEpoch(ms));
  return age < kRotationPauseMax && !age.isNegative;
}

/// The bearer as stored once no rotation of it is running: wait while
/// [rotating], read, and read again if a rotation began meanwhile (the token
/// read may be the one being replaced). For a look at the token; a send
/// takes its bearer through [beginSend].
@visibleForTesting
Future<String?> readTokenWhenSettled({
  required Future<bool> Function() rotating,
  required Future<String?> Function() read,
  Duration poll = const Duration(milliseconds: 250),
}) async {
  while (true) {
    while (await rotating()) {
      await Future<void>.delayed(poll);
    }
    final token = await read();
    if (!await rotating()) return token;
  }
}

/// The bearer for one send of the service's, through a handshake with the
/// app's rotation of it (the service runs in its own isolate, outside the
/// app's refresh gate).
///
/// Two-sided, so the two can never both go ahead: the app marks the rotation
/// first and then looks for a send ([waitForSendToClear]); the service marks
/// its send first ([mark]) and then looks for a rotation. Whichever looks
/// second sees the other. A rotation seen here means the send stands down
/// and waits it out; otherwise the bearer is read with the send marked, so a
/// rotation that begins now waits for it, and the caller clears the mark
/// ([unmark]) once the answer's headers are in. Null (nothing marked) when
/// the login holds no bearer.
@visibleForTesting
Future<String?> beginSend({
  required Future<bool> Function() rotating,
  required Future<void> Function() mark,
  required Future<void> Function() unmark,
  required Future<String?> Function() read,
  Duration poll = const Duration(milliseconds: 250),
}) async {
  while (true) {
    while (await rotating()) {
      await Future<void>.delayed(poll);
    }
    await mark();
    if (await rotating()) {
      await unmark();
      continue;
    }
    final token = await read();
    if (token == null || token.isEmpty) await unmark();
    return token;
  }
}

/// One send of the service's, cancelled through [cancel] when its answer's
/// headers are not in within [within]. [endSend] clears the send's mark
/// whichever way it ends: headers in, a failure, or the cancel.
@visibleForTesting
Future<T> sendWithin<T>({
  required CancelToken cancel,
  required Future<T> Function() send,
  required Future<void> Function() endSend,
  Duration within = kSendHeadersMax,
}) async {
  final timer = Timer(within, () {
    if (!cancel.isCancelled) cancel.cancel('no answer within $within');
  });
  try {
    return await send();
  } finally {
    timer.cancel();
    await endSend();
  }
}

/// The options for the service's conversations fetch: the bearer, and an
/// answer within [kSendHeadersMax] (past it the fetch fails, and its mark
/// clears).
@visibleForTesting
Options conversationsFetchOptions(String token) => Options(
      headers: {'Authorization': 'Bearer $token'},
      receiveTimeout: kSendHeadersMax,
    );

/// The app's side of [beginSend]: with the rotation already marked, wait for
/// a send of the service's to have its answer. False when it does not within
/// [timeout]: the refresh must not be posted under it.
@visibleForTesting
Future<bool> waitForSendToClear({
  required Future<bool> Function() sending,
  Duration timeout = kSendWaitMax,
  Duration poll = const Duration(milliseconds: 100),
}) async {
  final until = DateTime.now().add(timeout);
  while (await sending()) {
    if (!DateTime.now().isBefore(until)) return false;
    await Future<void>.delayed(poll);
  }
  return true;
}

/// Whether a refusal of a send made with [used] was of a token the app has
/// since replaced, judged by the token as [settled] reads it (outside any
/// rotation of it: in the middle of one, the store may still hold [used]).
@visibleForTesting
Future<bool> refusedTokenReplaced({
  required String? used,
  required Future<String?> Function() settled,
}) async {
  final now = await settled();
  return now != null && now.isNotEmpty && now != used;
}

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

  /// Hold the service's reconnects while [sessionId]'s bearer rotates: a
  /// connect with the token being replaced, landing after its successor was
  /// used, would end every session of the login. The rotation is marked
  /// first, then a send the service already has on its way is waited for
  /// ([beginSend] is the other side). False when that send has no answer in
  /// [kSendWaitMax]: the refresh is then skipped.
  Future<bool> pauseForRotation(String sessionId) async {
    if (!supported) return true;
    await FlutterForegroundTask.saveData(
      key: _kRotating,
      value: rotationMarker(sessionId, DateTime.now()),
    );
    // A service that is not running sends nothing (one starting now sees
    // the rotation marked).
    if (!await FlutterForegroundTask.isRunningService) return true;
    return waitForSendToClear(
      sending: () async => rotationPending(
        await FlutterForegroundTask.getData<String>(key: _kSending),
        sessionId,
        DateTime.now(),
      ),
    );
  }

  /// The rotation is over (stored, or given up): reconnects may go.
  Future<void> resumeAfterRotation(String sessionId) async {
    if (!supported) return;
    await FlutterForegroundTask.removeData(key: _kRotating);
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

  /// The connect on its way, cancelled with the service or when its headers
  /// are late.
  CancelToken? _attempt;
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
    // A mark left by a service that was killed mid send: nothing of this
    // one's is on its way yet.
    await _endSend();
    // The bearer goes on each request, read fresh: the app rotates it.
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      followRedirects: false,
      connectTimeout: const Duration(seconds: 15),
    ))
      ..interceptors.add(MobileBuildInterceptor());
    _cancel = CancelToken();
    unawaited(_run());
  }

  Future<void> _run() async {
    var backoff = const Duration(seconds: 1);
    const maxBackoff = Duration(seconds: 30);
    String? used;
    while (!(_cancel?.isCancelled ?? true)) {
      try {
        // The bearer is read again before every connect: the app rotates it
        // (token refresh), and a rotated token used after its successor ends
        // every session of the login on the brain. Never in the middle of
        // a rotation either, and no rotation is posted while the connect is
        // on its way (the handshake in [beginSend]).
        final token = await _beginSend();
        if (token == null || token.isEmpty) {
          await FlutterForegroundTask.stopService();
          return;
        }
        used = token;
        // One token per connect: the service's stop cancels it, and so does
        // a connect whose headers are late (a timeout on the whole stream
        // would end an idle one).
        final attempt = CancelToken();
        _attempt = attempt;
        if (_cancel?.isCancelled ?? true) {
          await _endSend();
          return;
        }
        // The headers are in, the connect failed or it was cancelled: the
        // send's mark clears either way, and a rotation may go.
        final res = await sendWithin(
          cancel: attempt,
          send: () => _dio!.get<ResponseBody>(
            '/api/assistant/stream',
            options: Options(
              responseType: ResponseType.stream,
              headers: {'Authorization': 'Bearer $token'},
            ),
            cancelToken: attempt,
          ),
          endSend: _endSend,
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
        // The service stopped. A connect cancelled for want of headers is
        // tried again after the backoff.
        if (CancelToken.isCancel(e) && (_cancel?.isCancelled ?? true)) return;
        if (isAuthFailure(e)) {
          // Refused with a token the app has since replaced (a rotation
          // landed while this connect was on its way): connect again with
          // the new one. Judged once any rotation running is over: in the
          // middle of one the store still holds the token being replaced.
          if (await refusedTokenReplaced(
            used: used,
            settled: _settledToken,
          )) {
            continue;
          }
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

  /// The bearer for one send, with the send marked until [_endSend].
  Future<String?> _beginSend() async {
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) return null;
    return beginSend(
      rotating: () async => rotationPending(
        await FlutterForegroundTask.getData<String>(key: _kRotating),
        sessionId,
        DateTime.now(),
      ),
      mark: () async {
        await FlutterForegroundTask.saveData(
          key: _kSending,
          value: rotationMarker(sessionId, DateTime.now()),
        );
      },
      unmark: _endSend,
      read: () => TokenStore.readDirect(sessionId),
    );
  }

  /// The send marked by [_beginSend] has its answer.
  Future<void> _endSend() async {
    try {
      await FlutterForegroundTask.removeData(key: _kSending);
    } catch (_) {
      /* the mark ages out on its own */
    }
  }

  /// The login's bearer as stored now, read outside any rotation of it.
  Future<String?> _settledToken() async {
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) return null;
    return readTokenWhenSettled(
      rotating: () async => rotationPending(
        await FlutterForegroundTask.getData<String>(key: _kRotating),
        sessionId,
        DateTime.now(),
      ),
      read: () => TokenStore.readDirect(sessionId),
    );
  }

  /// Fetch the agent's latest message and post a notification.
  Future<void> _notify(String agentSlug) async {
    try {
      // The stream may have been opened weeks of rotations ago: this fetch
      // takes the bearer as it is now, never the one the stream began with,
      // and holds a rotation off until its answer is in.
      final token = await _beginSend();
      if (token == null || token.isEmpty) return;
      final Response<Map<String, dynamic>> res;
      try {
        res = await _dio!.get<Map<String, dynamic>>(
          '/api/assistant/conversations',
          options: conversationsFetchOptions(token),
        );
      } finally {
        await _endSend();
      }
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
    _attempt?.cancel();
    _dio?.close(force: true);
    // A send cancelled here has no answer coming: its mark goes with it.
    await _endSend();
  }
}
