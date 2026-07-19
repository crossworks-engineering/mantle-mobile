import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/search/search_api.dart';
import '../../data/search/search_models.dart';

part 'search_controller.g.dart';

/// Debounce for search-as-you-type. Queries shorter than [kSearchMinChars]
/// never hit the server.
const kSearchDebounce = Duration(milliseconds: 350);
const kSearchMinChars = 2;

/// What the search screen renders: the current query, the active type
/// filter, the latest results, and whether a request is in flight.
class SearchState {
  const SearchState({
    this.query = '',
    this.type,
    this.results = const [],
    this.searching = false,
    this.searched = false,
    this.error,
  });

  final String query;

  /// Server node-type filter (null = all types).
  final String? type;
  final List<SearchResult> results;
  final bool searching;

  /// True once a search for the current query has completed (drives the
  /// "no results" empty state — never shown before the first response).
  final bool searched;
  final String? error;

  SearchState copyWith({
    String? query,
    String? type,
    bool clearType = false,
    List<SearchResult>? results,
    bool? searching,
    bool? searched,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      type: clearType ? null : (type ?? this.type),
      results: results ?? this.results,
      searching: searching ?? this.searching,
      searched: searched ?? this.searched,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the search flow: debounced as-you-type queries, an immediate path
/// for submit, a type filter that re-runs the current query, and stale-
/// response protection (only the latest request may write results).
@riverpod
class SearchController extends _$SearchController {
  Timer? _debounce;
  int _requestSeq = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  /// As-you-type entry point: debounce, and clear results for short queries.
  void onQueryChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.length < kSearchMinChars) {
      _requestSeq++; // invalidate any in-flight request
      state = state.copyWith(
        query: q,
        results: const [],
        searching: false,
        searched: false,
        clearError: true,
      );
      return;
    }
    state = state.copyWith(query: q, searching: true, clearError: true);
    _debounce = Timer(kSearchDebounce, () => _run(q));
  }

  /// Immediate search (keyboard submit; also what tests drive).
  Future<void> searchNow(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.length < kSearchMinChars) {
      state = state.copyWith(
        query: q,
        results: const [],
        searching: false,
        searched: false,
        clearError: true,
      );
      return Future.value();
    }
    state = state.copyWith(query: q, searching: true, clearError: true);
    return _run(q);
  }

  /// Switch the type filter (null = all) and re-run the current query.
  Future<void> setType(String? type) {
    state = state.copyWith(type: type, clearType: type == null);
    final q = state.query;
    if (q.length < kSearchMinChars) return Future.value();
    state = state.copyWith(searching: true, clearError: true);
    return _run(q);
  }

  Future<void> _run(String q) async {
    final seq = ++_requestSeq;
    try {
      final results = await ref
          .read(searchApiProvider)
          .search(q, type: state.type);
      if (seq != _requestSeq) return; // a newer request superseded this one
      state = state.copyWith(
        results: results,
        searching: false,
        searched: true,
        clearError: true,
      );
    } catch (_) {
      if (seq != _requestSeq) return;
      state = state.copyWith(
        searching: false,
        searched: true,
        error: "Couldn't search right now.",
      );
    }
  }
}
