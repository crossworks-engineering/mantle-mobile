import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'pending_models.dart';

part 'pending_api.g.dart';

/// The agent-approval queue: list pending tool calls and decide them
/// (`GET /api/pending`, `PATCH /api/pending/{id}`).
class PendingApi {
  PendingApi(this._dio);

  final Dio _dio;

  /// `GET /api/pending?status=pending` — calls awaiting a decision, newest
  /// first. Defaults to the `pending` filter so the list matches the home
  /// screen's pending badge (which counts pending rows).
  Future<List<PendingCall>> list({String status = 'pending'}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/pending',
      queryParameters: {'status': status},
    );
    final rows = (res.data?['pending'] as List?) ?? const [];
    return rows
        .map((e) => PendingCall.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `PATCH /api/pending/{id}` — approve (dispatches the tool) or reject.
  /// Returns the updated call. Throws on 404 (already decided / not found).
  Future<PendingCall> decide(String id, {required bool approve}) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/pending/$id',
      data: {'decision': approve ? 'approve' : 'reject'},
    );
    return PendingCall.fromJson(
      (res.data?['pending'] as Map).cast<String, dynamic>(),
    );
  }
}

@Riverpod(keepAlive: true)
PendingApi pendingApi(Ref ref) => PendingApi(ref.watch(dioProvider));
