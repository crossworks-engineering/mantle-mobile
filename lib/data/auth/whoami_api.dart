import 'package:dio/dio.dart';

import 'login_access.dart';

/// Who a bearer belongs to, from `GET /api/auth/whoami`: the brain's own id
/// and the login's id on it. A push names the same pair (see
/// `docs/push-notifications.md`, "Opening the item a push is about").
typedef BrainIdentity = ({String brainId, String loginId});

/// `GET /api/auth/whoami` through [dio], which carries the bearer to ask
/// about: the role, the login's workspaces and Admin areas, and whether it
/// is the brain's anchor login (`AuthWhoami` in the brain's client types).
///
/// Null on a brain older than whoami (404). Network and auth failures throw,
/// as any request does.
Future<LoginAccess?> fetchWhoami(Dio dio) async =>
    (await fetchWhoamiSent(dio)).access;

/// [fetchWhoami], with the options the request was answered for: the app's
/// client records in them whose bearer it carried, so a caller can tell
/// which login the answer is about.
Future<({LoginAccess? access, RequestOptions sent})> fetchWhoamiSent(
  Dio dio,
) async {
  try {
    final res = await dio.get<Map<String, dynamic>>('/api/auth/whoami');
    return (
      access: LoginAccess.fromWhoami(res.data ?? const {}),
      sent: res.requestOptions,
    );
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) {
      return (access: null, sent: e.requestOptions);
    }
    rethrow;
  }
}

/// Read the identity pair through [dio]. Null when the brain cannot say: a
/// brain older than whoami (404), or one that answers without a `brainId`
/// (its database is behind its code). Network and auth failures throw.
Future<BrainIdentity?> fetchBrainIdentity(Dio dio) async {
  final who = await fetchWhoami(dio);
  final brainId = who?.brainId;
  final loginId = who?.loginId;
  if (brainId == null || brainId.isEmpty) return null;
  if (loginId == null || loginId.isEmpty) return null;
  return (brainId: brainId, loginId: loginId);
}
