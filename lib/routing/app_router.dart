import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/server_setup_screen.dart';
import '../features/auth/session_controller.dart';
import '../features/chat/chat_screen.dart';
import '../features/conversations/conversations_screen.dart';
import '../features/home/home_screen.dart';
import '../features/pending/pending_screen.dart';
import '../features/settings/settings_screen.dart';

part 'app_router.g.dart';

/// The app router. A single [SessionController]-driven `redirect` is the whole
/// auth gate: while the session loads we show a splash; then we route to setup,
/// login, or home. `refreshListenable` re-runs the redirect whenever the
/// session changes (set server / sign in / sign out / token cleared on 401).
@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final loc = state.matchedLocation;

      if (session.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }

      // On error, fall back to setup (let the user re-enter the server).
      final status = session.value ?? AuthStatus.needsServer;
      switch (status) {
        case AuthStatus.needsServer:
          return loc == '/setup' ? null : '/setup';
        case AuthStatus.loggedOut:
          return loc == '/login' ? null : '/login';
        case AuthStatus.loggedIn:
          const transient = {'/splash', '/setup', '/login'};
          return transient.contains(loc) ? '/' : null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/setup', builder: (_, _) => const ServerSetupScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/chat', builder: (_, _) => const ConversationsScreen()),
      GoRoute(
        path: '/chat/:slug',
        builder: (context, state) =>
            ChatScreen(agentSlug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/pending', builder: (_, _) => const PendingScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
}

/// Minimal Material-free splash shown while the session resolves.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      color: theme.colorScheme.background,
      alignment: Alignment.center,
      child: Text('Mantle Companion', style: theme.textTheme.muted),
    );
  }
}
