// The home screen follows the login: a member is offered what its routes
// serve (chat, pages, notes, search, files), never the Admin workspace's own
// items, approvals or the brain overview; the workspace in use shows as a
// pill that opens the drawer, whose switcher changes it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/auth/login_access.dart';
import 'package:jackdaw/data/conversations/conversation_models.dart';
import 'package:jackdaw/data/dashboard/dashboard_models.dart';
import 'package:jackdaw/features/auth/login_access_controller.dart';
import 'package:jackdaw/features/auth/session_controller.dart';
import 'package:jackdaw/features/conversations/conversations_controller.dart';
import 'package:jackdaw/features/dashboard/dashboard_controller.dart';
import 'package:jackdaw/features/dashboard/up_next.dart';
import 'package:jackdaw/features/dashboard/up_next_controller.dart';
import 'package:jackdaw/features/home/home_screen.dart';
import 'package:jackdaw/features/workspaces/workspace_controller.dart';
import 'package:jackdaw/features/workspaces/workspace_switcher.dart';

import '../helpers/fixed_access.dart';
import '../helpers/pump_screen.dart';

class _NoConversations extends ConversationsController {
  @override
  Future<List<AgentConversation>> build() async => const [];
}

class _NoStats extends DashboardController {
  @override
  Future<DashboardData> build() async => throw Exception('not under test');
}

class _NothingUpNext extends UpNextController {
  @override
  Future<UpNext> build() async => const UpNext(events: [], tasks: []);
}

/// The workspace in use without the device store: picks are kept in memory.
class _MemoryWorkspace extends CurrentWorkspace {
  _MemoryWorkspace(this.access);
  final LoginAccess access;

  @override
  Future<ShellWorkspace?> build() async => access.defaultWorkspace;

  @override
  Future<void> select(String id) async {
    final ws = access.workspaceById(id);
    if (ws != null) state = AsyncData(ws);
  }
}

void main() {
  ProviderContainer make(LoginAccess access) => ProviderContainer(
        // A refused provider is not retried on a timer here.
        retry: (_, _) => null,
        overrides: [
          loginAccessControllerProvider.overrideWith(() => FixedAccess(access)),
          currentAccessProvider.overrideWithValue(access),
          currentWorkspaceProvider.overrideWith(() => _MemoryWorkspace(access)),
          conversationsControllerProvider.overrideWith(_NoConversations.new),
          dashboardControllerProvider.overrideWith(_NoStats.new),
          upNextControllerProvider.overrideWith(_NothingUpNext.new),
          heldSessionsProvider.overrideWith((ref) async => const []),
        ],
      );

  testWidgets('a member is offered only what its routes serve',
      (tester) async {
    await pumpScreen(tester, const HomeScreen(),
        container: make(memberAccess));

    for (final label in ['Chat', 'Pages', 'Notes', 'Search', 'Files']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    for (final label in ['Tasks', 'Journal', 'Events', 'Pending']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text("Couldn't load the dashboard."), findsNothing);
    expect(find.text('Team'), findsOneWidget, reason: 'the workspace pill');
  });

  testWidgets('an Admin user keeps the whole owner surface', (tester) async {
    await pumpScreen(tester, const HomeScreen(), container: make(adminAccess));

    for (final label in [
      'Chat',
      'Pages',
      'Notes',
      'Tasks',
      'Journal',
      'Events',
      'Search',
      'Pending',
      'Files',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Admin'), findsOneWidget, reason: 'the workspace pill');
  });

  testWidgets('the drawer\'s switcher changes the workspace in use',
      (tester) async {
    final c = make(memberAccess);
    await pumpScreen(tester, const HomeScreen(), container: c);

    expect(find.bySemanticsLabel('Workspace: Team'), findsOneWidget);
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceSwitcher), findsOneWidget);
    expect(find.text('Only you'), findsOneWidget,
        reason: 'the private workspace in the phone\'s own words');

    await tester.tap(find.text('Only you'));
    await tester.pumpAndSettle();
    expect(c.read(currentWorkspaceProvider).value?.id, 'ws-own');
    expect(find.byType(WorkspaceSwitcher), findsNothing,
        reason: 'the sheet closes on a pick');
  });

  testWidgets('a brain from before workspaces shows no pill', (tester) async {
    await pumpScreen(tester, const HomeScreen(),
        container: make(const LoginAccess.legacyAdmin()));
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Pending'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('^Workspace:')), findsNothing);
  });
}
