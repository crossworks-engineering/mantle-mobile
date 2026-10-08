import 'package:dio/dio.dart';

/// Who a bearer belongs to, from `GET /api/auth/whoami`: the brain's own id
/// and the login's id on it. A push names the same pair (see
/// `docs/push-notifications.md`, "Opening the item a push is about").
typedef BrainIdentity = ({String brainId, String loginId});

/// Read the identity pair through [dio], which carries the bearer to ask
/// about. Null when the brain cannot say: a brain older than whoami (404), or
/// one that answers without a `brainId` (its database is behind its code).
/// Network and auth failures throw, as any request does.
Future<BrainIdentity?> fetchBrainIdentity(Dio dio) async {
  try {
    final res = await dio.get<Map<String, dynamic>>('/api/auth/whoami');
    final data = res.data ?? const {};
    final brainId = data['brainId'];
    final loginId = data['loginId'];
    if (brainId is! String || brainId.isEmpty) return null;
    if (loginId is! String || loginId.isEmpty) return null;
    return (brainId: brainId, loginId: loginId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null;
    rethrow;
  }
}
