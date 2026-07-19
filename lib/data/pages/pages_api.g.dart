// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pages_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pagesApi)
final pagesApiProvider = PagesApiProvider._();

final class PagesApiProvider
    extends $FunctionalProvider<PagesApi, PagesApi, PagesApi>
    with $Provider<PagesApi> {
  PagesApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pagesApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pagesApiHash();

  @$internal
  @override
  $ProviderElement<PagesApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PagesApi create(Ref ref) {
    return pagesApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PagesApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PagesApi>(value),
    );
  }
}

String _$pagesApiHash() => r'b098118f284526ea13f0d64a52dc924d9e6d8afb';
