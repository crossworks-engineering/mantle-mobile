import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/mobile_build.dart';
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

/// What a person typed → the address to probe: `https://` is assumed when no
/// scheme is given (people type `mantle.example.com`), then normalized.
String canonicalServerUrl(String input) {
  var u = input.trim();
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://').hasMatch(u)) {
    u = 'https://$u';
  }
  return normalizeBaseUrl(u);
}

/// Why [url] must not be used as the server address, or null when it may.
///
/// The bearer rides on every request, so a public server has to be reached
/// over TLS. Plain `http://` is allowed only for addresses that stay on the
/// user's own network ([isPrivateHost]): a dev box, a LAN name, a loopback
/// tunnel. Credentials in the address are refused outright.
String? serverUrlProblem(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    return "That doesn't look like a server address.";
  }
  if (uri.userInfo.isNotEmpty) {
    return 'Leave the username and password out of the address.';
  }
  switch (uri.scheme) {
    case 'https':
      return null;
    case 'http':
      return isPrivateHost(uri.host)
          ? null
          : 'Use https:// for a server on the internet. Plain http:// only '
              'works for a server on your own network.';
    default:
      return 'The address must start with https://.';
  }
}

/// True for hosts that cannot be reached from the public internet: loopback,
/// RFC 1918 and link-local ranges, `.local` / `.localhost` names, and bare
/// single-label names (a LAN hostname).
bool isPrivateHost(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local')) {
    return true;
  }
  if (!h.contains('.') && !h.contains(':')) return true; // bare LAN name
  final v4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
      .firstMatch(h);
  if (v4 != null) {
    final a = int.parse(v4.group(1)!);
    final b = int.parse(v4.group(2)!);
    if (a == 127 || a == 10) return true;
    if (a == 192 && b == 168) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 169 && b == 254) return true;
    return false;
  }
  final v6 = h.replaceAll(RegExp(r'^\[|\]$'), '');
  if (v6 == '::1') return true;
  if (v6.startsWith('fc') || v6.startsWith('fd')) return true; // fc00::/7
  if (v6.startsWith('fe8') || v6.startsWith('fe9') ||
      v6.startsWith('fea') || v6.startsWith('feb')) {
    return true; // fe80::/10
  }
  return false;
}

/// What the setup screen found at the address the user typed.
sealed class ServerProbe {
  const ServerProbe();
}

/// A real Mantle brain. [baseUrl] is the normalized address to save.
class ServerProbeBrain extends ServerProbe {
  const ServerProbeBrain(this.baseUrl);
  final String baseUrl;
}

/// The **owner UI**, not the brain. Since Mantle v0.200.0 split the frontend
/// from the server, a deployment can serve the owner app on its own origin
/// (`app.example.com`) that carries no `/api` at all — so the address people
/// see in their browser is the one thing that will never work here. That app
/// advertises the brain it talks to in `/env.js`, so we can name it instead of
/// just failing: [brainBaseUrl] is that origin, already probed successfully.
class ServerProbeClientApp extends ServerProbe {
  const ServerProbeClientApp(this.brainBaseUrl);
  final String brainBaseUrl;
}

/// Nothing Mantle-shaped answered — wrong address, or the server is down.
class ServerProbeUnreachable extends ServerProbe {
  const ServerProbeUnreachable();
}

/// Lightweight reachability check used by the setup screen: a real Mantle
/// answers `GET /api/version` (public) with a JSON `{ version }`. When it
/// doesn't, we check whether we're looking at the split-out owner app and, if
/// so, recover the brain address it points at (see [ServerProbeClientApp]).
Future<ServerProbe> probeMantleServer(String url) async {
  final base = normalizeBaseUrl(url);
  if (await _isMantleBrain(base)) return ServerProbeBrain(base);

  final brain = await _brainAdvertisedByClientApp(base);
  if (brain != null &&
      brain != base &&
      serverUrlProblem(brain) == null &&
      await _isMantleBrain(brain)) {
    return ServerProbeClientApp(brain);
  }
  return const ServerProbeUnreachable();
}

/// Same redirect policy as the app client: a server that answers the probe
/// with a 3xx (say, http → https) is NOT a brain at this address, otherwise
/// the probe would pass on an address every later request fails on. It names
/// the phone build too, as every client that talks to a brain does.
Dio _probeDio(String baseUrl) => Dio(
  BaseOptions(
    baseUrl: baseUrl,
    followRedirects: false,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ),
)..interceptors.add(MobileBuildInterceptor());

/// True when `GET /api/version` answers like a Mantle server.
Future<bool> _isMantleBrain(String baseUrl) async {
  try {
    final res = await _probeDio(
      baseUrl,
    ).get<Map<String, dynamic>>('/api/version');
    return res.statusCode == 200 && (res.data?.containsKey('version') ?? false);
  } catch (_) {
    return false;
  }
}

/// The origin advertised by the owner app's runtime config, or null if this
/// isn't the owner app. `client/web` serves `/env.js` (public, no session) as
/// `window.__MANTLE_ENV__ = {"apiBase":"…","serverOrigin":"…",…};`.
///
/// A single-host install — one hostname path-routing `/api` to the server and
/// everything else to the owner app — never reaches here at all, because
/// `/api/version` answered first. It also advertises an origin equal to (or
/// empty, meaning same as) the address we probed, and the caller rejects both,
/// so there is no way to loop back onto a brain we already found dead.
Future<String?> _brainAdvertisedByClientApp(String baseUrl) async {
  try {
    final res = await _probeDio(baseUrl).get<String>(
      '/env.js',
      options: Options(responseType: ResponseType.plain),
    );
    final body = res.data;
    if (res.statusCode != 200 || body == null) return null;
    final start = body.indexOf('{');
    final end = body.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final env = jsonDecode(body.substring(start, end + 1));
    if (env is! Map) return null;
    final origin = env['serverOrigin'] ?? env['apiBase'];
    if (origin is! String || origin.trim().isEmpty) return null;
    return normalizeBaseUrl(origin);
  } catch (_) {
    return null;
  }
}
