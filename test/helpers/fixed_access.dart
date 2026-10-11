import 'package:jackdaw/data/auth/login_access.dart';
import 'package:jackdaw/features/auth/login_access_controller.dart';

/// A [LoginAccessController] that answers [value] and asks nobody: for
/// tests of the screens and controllers that follow the login's access.
class FixedAccess extends LoginAccessController {
  FixedAccess(this.value);

  final LoginAccess value;

  @override
  Future<LoginAccess> build() async => value;
}

/// An Admin user on a brain with workspaces: every area.
const adminAccess = LoginAccess(
  role: LoginRole.admin,
  loginId: 'login-admin',
  workspaces: [
    ShellWorkspace(id: 'ws-admin', name: 'Admin', isAdmin: true),
    ShellWorkspace(id: 'ws-team', name: 'Team', moderator: true),
  ],
  areas: {'settings', 'users', 'assistants', 'connectors', 'keys'},
  isOwner: true,
);

/// A member in the Team workspace and its own private one.
const memberAccess = LoginAccess(
  role: LoginRole.member,
  loginId: 'login-member',
  workspaces: [
    ShellWorkspace(id: 'ws-team', name: 'Team'),
    ShellWorkspace(id: 'ws-own', name: 'Mia (only you)', private: true),
  ],
);
