import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/auth/session_repository.dart';
import '../data/push/notification_tap.dart';
import '../features/auth/session_controller.dart';
import '../features/auth/session_identity.dart';
import 'app_router.dart';

part 'notification_router.g.dart';

/// Acts on a tapped notification: picks the login it was for, makes it the
/// one in use, then opens the screen it names on top of Home (so Back goes
/// home, on a cold start too).
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
        await _show(route);
      case SwitchThenFollow(:final sessionId, :final route):
        final switched = await _ref
            .read(sessionControllerProvider.notifier)
            .switchTo(sessionId);
        // Not switched: that login's brain signed it out, and the switch has
        // already opened its sign-in screen. The link waits for no one.
        if (switched) await _show(route);
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
