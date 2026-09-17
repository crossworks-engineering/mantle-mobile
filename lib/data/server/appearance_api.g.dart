// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appearance_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appearanceApi)
final appearanceApiProvider = AppearanceApiProvider._();

final class AppearanceApiProvider
    extends $FunctionalProvider<AppearanceApi, AppearanceApi, AppearanceApi>
    with $Provider<AppearanceApi> {
  AppearanceApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearanceApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearanceApiHash();

  @$internal
  @override
  $ProviderElement<AppearanceApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppearanceApi create(Ref ref) {
    return appearanceApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppearanceApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppearanceApi>(value),
    );
  }
}

String _$appearanceApiHash() => r'0f53c2bdaa5d9f05e17c0a9305f285a503c124e9';
