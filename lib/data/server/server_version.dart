import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';

part 'server_version.g.dart';

/// The Mantle version the configured server reports on the public
/// `GET /api/version` (the same call the setup probe makes). Null when the
/// server cannot be reached. Not kept alive: the settings screen asks again
/// each time it opens, so a server that was down shows up once it is back.
@riverpod
Future<String?> serverVersion(Ref ref) async {
  try {
    final res = await ref
        .watch(dioProvider)
        .get<Map<String, dynamic>>('/api/version');
    return res.data?['version'] as String?;
  } catch (_) {
    return null;
  }
}
