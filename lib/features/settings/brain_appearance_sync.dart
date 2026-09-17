import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../data/server/appearance_api.dart';
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
    final BrainAppearance appearance;
    try {
      appearance = await ref.read(appearanceApiProvider).get();
    } catch (_) {
      return false;
    }
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
}
