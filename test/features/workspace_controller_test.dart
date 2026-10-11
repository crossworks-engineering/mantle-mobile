// The workspace in use (kept per login), and where Chat goes in it.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/agents/agent.dart';
import 'package:jackdaw/data/auth/login_access.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/data/workspaces/workspaces_api.dart';
import 'package:jackdaw/features/auth/login_access_controller.dart';
import 'package:jackdaw/features/workspaces/workspace_controller.dart';

import '../helpers/fixed_access.dart';

const _team = ShellWorkspace(id: 'ws-team', name: 'Team');
const _sales = ShellWorkspace(id: 'ws-sales', name: 'Sales');
const _admin = ShellWorkspace(id: 'ws-admin', name: 'Admin', isAdmin: true);

const _teamAgent = Agent(id: 'a-team', slug: 'team-assistant', name: 'Tess');
const _ownerAgent = Agent(id: 'a-owner', slug: 'saskia', name: 'Saskia');

const _rows = [
  WorkspaceRow(id: 'ws-admin', name: 'Admin', isAdmin: true,
      assistant: WorkspaceAssistant(id: 'a-owner', name: 'Saskia')),
  WorkspaceRow(id: 'ws-team', name: 'Team',
      assistant: WorkspaceAssistant(id: 'a-team', name: 'Tess')),
  WorkspaceRow(id: 'ws-sales', name: 'Sales'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chatTargetFor', () {
    test('a workspace with an assistant chats with it', () {
      final t = chatTargetFor(
        workspace: _team,
        rows: _rows,
        agents: const [_ownerAgent, _teamAgent],
      );
      expect(t, isA<ChatWithAssistant>());
      expect((t as ChatWithAssistant).agent.slug, 'team-assistant');
    });

    test('the Admin workspace (or none) keeps the owner inbox', () {
      expect(
        chatTargetFor(workspace: _admin, rows: _rows, agents: const []),
        isA<ChatInbox>(),
      );
      expect(
        chatTargetFor(workspace: null, rows: _rows, agents: const []),
        isA<ChatInbox>(),
      );
    });

    test('a workspace without an assistant says so', () {
      expect(
        chatTargetFor(workspace: _sales, rows: _rows, agents: const []),
        isA<NoAssistantHere>(),
      );
    });

    test('an assistant this login may not chat with is no assistant', () {
      expect(
        chatTargetFor(
          workspace: _team,
          rows: _rows,
          agents: const [_ownerAgent],
        ),
        isA<NoAssistantHere>(),
      );
    });

    test('the brain could not list workspaces: the inbox', () {
      expect(
        chatTargetFor(workspace: _team, rows: const [], agents: const []),
        isA<ChatInbox>(),
      );
    });
  });

  group('CurrentWorkspace', () {
    late AppDatabase db;
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.setSetting(AppDatabase.activeSessionKey, 's1');
    });
    tearDown(() => db.close());

    ProviderContainer make(LoginAccess access) {
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          loginAccessControllerProvider.overrideWith(() => FixedAccess(access)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    const member = LoginAccess(
      role: LoginRole.member,
      workspaces: [_team, _sales],
    );

    test('starts in the default and remembers a pick per login', () async {
      final c = make(member);
      expect((await c.read(currentWorkspaceProvider.future))?.id, 'ws-team');

      await c.read(currentWorkspaceProvider.notifier).select('ws-sales');
      expect(c.read(currentWorkspaceProvider).value?.id, 'ws-sales');
      expect(await db.getSetting('workspace.s1'), 'ws-sales');

      // A fresh start reads the pick back.
      final again = make(member);
      expect((await again.read(currentWorkspaceProvider.future))?.id,
          'ws-sales');
    });

    test('a workspace the login is not in is ignored', () async {
      final c = make(member);
      await c.read(currentWorkspaceProvider.future);
      await c.read(currentWorkspaceProvider.notifier).select('ws-admin');
      expect(c.read(currentWorkspaceProvider).value?.id, 'ws-team');
    });

    test('a stored pick the login left falls back to the default', () async {
      await db.setSetting('workspace.s1', 'ws-gone');
      final c = make(member);
      expect((await c.read(currentWorkspaceProvider.future))?.id, 'ws-team');
    });

    test('a brain from before workspaces has none', () async {
      final c = make(const LoginAccess.legacyAdmin());
      expect(await c.read(currentWorkspaceProvider.future), isNull);
    });
  });
}
