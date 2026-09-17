// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads the landing dashboard: the summary metrics (required) plus live system
/// health (best-effort — an older Mantle or a degraded host shouldn't blank the
/// whole screen, so health failures fall back to `null`).

@ProviderFor(DashboardController)
final dashboardControllerProvider = DashboardControllerProvider._();

/// Loads the landing dashboard: the summary metrics (required) plus live system
/// health (best-effort — an older Mantle or a degraded host shouldn't blank the
/// whole screen, so health failures fall back to `null`).
final class DashboardControllerProvider
    extends $AsyncNotifierProvider<DashboardController, DashboardData> {
  /// Loads the landing dashboard: the summary metrics (required) plus live system
  /// health (best-effort — an older Mantle or a degraded host shouldn't blank the
  /// whole screen, so health failures fall back to `null`).
  DashboardControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardControllerHash();

  @$internal
  @override
  DashboardController create() => DashboardController();
}

String _$dashboardControllerHash() =>
    r'd42d0c68517486ea6e7bb6760a2dbdad811ced8c';

/// Loads the landing dashboard: the summary metrics (required) plus live system
/// health (best-effort — an older Mantle or a degraded host shouldn't blank the
/// whole screen, so health failures fall back to `null`).

abstract class _$DashboardController extends $AsyncNotifier<DashboardData> {
  FutureOr<DashboardData> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DashboardData>, DashboardData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DashboardData>, DashboardData>,
              AsyncValue<DashboardData>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
