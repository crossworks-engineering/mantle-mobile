// The brain-theme sync and the precedence it feeds: a mocked appearance API
// and a real in-memory settings repository, so "what the phone paints" is
// asserted end to end — sync stores, controller resolves, override wins.

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/core/lifecycle/app_lifecycle.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/server/appearance_api.dart';
import 'package:jackdaw/features/auth/session_controller.dart';
import 'package:jackdaw/features/settings/brain_appearance_sync.dart';
import 'package:jackdaw/features/settings/color_theme_controller.dart';
import 'package:jackdaw/features/settings/settings_repository.dart';
import 'package:jackdaw/theme/mantle_theme.dart';
import 'package:mocktail/mocktail.dart';

class MockAppearanceApi extends Mock implements AppearanceApi {}

class _LoggedIn extends SessionController {
  @override
  Future<AuthStatus> build() async => AuthStatus.loggedIn;
}

void main() {
  late AppDatabase db;
  late SettingsRepository repo;
  late MockAppearanceApi api;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SettingsRepository(db);
    api = MockAppearanceApi();
  });
  tearDown(() => db.close());

  ProviderContainer make() {
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repo),
        appearanceApiProvider.overrideWithValue(api),
        sessionControllerProvider.overrideWith(_LoggedIn.new),
      ],
    );
    addTearDown(container.dispose);
    // The app root keeps the (autoDispose) theme controller alive by watching
    // it; without a listener it would be disposed between reads here.
    container.listen(colorThemeControllerProvider, (_, _) {});
    return container;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// The app root `ref.watch`es the sync so it rebuilds when the session or
  /// lifecycle changes; a bare `read` in a test would build it once and let
  /// it go stale. Listen, as the root does, after the session has resolved.
  Future<void> startSync(ProviderContainer container) async {
    await container.read(sessionControllerProvider.future);
    container.listen(brainAppearanceSyncProvider, (_, _) {});
    await settle();
    await settle();
  }

  test('a signed-in, foregrounded app syncs the brain theme once and paints it',
      () async {
    when(() => api.get()).thenAnswer(
      (_) async => const BrainAppearance(colorTheme: 'clean-slate'),
    );
    final container = make();
    expect(await container.read(colorThemeControllerProvider.future), 'jackdaw');

    await startSync(container);

    verify(() => api.get()).called(1);
    expect(await repo.brainColorTheme(), 'clean-slate');
    expect(container.read(colorThemeControllerProvider).value, 'clean-slate');
    expect(await container.read(brainColorThemeProvider.future), 'clean-slate');
  });

  test('a theme picked on the phone wins over the brain', () async {
    await repo.setColorTheme('mono');
    when(() => api.get()).thenAnswer(
      (_) async => const BrainAppearance(colorTheme: 'pinnacle'),
    );
    final container = make();
    await container.read(colorThemeControllerProvider.future);
    await startSync(container);

    expect(await repo.brainColorTheme(), 'pinnacle');
    expect(container.read(colorThemeControllerProvider).value, 'mono');
    expect(await container.read(colorThemeFollowsBrainProvider.future), isFalse);

    await container.read(colorThemeControllerProvider.notifier).followBrain();
    expect(container.read(colorThemeControllerProvider).value, 'pinnacle');
    expect(await container.read(colorThemeFollowsBrainProvider.future), isTrue);
  });

  test('a brain theme the phone has no port for paints the default', () async {
    when(() => api.get()).thenAnswer(
      (_) async => const BrainAppearance(colorTheme: 'a-theme-from-the-future'),
    );
    final container = make();
    await container.read(colorThemeControllerProvider.future);
    final changed =
        await container.read(brainAppearanceSyncProvider.notifier).syncOnce();

    expect(changed, isFalse);
    expect(await repo.brainColorTheme(), isNull);
    expect(container.read(colorThemeControllerProvider).value, MantleTheme.defaultId);
  });

  test('a failed fetch keeps what was last stored', () async {
    await repo.setBrainColorTheme('claude');
    when(() => api.get()).thenThrow(Exception('offline'));
    final container = make();
    await container.read(colorThemeControllerProvider.future);
    final changed =
        await container.read(brainAppearanceSyncProvider.notifier).syncOnce();

    expect(changed, isFalse);
    expect(await repo.brainColorTheme(), 'claude');
    expect(container.read(colorThemeControllerProvider).value, 'claude');
  });

  test('nothing is fetched while backgrounded', () async {
    when(() => api.get()).thenAnswer(
      (_) async => const BrainAppearance(colorTheme: 'claude'),
    );
    final container = make();
    container.read(appLifecycleProvider.notifier).set(AppLifecycleState.paused);
    await startSync(container);

    verifyNever(() => api.get());
  });
}
