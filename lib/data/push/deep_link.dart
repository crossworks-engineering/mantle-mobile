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

/// The workspace each review kind waits in, as the brain names it
/// (mantle `reviewDeepLink`): a "waiting for approval" push opens
/// `/<workspace>?review=<id>`.
const Map<String, String> reviewWorkspaces = {
  'page': '/pages',
  'note': '/notes',
  'table': '/tables',
  'draw': '/draw',
  'file': '/files',
};

/// Of those, the workspaces this app has a screen for. A table or a drawing
/// has no screen on the phone, so its push opens Home.
const Set<String> _phoneWorkspaces = {'/pages', '/notes', '/files'};

/// The old review link (`/team-admin?view=review[&item=<id>]`), from a brain
/// older than review in each workspace.
const String _legacyReviewPath = '/team-admin';

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// An item waiting for an admin's approval, named by a push: its id and the
/// workspace it waits in. [workspace] is null for an old link, which does not
/// say the kind.
typedef ReviewLink = ({String id, String? workspace});

/// The parsed in-app link, or null. Rules: it must be an absolute in-app path
/// (no scheme, no host, no `//`), with no backslash, control character or
/// dot segment.
Uri? _inAppUri(String? link) {
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
  return uri;
}

/// True for the old review link, with or without an item.
bool _isLegacyReview(Uri uri) =>
    uri.path == _legacyReviewPath && uri.queryParameters['view'] == 'review';

/// Reduce a link from a notification payload to a route this app owns, or
/// null. Its path must match one of the app's routes exactly, and only the
/// Files routes keep a query string (they take `?path=` / `?name=`).
///
/// A review link's workspace without a phone screen (Tables, Draw) and the
/// old review link open Home. The `review` id is never kept here: it is for
/// an admin only, and [reviewRoute] adds it back once the login is known to
/// be one.
String? sanitizeDeepLink(String? link) {
  final uri = _inAppUri(link);
  if (uri == null) return null;
  final path = uri.path;
  if (path == '/tables' || path == '/draw' || _isLegacyReview(uri)) return '/';
  if (!_allowedDeepLinks.any((r) => r.hasMatch(path))) return null;
  if (path.startsWith('/files') && uri.hasQuery) {
    if (!uri.queryParameters.containsKey('review')) {
      return Uri(path: path, query: uri.query).toString();
    }
    final query = Map.of(uri.queryParameters)..remove('review');
    return query.isEmpty
        ? path
        : Uri(path: path, queryParameters: query).toString();
  }
  return path;
}

/// The item a review push names, or null. Only a UUID is an item id: any
/// other `review` (or `item`) value is dropped, and so is the link.
ReviewLink? reviewLinkOf(String? link) {
  final uri = _inAppUri(link);
  if (uri == null) return null;
  if (_isLegacyReview(uri)) {
    final id = uri.queryParameters['item'];
    return id != null && _uuid.hasMatch(id) ? (id: id, workspace: null) : null;
  }
  if (!reviewWorkspaces.containsValue(uri.path)) return null;
  final id = uri.queryParameters['review'];
  return id != null && _uuid.hasMatch(id) ? (id: id, workspace: uri.path) : null;
}

/// Where an admin's review tap opens: the workspace's screen with the item
/// named (`/pages?review=<id>`), or Home when the phone has no screen for
/// that workspace or the kind is not known. [kind] is the item's kind as the
/// brain reports it, for an old link that does not say.
String reviewRoute(ReviewLink link, {String? kind}) {
  final workspace = link.workspace ?? reviewWorkspaces[kind];
  if (workspace == null || !_phoneWorkspaces.contains(workspace)) return '/';
  return Uri(path: workspace, queryParameters: {'review': link.id}).toString();
}
