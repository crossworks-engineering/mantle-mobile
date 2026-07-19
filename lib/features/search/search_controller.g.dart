// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the search flow: debounced as-you-type queries, an immediate path
/// for submit, a type filter that re-runs the current query, and stale-
/// response protection (only the latest request may write results).

@ProviderFor(SearchController)
final searchControllerProvider = SearchControllerProvider._();

/// Owns the search flow: debounced as-you-type queries, an immediate path
/// for submit, a type filter that re-runs the current query, and stale-
/// response protection (only the latest request may write results).
final class SearchControllerProvider
    extends $NotifierProvider<SearchController, SearchState> {
  /// Owns the search flow: debounced as-you-type queries, an immediate path
  /// for submit, a type filter that re-runs the current query, and stale-
  /// response protection (only the latest request may write results).
  SearchControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchControllerHash();

  @$internal
  @override
  SearchController create() => SearchController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchState>(value),
    );
  }
}

String _$searchControllerHash() => r'613e3ec8f068e4a5be425741ce809b2d5251409a';

/// Owns the search flow: debounced as-you-type queries, an immediate path
/// for submit, a type filter that re-runs the current query, and stale-
/// response protection (only the latest request may write results).

abstract class _$SearchController extends $Notifier<SearchState> {
  SearchState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SearchState, SearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SearchState, SearchState>,
              SearchState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
