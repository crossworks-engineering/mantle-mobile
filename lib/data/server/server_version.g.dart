// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_version.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Mantle version the configured server reports on the public
/// `GET /api/version` (the same call the setup probe makes). Null when the
/// server cannot be reached. Not kept alive: the settings screen asks again
/// each time it opens, so a server that was down shows up once it is back.

@ProviderFor(serverVersion)
final serverVersionProvider = ServerVersionProvider._();

/// The Mantle version the configured server reports on the public
/// `GET /api/version` (the same call the setup probe makes). Null when the
/// server cannot be reached. Not kept alive: the settings screen asks again
/// each time it opens, so a server that was down shows up once it is back.

final class ServerVersionProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The Mantle version the configured server reports on the public
  /// `GET /api/version` (the same call the setup probe makes). Null when the
  /// server cannot be reached. Not kept alive: the settings screen asks again
  /// each time it opens, so a server that was down shows up once it is back.
  ServerVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverVersionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverVersionHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return serverVersion(ref);
  }
}

String _$serverVersionHash() => r'd9a7f0bcce9f1e790ed1fa7aad11296e8fc3b31e';
