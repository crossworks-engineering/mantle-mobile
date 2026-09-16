import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Surfaces notification-tap deep links into the app so a tap can jump to the
/// right screen (e.g. an approval push → `/pending`, a message → `/chat/<slug>`).
///
/// Two arrival paths feed one [pending] notifier:
///   - iOS: native taps come over the `mantle/push` MethodChannel — the
///     AppDelegate invokes `deepLink` with the tapped link, and a cold-launch
///     tap is fetched once via `getInitialDeepLink` (the tap fires before Dart
///     attaches its handler).
///   - Android: the SHARED flutter_local_notifications tap callback + app-
///     launch details feed [offer], with payload→route translation for event
///     alarms (see local_notifications.dart).
///
/// Every link passes through [sanitizeDeepLink] first: a push payload is
/// data from the network, not a command, so only the app's own routes get
/// through. The root widget listens to [pending] and routes via go_router,
/// then clears it. Singleton so the platform channel handler and the Android
/// notifier share one queue.
class DeepLinkRouter {
  DeepLinkRouter._();

  static final DeepLinkRouter instance = DeepLinkRouter._();

  static const _channel = MethodChannel('mantle/push');

  /// The most recent un-consumed deep link, or null. The root widget watches
  /// this, navigates, and resets it to null.
  final ValueNotifier<String?> pending = ValueNotifier<String?>(null);

  bool _started = false;

  /// Begin listening for taps. Idempotent — safe to call once at startup.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Warm (foreground/background) taps: native → Dart over the shared channel.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'deepLink') {
        offer(call.arguments as String?);
      }
      return null;
    });

    // Cold launch via a notification tap: the native side stored the link
    // before Dart was ready, so pull it once now.
    try {
      final initial = await _channel.invokeMethod<String>('getInitialDeepLink');
      offer(initial);
    } on PlatformException {
      /* no initial link */
    } on MissingPluginException {
      /* not iOS / channel not wired (e.g. unit tests) */
    }
  }

  /// Queue a deep link for the root widget to consume. Anything that is not
  /// one of the app's own routes is dropped ([sanitizeDeepLink]).
  void offer(String? link) {
    final safe = sanitizeDeepLink(link);
    if (safe != null) pending.value = safe;
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
  RegExp(r'^/journal$'),
  RegExp(r'^/events$'),
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
