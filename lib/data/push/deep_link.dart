import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'notification_tap.dart';

/// Surfaces notification taps into the app so a tap can jump to the right
/// screen (an approval push → `/pending`, a reminder → that event), on the
/// login the push was for.
///
/// Two arrival paths feed one [pending] notifier:
///   - iOS: native taps come over the `mantle/push` MethodChannel — the
///     AppDelegate invokes `deepLink` with the tapped push's fields, and a
///     cold-launch tap is fetched once via `getInitialDeepLink` (the tap
///     fires before Dart attaches its handler).
///   - Both platforms: the SHARED flutter_local_notifications tap callback +
///     app-launch details feed [offer] with the local payload (an Android
///     push, a direct-connection message, an event alarm; see
///     local_notifications.dart).
///
/// Every tap is parsed into a [NotificationTap], whose route passes only the
/// app's own routes ([sanitizeDeepLink]): a push payload is data from the
/// network, not a command. The root widget listens to [pending], picks the
/// login and routes, then clears it. Singleton so the platform channel
/// handler and the local-notification callback share one queue.
class DeepLinkRouter {
  DeepLinkRouter._();

  static final DeepLinkRouter instance = DeepLinkRouter._();

  static const _channel = MethodChannel('mantle/push');

  /// The most recent un-consumed tap, or null. The root widget watches this,
  /// acts on it, and resets it to null.
  final ValueNotifier<NotificationTap?> pending =
      ValueNotifier<NotificationTap?>(null);

  bool _started = false;

  /// Begin listening for taps. Idempotent — safe to call once at startup.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Warm (foreground/background) taps: native → Dart over the shared channel.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'deepLink') {
        offer(call.arguments);
      }
      return null;
    });

    // Cold launch via a notification tap: the native side stored the tap
    // before Dart was ready, so pull it once now.
    try {
      final initial = await _channel.invokeMethod<Object?>('getInitialDeepLink');
      offer(initial);
    } on PlatformException {
      /* no initial link */
    } on MissingPluginException {
      /* not iOS / channel not wired (e.g. unit tests) */
    }
  }

  /// Queue a tap for the root widget to act on: a bare path, a local
  /// payload string or the iOS channel's map ([NotificationTap.parse]). A tap
  /// with no route of the app's own is dropped.
  void offer(Object? raw) {
    final tap = NotificationTap.parse(raw);
    if (tap != null && tap.route != null) pending.value = tap;
  }
}

/// One segment of an id or slug: what Mantle mints (UUIDs, kebab slugs) and
/// nothing that could be read as a path or query trick.
const _seg = r'[A-Za-z0-9._~-]+';

/// The routes a notification may open. Mirrors `app_router.dart`; a route
/// added there is not reachable from a push until it is added here too.
final List<RegExp> _allowedDeepLinks = [
  RegExp(r'^/$'),
  RegExp(r'^/chat$'),
  RegExp('^/chat/$_seg\$'),
  RegExp(r'^/pending$'),
  RegExp(r'^/pages$'),
  RegExp('^/pages/$_seg\$'),
  RegExp(r'^/search$'),
  RegExp(r'^/files$'),
  RegExp('^/files/image/$_seg\$'),
  RegExp(r'^/notes$'),
  RegExp('^/notes/$_seg\$'),
  RegExp(r'^/tasks$'),
  RegExp('^/tasks/$_seg\$'),
  RegExp(r'^/journal$'),
  RegExp(r'^/events$'),
  RegExp('^/events/$_seg\$'),
  RegExp(r'^/settings$'),
  RegExp(r'^/settings/(appearance|notifications)$'),
];

/// Reduce a link from a notification payload to a route this app owns, or
/// null. Rules: it must be an absolute in-app path (no scheme, no host, no
/// `//`), its path must match one of the app's routes exactly, and only the
/// Files routes keep a query string (they take `?path=` / `?name=`).
String? sanitizeDeepLink(String? link) {
  if (link == null) return null;
  final s = link.trim();
  if (s.isEmpty || !s.startsWith('/') || s.startsWith('//')) return null;
  if (s.contains('\\') || s.codeUnits.any((c) => c < 0x20 || c == 0x7f)) {
    return null;
  }
  // Dot segments are checked on the raw text: Uri.parse folds `/a/../b` into
  // `/b` before the path is visible, which is exactly the trick to refuse.
  final rawPath = s.split(RegExp(r'[?#]')).first;
  if (rawPath.split('/').any((seg) => seg == '.' || seg == '..')) return null;
  final uri = Uri.tryParse(s);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final path = uri.path;
  if (!_allowedDeepLinks.any((r) => r.hasMatch(path))) return null;
  if (path.startsWith('/files') && uri.hasQuery) {
    return Uri(path: path, query: uri.query).toString();
  }
  return path;
}
