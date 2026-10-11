/// What kind of login the bearer is (`AuthWhoami.role`).
enum LoginRole {
  /// A user of the Admin workspace: the owner surface, as before.
  admin,

  /// Any other user: its own workspaces, its own threads, no Admin areas.
  member,

  /// A client login. The brain serves none to the phone yet.
  client;

  static LoginRole parse(Object? raw) => switch (raw) {
        'member' => LoginRole.member,
        'client' => LoginRole.client,
        _ => LoginRole.admin,
      };
}

/// The Admin areas a login may hold (`WorkspaceArea` on the brain).
abstract final class AdminArea {
  static const settings = 'settings';
  static const users = 'users';
  static const assistants = 'assistants';
  static const connectors = 'connectors';
  static const keys = 'keys';
}

/// One of the login's live workspaces (`ShellWorkspace` on the brain), what
/// the drawer's switcher lists.
class ShellWorkspace {
  const ShellWorkspace({
    required this.id,
    required this.name,
    this.isAdmin = false,
    this.moderator = false,
    this.private = false,
  });

  final String id;
  final String name;

  /// The Admin workspace: its users manage the brain.
  final bool isAdmin;

  /// The login is a Moderator here.
  final bool moderator;

  /// The login's own private workspace (`<name> (only you)`). Matched on this
  /// flag, never on the name.
  final bool private;

  static ShellWorkspace? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || id.isEmpty) return null;
    return ShellWorkspace(
      id: id,
      name: name is String && name.isNotEmpty ? name : id,
      isAdmin: raw['isAdmin'] == true,
      moderator: raw['moderator'] == true,
      private: raw['private'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isAdmin': isAdmin,
        'moderator': moderator,
        if (private) 'private': true,
      };
}

/// Who the login in use is and what it may reach on the phone, from
/// `GET /api/auth/whoami` (cached per login, so the screens know at once on
/// the next start, offline too).
///
/// The brain decides every right; this only keeps the phone from offering a
/// screen whose routes would refuse the login (403 `member-login`), so a
/// member never meets a screen that cannot load.
class LoginAccess {
  const LoginAccess({
    required this.role,
    this.loginId,
    this.email,
    this.displayName,
    this.brainId,
    this.workspaces = const [],
    this.areas = const {},
    this.isOwner = false,
    this.legacy = false,
  });

  /// A brain from before workspaces (its whoami has no `areas`, or there is
  /// no whoami at all): every login there is an Admin user with the whole
  /// owner surface, as the app always assumed.
  const LoginAccess.legacyAdmin()
      : role = LoginRole.admin,
        loginId = null,
        email = null,
        displayName = null,
        brainId = null,
        workspaces = const [],
        areas = const {},
        isOwner = false,
        legacy = true;

  /// What a sign-in answer said before whoami answers: only the role.
  factory LoginAccess.fromRole(String? role) {
    final parsed = LoginRole.parse(role);
    return parsed == LoginRole.admin
        ? const LoginAccess.legacyAdmin()
        : LoginAccess(role: parsed);
  }

  final LoginRole role;
  final String? loginId;
  final String? email;
  final String? displayName;
  final String? brainId;
  final List<ShellWorkspace> workspaces;
  final Set<String> areas;

  /// The brain's anchor login.
  final bool isOwner;

  /// See [LoginAccess.legacyAdmin].
  final bool legacy;

  /// A user of the Admin workspace.
  bool get isAdminUser => role == LoginRole.admin;

  /// Whether the login holds an Admin [area]. On a brain from before
  /// workspaces an admin holds them all.
  bool hasArea(String area) =>
      legacy ? isAdminUser : isAdminUser && areas.contains(area);

  // ─── What the phone offers ──────────────────────────────────────────────

  /// The owner's own items the brain keeps for the Admin workspace: the
  /// journal, tasks, events (and their alarms), contacts. A member's routes
  /// refuse them.
  bool get ownerContent => isAdminUser;

  /// Pending approvals: the settings area.
  bool get pendingApprovals => hasArea(AdminArea.settings);

  /// The brain overview on the home screen (`/api/dashboard`): settings.
  bool get brainStats => hasArea(AdminArea.settings);

  /// The full agent rows and their avatars (`/api/agents`): the assistants
  /// area. Without it the chat lists the agents the thread route names.
  bool get agentCatalog => hasArea(AdminArea.assistants);

  /// The login's own profile, push devices and reminder channel
  /// (`/api/profile`, `/api/push`): an Admin user's own things.
  bool get ownerSelf => isAdminUser;

  /// A reply typing out live (the turn stream). A member's turn is queued
  /// and its reply lands in the thread: the phone polls for it.
  bool get liveTurnStream => isAdminUser;

  /// Pictures and files sent with a message. A member's chat takes text.
  bool get chatAttachments => isAdminUser;

  /// The Admin workspace among [workspaces], if the login is in it.
  ShellWorkspace? get adminWorkspace {
    for (final w in workspaces) {
      if (w.isAdmin) return w;
    }
    return null;
  }

  ShellWorkspace? workspaceById(String? id) {
    if (id == null) return null;
    for (final w in workspaces) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// The workspace to start in: an Admin user's Admin workspace, anyone
  /// else's first shared workspace (the Team workspace is listed first), then
  /// whatever there is.
  ShellWorkspace? get defaultWorkspace {
    if (workspaces.isEmpty) return null;
    if (isAdminUser) {
      final admin = adminWorkspace;
      if (admin != null) return admin;
    }
    for (final w in workspaces) {
      if (!w.isAdmin && !w.private) return w;
    }
    for (final w in workspaces) {
      if (!w.isAdmin) return w;
    }
    return workspaces.first;
  }

  /// Parse `GET /api/auth/whoami`. A whoami without `areas` is a brain from
  /// before workspaces: [legacy].
  factory LoginAccess.fromWhoami(Map<String, dynamic> data) {
    String? text(String key) {
      final v = data[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    final rawAreas = data['areas'];
    final rawWorkspaces = data['workspaces'];
    final role = LoginRole.parse(data['role']);
    return LoginAccess(
      role: role,
      loginId: text('loginId'),
      email: text('email'),
      displayName: text('displayName'),
      brainId: text('brainId'),
      workspaces: [
        if (rawWorkspaces is List)
          for (final w in rawWorkspaces) ?ShellWorkspace.tryParse(w),
      ],
      areas: {
        if (rawAreas is List)
          for (final a in rawAreas)
            if (a is String) a,
      },
      isOwner: data['isOwner'] == true,
      legacy: rawAreas is! List && role == LoginRole.admin,
    );
  }

  /// The cached form: the whoami shape, plus [legacy].
  Map<String, dynamic> toJson() => {
        'role': role.name,
        'loginId': ?loginId,
        'email': ?email,
        'displayName': ?displayName,
        'brainId': ?brainId,
        'workspaces': [for (final w in workspaces) w.toJson()],
        if (!legacy) 'areas': areas.toList(),
        'isOwner': isOwner,
      };
}
