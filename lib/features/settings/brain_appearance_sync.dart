import 'dart:async' show unawaited;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../data/auth/session_repository.dart';
import '../../data/db/app_database.dart' show Session;
import '../../data/server/appearance_api.dart';
import '../../data/server/server_config.dart';
import '../../theme/mantle_theme.dart';
import '../auth/session_controller.dart';
import 'color_theme_controller.dart';
import 'settings_repository.dart';

part 'brain_appearance_sync.g.dart';

/// Keeps the phone's idea of the brain's colour theme fresh: on sign-in and
/// on every foreground resume it reads the public `GET /api/appearance` and
/// stores `colorTheme`. A theme the owner sets on the web therefore shows on
/// the phone the next time it comes to the front — unless the phone has a
/// pick of its own, which wins (see [SettingsRepository.colorTheme]).
///
/// The same answer names the brain (`siteName`), which is stored on the login
/// in use so the Logins screen can call each brain by its name, not its host.
///
/// keepAlive + watched once from the app root, like the alarm sync — nothing
/// reads its (void) value. Failures are silent: offline or a pre-appearance
/// server leaves whatever was last stored.
@Riverpod(keepAlive: true)
class BrainAppearanceSync extends _$BrainAppearanceSync {
  @override
  void build() {
    final session = ref.watch(sessionControllerProvider).value;
    final lifecycle = ref.watch(appLifecycleProvider);
    if (session != AuthStatus.loggedIn) return;
    if (lifecycle != AppLifecycleState.resumed) return;
    unawaited(syncOnce());
  }

  /// One fetch-and-store. Public so a test (or a pull-to-refresh) can drive
  /// it directly. Returns true when the stored brain theme changed.
  Future<bool> syncOnce() async {
    final asked = await _loginInUse();
    final BrainAppearance appearance;
    try {
      appearance = await ref.read(appearanceApiProvider).get();
    } catch (_) {
      return false;
    }
    if (!ref.mounted) return false;
    await _recordSiteName(asked, appearance.siteName);
    if (!ref.mounted) return false;
    final repo = ref.read(settingsRepositoryProvider);
    // An id the phone has no port for is stored as "none": painting the
    // default is closer to the web's intent than painting an unrelated
    // theme, and the next sync after a regenerate picks it up.
    final next = MantleTheme.has(appearance.colorTheme)
        ? appearance.colorTheme
        : null;
    final previous = await repo.brainColorTheme();
    if (next == previous) return false;
    await repo.setBrainColorTheme(next);
    if (!ref.mounted) return true;
    ref.invalidate(brainColorThemeProvider);
    await ref.read(colorThemeControllerProvider.notifier).reload();
    return true;
  }

  /// The login in use as the request goes out, when the client is pointed at
  /// its brain. Null otherwise (nobody signed in, or a switch to another
  /// brain whose address the client has not picked up yet): an answer from
  /// that request is not known to be this login's brain.
  Future<Session?> _loginInUse() async {
    try {
      final active = await ref.read(sessionRepositoryProvider).active();
      final server = await ref.read(serverConfigProvider.future);
      return (active != null && active.baseUrl == server) ? active : null;
    } catch (_) {
      return null;
    }
  }

  /// Store the brain's name on the login [asked] for, if that login is still
  /// the one in use. Best-effort, like the theme: a failure leaves the host
  /// showing on the Logins screen.
  Future<void> _recordSiteName(Session? asked, String? siteName) async {
    if (asked == null) return;
    final name = siteName?.trim();
    final next = (name == null || name.isEmpty) ? null : name;
    if (next == asked.siteName) return;
    try {
      final sessions = ref.read(sessionRepositoryProvider);
      if (await sessions.activeId() != asked.id) return;
      await sessions.recordIdentity(asked.id, siteName: Value(next));
      if (ref.mounted) ref.invalidate(heldSessionsProvider);
    } catch (_) {
      /* the list keeps showing the host */
    }
  }
}
