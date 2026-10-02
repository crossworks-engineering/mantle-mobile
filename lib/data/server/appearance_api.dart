import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';

part 'appearance_api.g.dart';

/// What the brain says about its own look, from the public
/// `GET /api/appearance`: the route is unauthenticated on purpose (the web
/// client reads it before it has a session, to paint the right theme on first
/// load) and carries branding only, never a preference that is anyone's
/// secret. The phone reads the colour theme, and the site name the Logins
/// screen calls the brain by.
class BrainAppearance {
  const BrainAppearance({required this.colorTheme, this.siteName});

  /// The brain's system-wide colour theme id, or null when the owner has not
  /// chosen one (the web then shows its default).
  final String? colorTheme;

  /// What the brain calls itself, or null when it has not been named (or is
  /// older than the route's identity fields).
  final String? siteName;

  factory BrainAppearance.fromJson(Map<String, dynamic> json) =>
      BrainAppearance(
        colorTheme: json['colorTheme'] as String?,
        siteName: json['siteName'] as String?,
      );
}

class AppearanceApi {
  AppearanceApi(this._dio);

  final Dio _dio;

  /// `GET /api/appearance`. Throws on a network or server failure — callers
  /// treat that as "unknown", never as "no theme".
  Future<BrainAppearance> get() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/appearance');
    return BrainAppearance.fromJson(res.data ?? const {});
  }
}

@Riverpod(keepAlive: true)
AppearanceApi appearanceApi(Ref ref) => AppearanceApi(ref.watch(dioProvider));
