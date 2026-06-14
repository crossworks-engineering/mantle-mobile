// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-wide Dio for talking to Mantle. Base URL comes from [ServerConfig] (so
/// it rebuilds when the server changes); the bearer token is injected per
/// request. On an auth failure it clears the token and invalidates the session,
/// so the router bounces to login.
///
/// Auth failure = HTTP 401, OR a 3xx redirect to /login. The latter happens for
/// a server-revoked-but-unexpired token: it clears Mantle's Edge gate (valid
/// signature) but `requireOwner()` redirects it (see the Phase 1 notes). We
/// disable redirect-following so we can see that and treat it as a logout.

@ProviderFor(dio)
final dioProvider = DioProvider._();

/// App-wide Dio for talking to Mantle. Base URL comes from [ServerConfig] (so
/// it rebuilds when the server changes); the bearer token is injected per
/// request. On an auth failure it clears the token and invalidates the session,
/// so the router bounces to login.
///
/// Auth failure = HTTP 401, OR a 3xx redirect to /login. The latter happens for
/// a server-revoked-but-unexpired token: it clears Mantle's Edge gate (valid
/// signature) but `requireOwner()` redirects it (see the Phase 1 notes). We
/// disable redirect-following so we can see that and treat it as a logout.

final class DioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// App-wide Dio for talking to Mantle. Base URL comes from [ServerConfig] (so
  /// it rebuilds when the server changes); the bearer token is injected per
  /// request. On an auth failure it clears the token and invalidates the session,
  /// so the router bounces to login.
  ///
  /// Auth failure = HTTP 401, OR a 3xx redirect to /login. The latter happens for
  /// a server-revoked-but-unexpired token: it clears Mantle's Edge gate (valid
  /// signature) but `requireOwner()` redirects it (see the Phase 1 notes). We
  /// disable redirect-following so we can see that and treat it as a logout.
  DioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return dio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$dioHash() => r'f7cb4d0edf9cf73c8fc37226c26c49083d8d1832';
