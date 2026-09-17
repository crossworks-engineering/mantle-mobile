// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'random_theme_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns whether random-rotation mode is on and its cadence. Persists both;
/// the actual reshuffling is driven by [RandomThemeScheduler].

@ProviderFor(RandomThemeController)
final randomThemeControllerProvider = RandomThemeControllerProvider._();

/// Owns whether random-rotation mode is on and its cadence. Persists both;
/// the actual reshuffling is driven by [RandomThemeScheduler].
final class RandomThemeControllerProvider
    extends $AsyncNotifierProvider<RandomThemeController, RandomThemeState> {
  /// Owns whether random-rotation mode is on and its cadence. Persists both;
  /// the actual reshuffling is driven by [RandomThemeScheduler].
  RandomThemeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'randomThemeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$randomThemeControllerHash();

  @$internal
  @override
  RandomThemeController create() => RandomThemeController();
}

String _$randomThemeControllerHash() =>
    r'25dc3051283d797d94ea6fbc89f89363408ffff1';

/// Owns whether random-rotation mode is on and its cadence. Persists both;
/// the actual reshuffling is driven by [RandomThemeScheduler].

abstract class _$RandomThemeController
    extends $AsyncNotifier<RandomThemeState> {
  FutureOr<RandomThemeState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<RandomThemeState>, RandomThemeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RandomThemeState>, RandomThemeState>,
              AsyncValue<RandomThemeState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Drives the reshuffles when random mode is on: catches up on any overdue
/// rotation when the app (re)gains focus, then ticks on the interval. Only runs
/// while the app is foregrounded — a timer is pointless while suspended, and
/// `lastRandomAtMs` lets it catch up on resume the way the web does on reload.
///
/// keepAlive + watched once from the app root so it stays active for the
/// session. Nothing reads its (void) value — it exists for its side effects.

@ProviderFor(RandomThemeScheduler)
final randomThemeSchedulerProvider = RandomThemeSchedulerProvider._();

/// Drives the reshuffles when random mode is on: catches up on any overdue
/// rotation when the app (re)gains focus, then ticks on the interval. Only runs
/// while the app is foregrounded — a timer is pointless while suspended, and
/// `lastRandomAtMs` lets it catch up on resume the way the web does on reload.
///
/// keepAlive + watched once from the app root so it stays active for the
/// session. Nothing reads its (void) value — it exists for its side effects.
final class RandomThemeSchedulerProvider
    extends $NotifierProvider<RandomThemeScheduler, void> {
  /// Drives the reshuffles when random mode is on: catches up on any overdue
  /// rotation when the app (re)gains focus, then ticks on the interval. Only runs
  /// while the app is foregrounded — a timer is pointless while suspended, and
  /// `lastRandomAtMs` lets it catch up on resume the way the web does on reload.
  ///
  /// keepAlive + watched once from the app root so it stays active for the
  /// session. Nothing reads its (void) value — it exists for its side effects.
  RandomThemeSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'randomThemeSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$randomThemeSchedulerHash();

  @$internal
  @override
  RandomThemeScheduler create() => RandomThemeScheduler();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$randomThemeSchedulerHash() =>
    r'802fcc75ec877f03394615e450f7affd274fbcd2';

/// Drives the reshuffles when random mode is on: catches up on any overdue
/// rotation when the app (re)gains focus, then ticks on the interval. Only runs
/// while the app is foregrounded — a timer is pointless while suspended, and
/// `lastRandomAtMs` lets it catch up on resume the way the web does on reload.
///
/// keepAlive + watched once from the app root so it stays active for the
/// session. Nothing reads its (void) value — it exists for its side effects.

abstract class _$RandomThemeScheduler extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
