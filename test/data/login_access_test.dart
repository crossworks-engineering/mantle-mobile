// LoginAccess: whoami parsed, what the phone offers each login, the
// workspace to start in, and the cached form.

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/auth/login_access.dart';
import 'package:jackdaw/routing/app_router.dart' show routeAllowed;

Map<String, dynamic> _whoami({
  String role = 'member',
  List<String> areas = const [],
  bool withAreas = true,
}) =>
    {
      'role': role,
      'loginId': 'login-1',
      'email': 'mia@example.invalid',
      'displayName': 'Mia Member',
      'shell': '/api/shell',
      'pushBase': '/api/member/push',
      'brainId': 'brain-1',
      'workspaces': [
        {'id': 'ws-admin', 'name': 'Admin', 'isAdmin': true, 'moderator': true},
        {'id': 'ws-team', 'name': 'Team', 'isAdmin': false, 'moderator': false},
        {
          'id': 'ws-own',
          'name': 'Mia (only you)',
          'isAdmin': false,
          'moderator': true,
          'private': true,
        },
        {'name': 'no id, dropped'},
      ],
      if (withAreas) 'areas': areas,
      'isOwner': false,
    };

void main() {
  test('a role: none is the legacy Admin user, one unknown is a member',
      () {
    expect(LoginRole.parse(null), LoginRole.admin);
    expect(LoginRole.parse('admin'), LoginRole.admin);
    expect(LoginRole.parse('member'), LoginRole.member);
    expect(LoginRole.parse('client'), LoginRole.client);
    expect(LoginRole.parse('superuser'), LoginRole.member);
    expect(LoginRole.parse(''), LoginRole.member);
    expect(LoginRole.parse(7), LoginRole.member);
    expect(LoginAccess.fromRole('auditor').isAdminUser, isFalse);
    final unknown = LoginAccess.fromWhoami(_whoami(role: 'auditor'));
    expect(unknown.role, LoginRole.member);
    expect(unknown.ownerSelf, isFalse);
  });

  test('whoami is read whole', () {
    final a = LoginAccess.fromWhoami(_whoami());
    expect(a.role, LoginRole.member);
    expect(a.loginId, 'login-1');
    expect(a.email, 'mia@example.invalid');
    expect(a.displayName, 'Mia Member');
    expect(a.brainId, 'brain-1');
    expect(a.workspaces.map((w) => w.id), ['ws-admin', 'ws-team', 'ws-own']);
    expect(a.workspaces.last.private, isTrue);
    expect(a.isOwner, isFalse);
    expect(a.legacy, isFalse);
  });

  test('a member reaches no Admin area and no owner content', () {
    final a = LoginAccess.fromWhoami(_whoami());
    expect(a.isAdminUser, isFalse);
    expect(a.ownerContent, isFalse);
    expect(a.pendingApprovals, isFalse);
    expect(a.brainStats, isFalse);
    expect(a.agentCatalog, isFalse);
    expect(a.ownerSelf, isFalse);
    expect(a.liveTurnStream, isFalse);
    expect(a.chatAttachments, isFalse);
  });

  test('an Admin user holds what its areas say', () {
    final a = LoginAccess.fromWhoami(
      _whoami(role: 'admin', areas: ['settings']),
    );
    expect(a.ownerContent, isTrue);
    expect(a.pendingApprovals, isTrue);
    expect(a.brainStats, isTrue);
    expect(a.agentCatalog, isFalse, reason: 'no assistants area');
    expect(a.liveTurnStream, isTrue);
    expect(a.chatAttachments, isTrue);
  });

  test('a brain from before workspaces: the admin holds every area', () {
    final a = LoginAccess.fromWhoami(_whoami(role: 'admin', withAreas: false));
    expect(a.legacy, isTrue);
    expect(a.pendingApprovals, isTrue);
    expect(a.agentCatalog, isTrue);
    const none = LoginAccess.legacyAdmin();
    expect(none.agentCatalog, isTrue);
    expect(none.workspaces, isEmpty);
  });

  test('a sign-in answer\'s role stands in until whoami answers', () {
    expect(LoginAccess.fromRole('member').ownerContent, isFalse);
    expect(LoginAccess.fromRole('admin').legacy, isTrue);
    expect(LoginAccess.fromRole(null).isAdminUser, isTrue,
        reason: 'mobile-login of an older brain serves admins only');
  });

  test('the workspace to start in', () {
    final member = LoginAccess.fromWhoami(_whoami());
    expect(member.defaultWorkspace?.id, 'ws-team',
        reason: 'the first shared one, not Admin, not the private one');
    final admin = LoginAccess.fromWhoami(
      _whoami(role: 'admin', areas: ['settings']),
    );
    expect(admin.defaultWorkspace?.id, 'ws-admin');
    const onlyPrivate = LoginAccess(
      role: LoginRole.member,
      workspaces: [ShellWorkspace(id: 'p', name: 'P', private: true)],
    );
    expect(onlyPrivate.defaultWorkspace?.id, 'p');
    expect(const LoginAccess.legacyAdmin().defaultWorkspace, isNull);
  });

  test('the cached form reads back the same', () {
    for (final a in [
      LoginAccess.fromWhoami(_whoami()),
      LoginAccess.fromWhoami(_whoami(role: 'admin', areas: ['settings'])),
      const LoginAccess.legacyAdmin(),
    ]) {
      final back = LoginAccess.fromWhoami(a.toJson());
      expect(back.role, a.role);
      expect(back.legacy, a.legacy);
      expect(back.areas, a.areas);
      expect(back.workspaces.map((w) => (w.id, w.private, w.isAdmin)),
          a.workspaces.map((w) => (w.id, w.private, w.isAdmin)));
      expect(back.brainId, a.brainId);
    }
  });

  test('a refused screen is not offered to a member', () {
    final member = LoginAccess.fromWhoami(_whoami());
    for (final loc in [
      '/tasks',
      '/tasks/t1',
      '/journal',
      '/events/e1',
      '/pending',
      '/settings/notifications',
    ]) {
      expect(routeAllowed(loc, member), isFalse, reason: loc);
    }
    for (final loc in [
      '/',
      '/chat',
      '/chat/team',
      '/pages',
      '/notes/n1',
      '/files',
      '/search',
      '/settings',
      '/settings/logins',
      '/tasksboard',
    ]) {
      expect(routeAllowed(loc, member), isTrue, reason: loc);
    }
    const admin = LoginAccess.legacyAdmin();
    expect(routeAllowed('/pending', admin), isTrue);
    expect(routeAllowed('/journal', admin), isTrue);
  });
}
