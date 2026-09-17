import '../server/server_config.dart';

/// What the web app's "Sign in on your phone" QR encodes: a URL on the brain,
/// `https://<brain>/pair#v=1&code=<code>`. The server address is the URL's
/// origin; the pairing code rides in the fragment so it never reaches a
/// server log, and a browser that scans the same code lands on the brain's
/// `/pair` page (which explains, and never shows the code).
///
/// The code is short-lived, single-use and bound to the web user who asked
/// for it; it is not a password and not the bearer.
class PairingPayload {
  const PairingPayload({required this.server, required this.code});

  /// The brain's base URL, normalized like a typed address.
  final String server;

  /// The one-time pairing code, opaque to the phone.
  final String code;

  /// Parse a scanned string. Null for anything that is not a version-1
  /// Jackdaw pairing URL, or whose server address the app would refuse to
  /// use (see [serverUrlProblem]).
  static PairingPayload? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    if (uri.userInfo.isNotEmpty) return null;
    if (uri.path != '/pair' && uri.path != '/pair/') return null;
    // The code rides ONLY in the fragment (never a query, which servers log).
    if (uri.hasQuery) return null;
    final Map<String, String> params;
    try {
      params = Uri.splitQueryString(uri.fragment);
    } on ArgumentError {
      return null;
    }
    if (params['v'] != '1') return null;
    final code = params['code']?.trim() ?? '';
    // 128 bits base64url is 22 chars; anything shorter is not ours.
    if (code.length < 16 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code)) {
      return null;
    }
    final server = normalizeBaseUrl(
      Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null)
          .toString(),
    );
    if (serverUrlProblem(server) != null) return null;
    return PairingPayload(server: server, code: code);
  }
}
