import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/notes/notes_api.dart';
import '../../data/notes/notes_models.dart';

part 'notes_controller.g.dart';

/// What the notes screen renders: the loaded rows (possibly several server
/// pages deep), the total for "has more", the tag facets, and the active
/// tag filter.
class NotesState {
  const NotesState({
    required this.notes,
    required this.total,
    required this.tags,
    this.tag,
    this.loadingMore = false,
  });

  final List<NoteRow> notes;
  final int total;
  final List<NoteTag> tags;

  /// Active tag filter (null = all notes).
  final String? tag;
  final bool loadingMore;

  bool get hasMore => notes.length < total;

  NotesState copyWith({
    List<NoteRow>? notes,
    int? total,
    List<NoteTag>? tags,
    String? tag,
    bool clearTag = false,
    bool? loadingMore,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      total: total ?? this.total,
      tags: tags ?? this.tags,
      tag: clearTag ? null : (tag ?? this.tag),
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// Owns the notes list: first page on build, older pages via [loadMore],
/// a tag filter, and optimistic quick-add/delete (a failure reloads so the
/// screen never lies for long).
@riverpod
class NotesController extends _$NotesController {
  @override
  Future<NotesState> build() => _fetch(tag: null);

  Future<NotesState> _fetch({String? tag}) async {
    final page = await ref.read(notesApiProvider).list(tag: tag);
    return NotesState(
      notes: page.notes,
      total: page.total,
      tags: page.tags,
      tag: tag,
    );
  }

  Future<void> refresh() async {
    final tag = state.value?.tag;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(tag: tag));
  }

  /// Switch the tag filter (null = all) and reload from page 1.
  Future<void> setTag(String? tag) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(tag: tag));
  }

  /// Append the next server page (no-op while one is already loading).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final nextPage = (current.notes.length ~/ 50) + 1;
      final page = await ref
          .read(notesApiProvider)
          .list(page: nextPage, tag: current.tag);
      final seen = {for (final n in current.notes) n.id};
      state = AsyncData(current.copyWith(
        notes: [
          ...current.notes,
          for (final n in page.notes)
            if (!seen.contains(n.id)) n,
        ],
        total: page.total,
        tags: page.tags,
        loadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Quick-add a title-only note. With a tag filter active the new
  /// (untagged) note wouldn't match it, so the filter resets to "all" and
  /// the list reloads — the user always sees what they just captured.
  Future<void> add(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final current = state.value;
    try {
      final row = await ref.read(notesApiProvider).create(trimmed);
      if (current == null || current.tag != null) {
        state = await AsyncValue.guard(() => _fetch(tag: null));
      } else {
        state = AsyncData(current.copyWith(
          notes: [row, ...current.notes],
          total: current.total + 1,
        ));
      }
    } catch (_) {
      await _reloadSilently();
      rethrow; // let the screen surface the failure
    }
  }

  /// Delete a note (long-press action), optimistically.
  Future<void> delete(String id) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(
        notes: [
          for (final n in current.notes)
            if (n.id != id) n,
        ],
        total: current.total > 0 ? current.total - 1 : 0,
      ));
    }
    try {
      await ref.read(notesApiProvider).delete(id);
    } catch (_) {
      await _reloadSilently();
    }
  }

  /// Replace one row in place after an edit (note view saves ride through
  /// here so the list preview stays fresh without a refetch).
  void applyUpdated(NoteRow row) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      notes: [
        for (final n in current.notes)
          if (n.id == row.id) row else n,
      ],
    ));
  }

  Future<void> _reloadSilently() async {
    try {
      state = AsyncData(await _fetch(tag: state.value?.tag));
    } catch (_) {
      /* keep current; pull-to-refresh reconciles */
    }
  }
}

/// One note by id — backs the note view screen.
@riverpod
Future<NoteRow> noteContent(Ref ref, String id) {
  return ref.watch(notesApiProvider).get(id);
}
