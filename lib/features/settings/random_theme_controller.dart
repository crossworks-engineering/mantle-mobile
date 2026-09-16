import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart' show AppLifecycleState, immutable;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../theme/mantle_theme.dart';
import 'color_theme_controller.dart';
import 'settings_repository.dart';

part 'random_theme_controller.g.dart';

/// Selectable reshuffle cadences (the web app's dice menu).
const List<Duration> kRandomIntervals = [
  Duration(hours: 1),
  Duration(hours: 6),
  Duration(hours: 12),
  Duration(days: 1),
  Duration(days: 7),
];

/// Pick a random color-theme id, avoiding [exclude] (the current one) so a
/// reshuffle always visibly changes something.
String pickRandomColorThemeId({String? exclude}) {
  final pool = kMantleThemes.where((t) => t.id != exclude).toList();
  final list = pool.isNotEmpty ? pool : kMantleThemes;
  return list[Random().nextInt(list.length)].id;
}

@immutable
class RandomThemeState {
  const RandomThemeState({required this.enabled, required this.interval});

  final bool enabled;
  final Duration interval;
}

/// Owns whether random-rotation mode is on and its cadence. Persists both;
/// the actual reshuffling is driven by [RandomThemeScheduler].
@riverpod
class RandomThemeController extends _$RandomThemeController {
  @override
  Future<RandomThemeState> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return RandomThemeState(
      enabled: await repo.randomThemeEnabled(),
      interval: await repo.randomInterval(),
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setRandomThemeEnabled(enabled);
    // Force an immediate first shuffle when turning it on, so the toggle has
    // visible effect; the scheduler reshuffles on its next (re)build.
    if (enabled) await repo.setLastRandomAtMs(0);
    if (!ref.mounted) return;
    state = AsyncData(RandomThemeState(
      enabled: enabled,
      interval: state.value?.interval ?? SettingsRepository.defaultRandomInterval,
    ));
  }

  Future<void> setInterval(Duration interval) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setRandomInterval(interval);
    await repo.setLastRandomAtMs(DateTime.now().millisecondsSinceEpoch);
    if (!ref.mounted) return;
    state = AsyncData(RandomThemeState(
      enabled: state.value?.enabled ?? false,
      interval: interval,
    ));
  }
}

/// Drives the reshuffles when random mode is on: catches up on any overdue
/// rotation when the app (re)gains focus, then ticks on the interval. Only runs
/// while the app is foregrounded — a timer is pointless while suspended, and
/// `lastRandomAtMs` lets it catch up on resume the way the web does on reload.
///
/// keepAlive + watched once from the app root so it stays active for the
/// session. Nothing reads its (void) value — it exists for its side effects.
@Riverpod(keepAlive: true)
class RandomThemeScheduler extends _$RandomThemeScheduler {
  Timer? _timer;

  @override
  void build() {
    ref.onDispose(() => _timer?.cancel());
    _timer?.cancel();

    final config = ref.watch(randomThemeControllerProvider).value;
    final lifecycle = ref.watch(appLifecycleProvider);
    if (config == null || !config.enabled) return;
    if (lifecycle != AppLifecycleState.resumed) return;

    unawaited(_catchUpThenSchedule(config.interval));
  }

  Future<void> _catchUpThenSchedule(Duration interval) async {
    final repo = ref.read(settingsRepositoryProvider);
    final last = await repo.lastRandomAtMs();
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    if (last == 0 || elapsed >= interval.inMilliseconds) {
      await _reshuffle();
    }
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _reshuffle());
  }

  Future<void> _reshuffle() async {
    final current = ref.read(colorThemeControllerProvider).value;
    final next = pickRandomColorThemeId(exclude: current);
    await ref.read(colorThemeControllerProvider.notifier).select(next);
    await ref
        .read(settingsRepositoryProvider)
        .setLastRandomAtMs(DateTime.now().millisecondsSinceEpoch);
  }
}
