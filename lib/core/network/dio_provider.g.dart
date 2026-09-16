// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-wide Dio for talking to Mantle. Base URL comes from [ServerConfig] (so
/// it rebuilds when the server changes); the bearer token is injected per
/// request. On an auth failure it ends the session (see
/// [SessionController.sessionInvalidated]), so the router bounces to login
/// and nothing of the account stays on the device.
///
/// Auth failure = HTTP 401, OR a 3xx redirect whose path is `/login`
/// ([isAuthFailure]). The latter happens for a server-revoked-but-unexpired
/// token: it clears Mantle's Edge gate (valid signature) but `requireOwner()`
/// redirects it. We disable redirect-following so we can see that.

@ProviderFor(dio)
final dioProvider = DioProvider._();

/// App-wide Dio for talking to Mantle. Base URL comes from [ServerConfig] (so
/// it rebuilds when the server changes); the bearer token is injected per
/// request. On an auth failure it ends the session (see
/// [SessionController.sessionInvalidated]), so the router bounces to login
/// and nothing of the account stays on the device.
///
/// Auth failure = HTTP 401, OR a 3xx redirect whose path is `/login`
/// ([isAuthFailure]). The latter happens for a server-revoked-but-unexpired
/// token: it clears Mantle's Edge gate (valid signature) but `requireOwner()`
/// redirects it. We disable redirect-following so we can see that.

final class DioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// App-wide Dio for talking to Mantle. Base URL comes from [ServerConfig] (so
  /// it rebuilds when the server changes); the bearer token is injected per
  /// request. On an auth failure it ends the session (see
  /// [SessionController.sessionInvalidated]), so the router bounces to login
  /// and nothing of the account stays on the device.
  ///
  /// Auth failure = HTTP 401, OR a 3xx redirect whose path is `/login`
  /// ([isAuthFailure]). The latter happens for a server-revoked-but-unexpired
  /// token: it clears Mantle's Edge gate (valid signature) but `requireOwner()`
  /// redirects it. We disable redirect-following so we can see that.
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

String _$dioHash() => r'df0245bc359b9117447f6d5985e59c4cc6da3938';
