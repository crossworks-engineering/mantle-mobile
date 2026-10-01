import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/logins_screen.dart';
import '../features/auth/scan_sign_in_screen.dart';
import '../features/auth/server_setup_screen.dart';
import '../features/auth/session_controller.dart';
import '../features/chat/chat_screen.dart';
import '../features/conversations/conversations_screen.dart';
import '../features/events/events_screen.dart';
import '../features/files/file_image_screen.dart';
import '../features/files/files_screen.dart';
import '../features/home/home_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/notes/note_view_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/pages/page_view_screen.dart';
import '../features/pages/pages_screen.dart';
import '../features/pending/pending_screen.dart';
import '../features/search/search_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/settings/appearance_screen.dart';
import '../features/settings/push/notifications_screen.dart';
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
    // A route the app does not own (a stale link, a bad payload that slipped
    // past the allowlist) lands here instead of go_router's unthemed page.
    errorBuilder: (_, _) => const _NotFoundScreen(),
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final loc = state.matchedLocation;

      if (session.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }

      // On error, fall back to setup (let the user re-enter the server).
      final status = session.value ?? AuthStatus.needsServer;
      // The QR scan signs in from either signed-out state: it names the
      // brain itself, so it is reachable before a server is set.
      switch (status) {
        case AuthStatus.needsServer:
          return loc == '/setup' || loc == '/scan' ? null : '/setup';
        case AuthStatus.loggedOut:
          return loc == '/login' || loc == '/scan' ? null : '/login';
        case AuthStatus.loggedIn:
          const transient = {'/splash', '/setup', '/login', '/scan'};
          return transient.contains(loc) ? '/' : null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/setup', builder: (_, _) => const ServerSetupScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/scan', builder: (_, _) => const ScanSignInScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/chat', builder: (_, _) => const ConversationsScreen()),
      GoRoute(
        path: '/chat/:slug',
        builder: (context, state) =>
            ChatScreen(agentSlug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/pending', builder: (_, _) => const PendingScreen()),
      GoRoute(
        path: '/pages',
        builder: (context, state) =>
            PagesScreen(folderId: state.uri.queryParameters['folder']),
      ),
      GoRoute(
        path: '/pages/:id',
        builder: (context, state) =>
            PageViewScreen(pageId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: '/files',
        // `folder` opens the tree on a folder; `path` is how the pre-tree
        // screen (a brain older than the folder tree) drills.
        builder: (context, state) => FilesScreen(
          folderId: state.uri.queryParameters['folder'],
          legacyPath: state.uri.queryParameters['path'],
        ),
      ),
      GoRoute(
        path: '/files/image/:id',
        builder: (context, state) => FileImageScreen.file(
          fileId: state.pathParameters['id']!,
          name: state.uri.queryParameters['name'],
        ),
      ),
      // A picture just sent from this device: the chat keeps its local
      // preview after the turn lands, and no node id comes back with it.
      GoRoute(
        path: '/files/local-image',
        builder: (context, state) => FileImageScreen.local(
          localPath: state.uri.queryParameters['path'] ?? '',
          name: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/notes',
        builder: (context, state) =>
            NotesScreen(folderId: state.uri.queryParameters['folder']),
      ),
      GoRoute(
        path: '/notes/:id',
        builder: (context, state) =>
            NoteViewScreen(noteId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/tasks', builder: (_, _) => const TasksScreen()),
      GoRoute(path: '/journal', builder: (_, _) => const JournalScreen()),
      GoRoute(path: '/events', builder: (_, _) => const EventsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/settings/logins',
        builder: (_, _) => const LoginsScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (_, _) => const AppearanceScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
    ],
  );
}

/// Shown for a location no route matches. Themed like every other screen,
/// with the one action that always makes sense.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      color: theme.colorScheme.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("That page isn't here.", style: theme.textTheme.muted),
                const SizedBox(height: 16),
                ShadButton.outline(
                  onPressed: () => context.go('/'),
                  child: const Text('Go home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      child: Text('Jackdaw', style: theme.textTheme.muted),
    );
  }
}
