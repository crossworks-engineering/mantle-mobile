import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/database_provider.dart';

part 'server_config.g.dart';

/// The Mantle base URL the app talks to (user-entered, since Mantle is
/// self-hosted). Persisted in the app_settings key/value table — it's config,
/// not a secret. Exposed reactively so the Dio client rebuilds when it changes.
@Riverpod(keepAlive: true)
class ServerConfig extends _$ServerConfig {
  static const _key = 'server_base_url';

  @override
  Future<String?> build() async {
    final raw = await ref.watch(appDatabaseProvider).getSetting(_key);
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// Persist the base URL (trailing slash trimmed) and reflect it immediately.
  Future<void> setUrl(String url) async {
    final normalized = normalizeBaseUrl(url);
    await ref.read(appDatabaseProvider).setSetting(_key, normalized);
    state = AsyncData(normalized);
  }
}

/// Trim whitespace and any trailing slash so paths join cleanly.
String normalizeBaseUrl(String url) {
  var u = url.trim();
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

/// Lightweight reachability check used by the setup screen: a real Mantle
/// answers `GET /api/version` (public) with a JSON `{ version }`.
Future<bool> probeMantleServer(String url) async {
  try {
    final dio = Dio(
      BaseOptions(
        baseUrl: normalizeBaseUrl(url),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final res = await dio.get<Map<String, dynamic>>('/api/version');
    return res.statusCode == 200 && (res.data?.containsKey('version') ?? false);
  } catch (_) {
    return false;
  }
}
