import 'dart:convert';

import 'deep_link.dart';

/// Prefix identifying event-alarm payloads (`event-alarm:<id>:<ms>:<kind>`).
/// Lives here (not in event_alarms.dart) because the tap mapping needs it to
/// translate payloads and the alarm service needs it to mint them.
const String kEventAlarmPayloadPrefix = 'event-alarm:';

/// One tapped notification, as the app routes it: where to go, and which
/// login it was for.
///
/// Every arrival path makes one of these:
///   - a brain push (iOS through the notification extension and the
///     `mantle/push` channel, Android through the FCM data message): the
///     sealed payload's `deepLink`, `itemLink`, `brainId` and `loginId`;
///   - a direct-connection notification (Android without Google): the chat
///     link and the device-local [sessionId] of the stream it came from;
///   - an event alarm this phone scheduled: the event's id, in the payload.
///
/// Nothing in it is trusted: [route] passes only the app's own routes
/// ([sanitizeDeepLink]), and the ids only ever select among logins the
/// device already holds.
class NotificationTap {
  const NotificationTap({
    this.deepLink,
    this.itemLink,
    this.brainId,
    this.loginId,
    this.sessionId,
  });

  /// The brain's link for the push (a chat thread, `/pending`).
  final String? deepLink;

  /// The item the push is about (`/events/<id>`), set by a brain that names
  /// it. Preferred over [deepLink] when it is one of the app's routes.
  final String? itemLink;

  /// The brain and the login on it the push was sealed for. Both or neither:
  /// a login id alone says nothing (two brains made from one dump share
  /// login ids).
  final String? brainId;
  final String? loginId;

  /// The device-local session a notification came from, when the phone made
  /// it itself (the direct connection).
  final String? sessionId;

  /// The screen to open: the item when the app knows its route, else the
  /// brain's link, else nothing.
  String? get route => sanitizeDeepLink(itemLink) ?? sanitizeDeepLink(deepLink);

  /// The item waiting for approval the push names, if any. For an admin
  /// only: the tap router opens it ([reviewRoute]) once the login in use is
  /// known to be one, and follows [route] otherwise.
  ReviewLink? get review => reviewLinkOf(itemLink) ?? reviewLinkOf(deepLink);

  /// True when the push names the login it was for.
  bool get namesLogin =>
      (brainId?.isNotEmpty ?? false) && (loginId?.isNotEmpty ?? false);

  /// From whatever a platform hands over: a bare path (an older native side),
  /// a JSON object string (a local notification's payload), or a map (the
  /// iOS channel). Null when there is nothing to route.
  static NotificationTap? parse(Object? raw) {
    if (raw is Map) return _fromMap(raw);
    if (raw is! String) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith(kEventAlarmPayloadPrefix)) return _fromEventAlarm(s);
    if (s.startsWith('{')) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) return _fromMap(decoded);
      } on FormatException {
        return null;
      }
      return null;
    }
    return NotificationTap(deepLink: s);
  }

  /// The local-notification payload for this tap: what [parse] reads back.
  String toPayload() => jsonEncode({
        'deepLink': ?deepLink,
        'itemLink': ?itemLink,
        'brainId': ?brainId,
        'loginId': ?loginId,
        'sessionId': ?sessionId,
      });

  static NotificationTap? _fromMap(Map<dynamic, dynamic> m) {
    String? str(String key) {
      final v = m[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    final tap = NotificationTap(
      deepLink: str('deepLink'),
      itemLink: str('itemLink'),
      brainId: str('brainId'),
      loginId: str('loginId'),
      sessionId: str('sessionId'),
    );
    return tap.deepLink == null && tap.itemLink == null ? null : tap;
  }

  /// `event-alarm:<id>:<ms>:<kind>` → that event. An alarm belongs to the
  /// login in use when it was armed, and a switch cancels them all, so it
  /// names no login.
  static NotificationTap? _fromEventAlarm(String payload) {
    final rest = payload.substring(kEventAlarmPayloadPrefix.length);
    final id = rest.split(':').first;
    if (id.isEmpty) return const NotificationTap(deepLink: '/events');
    return NotificationTap(itemLink: '/events/$id', deepLink: '/events');
  }
}

/// What a tap does about logins, decided before anything navigates.
sealed class TapDecision {
  const TapDecision();
}

/// Open [route] on the login in use.
class FollowOnActive extends TapDecision {
  const FollowOnActive(this.route);
  final String? route;
}

/// Make [sessionId] the login in use, then open [route].
class SwitchThenFollow extends TapDecision {
  const SwitchThenFollow(this.sessionId, this.route);
  final String sessionId;
  final String? route;
}

/// The push is for a login this device cannot pick out (not held, or the
/// brain id is held under two addresses): open the app on the login in use
/// and follow nothing of the payload.
class OpenHome extends TapDecision {
  const OpenHome();
}

/// What the tap resolver knows of one held login.
typedef HeldLogin = ({
  String id,
  String baseUrl,
  String? brainId,
  String? loginId,
});

/// Decide which login a tap belongs to.
///
/// - A notification the phone made itself names its session: switch to it,
///   or open home when it is no longer held.
/// - A push that names its (brain, login) pair switches to the held login
///   with that pair. When the logins held for that brain are at more than one
///   address the push is ambiguous, and when none matches it is for a login
///   this device does not hold; both open home.
/// - A push that names no login (an older brain, an event alarm) opens on
///   the login in use, as every tap did before logins were told apart.
///
/// A held login whose pair is not learned yet could be the one. With
/// [canAsk] an unmatched push then answers null: the caller asks those
/// logins' brains (whoami) and resolves again. Without it, the one case
/// still followed is a device holding a single login, the one in use, whose
/// brain could not be asked: that is the device as it was before several
/// logins, and the push can only be for it or for a login signed out here.
TapDecision? resolveTap(
  NotificationTap tap, {
  required List<HeldLogin> held,
  required String? activeId,
  bool canAsk = false,
}) {
  final route = tap.route;
  TapDecision followOrSwitch(String id) =>
      id == activeId ? FollowOnActive(route) : SwitchThenFollow(id, route);

  final local = tap.sessionId;
  if (local != null) {
    final known = held.any((h) => h.id == local);
    return known ? followOrSwitch(local) : const OpenHome();
  }

  if (!tap.namesLogin) return FollowOnActive(route);

  final sameBrain = [
    for (final h in held)
      if (h.brainId == tap.brainId) h,
  ];
  if (sameBrain.map((h) => h.baseUrl).toSet().length > 1) {
    return const OpenHome();
  }
  for (final h in sameBrain) {
    if (h.loginId == tap.loginId) return followOrSwitch(h.id);
  }
  final unlearned = held.where((h) => h.brainId == null).toList();
  if (unlearned.isEmpty) return const OpenHome();
  if (canAsk) return null;
  if (held.length == 1 && held.single.id == activeId && sameBrain.isEmpty) {
    return FollowOnActive(route);
  }
  return const OpenHome();
}
