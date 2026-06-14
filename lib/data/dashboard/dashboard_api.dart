import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'dashboard_models.dart';

part 'dashboard_api.g.dart';

/// Reads the landing dashboard's metrics from Mantle.
class DashboardApi {
  DashboardApi(this._dio);

  final Dio _dio;

  /// `GET /api/dashboard/summary` — spend, brain, vectors, pending count.
  Future<DashboardSummary> summary() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/dashboard/summary');
    return DashboardSummary.fromJson(res.data ?? const {});
  }

  /// `GET /api/health` — live system vitals.
  Future<ServerHealth> health() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/health');
    return ServerHealth.fromJson(res.data ?? const {});
  }
}

@Riverpod(keepAlive: true)
DashboardApi dashboardApi(Ref ref) => DashboardApi(ref.watch(dioProvider));
