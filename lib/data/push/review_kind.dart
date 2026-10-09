import 'package:dio/dio.dart';

/// The kind (`page`, `note`, `table`, `draw`, `file`) of an item waiting for
/// an admin's approval, from `GET /api/team-admin/submissions/:id`. Admin
/// only: ask it with an admin's client, never a member's or a client's (the
/// route answers them 401, and a 401 signs the login out). Null when the
/// item is gone, no longer waits, or the brain cannot say.
Future<String?> fetchReviewKind(Dio dio, String id) async {
  try {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/team-admin/submissions/${Uri.encodeComponent(id)}',
    );
    final type = res.data?['type'];
    return type is String && type.isNotEmpty ? type : null;
  } on DioException {
    return null;
  }
}
