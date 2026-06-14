import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dashboard/dashboard_api.dart';
import '../../data/dashboard/dashboard_models.dart';

part 'dashboard_controller.g.dart';

/// Loads the landing dashboard: the summary metrics (required) plus live system
/// health (best-effort — an older Mantle or a degraded host shouldn't blank the
/// whole screen, so health failures fall back to `null`).
@riverpod
class DashboardController extends _$DashboardController {
  @override
  Future<DashboardData> build() => _load();

  Future<DashboardData> _load() async {
    final api = ref.read(dashboardApiProvider);
    final summaryFuture = api.summary();
    ServerHealth? health;
    try {
      health = await api.health();
    } catch (_) {
      health = null;
    }
    return DashboardData(summary: await summaryFuture, health: health);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}
