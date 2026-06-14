// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_config.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Mantle base URL the app talks to (user-entered, since Mantle is
/// self-hosted). Persisted in the app_settings key/value table — it's config,
/// not a secret. Exposed reactively so the Dio client rebuilds when it changes.

@ProviderFor(ServerConfig)
final serverConfigProvider = ServerConfigProvider._();

/// The Mantle base URL the app talks to (user-entered, since Mantle is
/// self-hosted). Persisted in the app_settings key/value table — it's config,
/// not a secret. Exposed reactively so the Dio client rebuilds when it changes.
final class ServerConfigProvider
    extends $AsyncNotifierProvider<ServerConfig, String?> {
  /// The Mantle base URL the app talks to (user-entered, since Mantle is
  /// self-hosted). Persisted in the app_settings key/value table — it's config,
  /// not a secret. Exposed reactively so the Dio client rebuilds when it changes.
  ServerConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverConfigHash();

  @$internal
  @override
  ServerConfig create() => ServerConfig();
}

String _$serverConfigHash() => r'b613e2c497b48691e9f5c84da4690ee6992ed8eb';

/// The Mantle base URL the app talks to (user-entered, since Mantle is
/// self-hosted). Persisted in the app_settings key/value table — it's config,
/// not a secret. Exposed reactively so the Dio client rebuilds when it changes.

abstract class _$ServerConfig extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
