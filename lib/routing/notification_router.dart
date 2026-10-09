import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/network/dio_provider.dart';
import '../data/auth/session_repository.dart';
import '../data/auth/whoami_api.dart';
import '../data/push/deep_link.dart';
import '../data/push/notification_tap.dart';
import '../data/push/review_kind.dart';
import '../features/auth/session_controller.dart';
import '../features/auth/session_identity.dart';
import 'app_router.dart';

part 'notification_router.g.dart';

/// Acts on a tapped notification: picks the login it was for, makes it the
/// one in use, then opens the screen it names on top of Home (so Back goes
/// home, on a cold start too). A "waiting for approval" push opens its item
/// for an admin only ([routeFor]).
///
/// It waits for the session to settle first. A cold start runs this while
/// the app is still on its splash, and navigating then is undone by the
/// router's gate a moment later.
class NotificationRouter {
  NotificationRouter(this._ref);

  final Ref _ref;

  Future<void> open(NotificationTap tap) async {
    final AuthStatus status;
    try {
      status = await _ref.read(sessionControllerProvider.future);
    } catch (_) {
      return;
    }
    // Signed out: the gate shows the sign-in screen, and nothing of the
    // payload is followed until someone is signed in as its login.
    if (status != AuthStatus.loggedIn) return;

    final decision = await decide(tap);
    switch (decision) {
      case OpenHome():
        _goHome();
      case FollowOnActive(:final route):
        await _show(await routeFor(tap, route));
      case SwitchThenFollow(:final sessionId, :final route):
        final switched = await _ref
            .read(sessionControllerProvider.notifier)
            .switchTo(sessionId);
        // Not switched: that login's brain signed it out, and the switch has
        // already opened its sign-in screen. The link waits for no one.
        if (switched) await _show(await routeFor(tap, route));
    }
  }

  /// Which login the tap is for, asking the brains of logins whose pair is
  /// not known yet when that is the only way to tell.
  @visibleForTesting
  Future<TapDecision> decide(NotificationTap tap) async {
    final sessions = _ref.read(sessionRepositoryProvider);
    Future<TapDecision?> resolve({required bool canAsk}) async {
      final held = [
        for (final s in await sessions.list())
          (
            id: s.id,
            baseUrl: s.baseUrl,
            brainId: s.brainId,
            loginId: s.loginId,
          ),
      ];
      return resolveTap(
        tap,
        held: held,
        activeId: await sessions.activeId(),
        canAsk: canAsk,
      );
    }

    final first = await resolve(canAsk: true);
    if (first != null) return first;
    await _ref.read(sessionIdentityProvider).learnUnknown();
    return await resolve(canAsk: false) ?? const OpenHome();
  }

  /// The screen to open on the login now in use. A review push names an
  /// item for an admin: only when the brain says this login is one does the
  /// tap open it ([reviewRoute]), asking the kind when an old link does not
  /// say. A member, a client, a brain that cannot say or any failure gets
  /// [route], which carries no review id.
  @visibleForTesting
  Future<String?> routeFor(NotificationTap tap, String? route) async {
    final review = tap.review;
    if (review == null) return route;
    final dio = _ref.read(dioProvider);
    try {
      if (await fetchLoginRole(dio) != 'admin') return route;
    } catch (_) {
      return route;
    }
    final kind =
        review.workspace == null ? await fetchReviewKind(dio, review.id) : null;
    return reviewRoute(review, kind: kind);
  }

  Future<void> _show(String? route) async {
    _goHome();
    if (route == null || route == '/') return;
    // Home first, then the screen on top of it: one frame apart, so the
    // push lands on the stack the `go` built.
    await WidgetsBinding.instance.endOfFrame;
    _ref.read(goRouterProvider).push(route);
  }

  void _goHome() => _ref.read(goRouterProvider).go('/');
}

@Riverpod(keepAlive: true)
NotificationRouter notificationRouter(Ref ref) => NotificationRouter(ref);
