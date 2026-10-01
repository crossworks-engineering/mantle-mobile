import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/notes/notes_api.dart';
import '../../data/notes/notes_models.dart';
import '../../data/tree/tree_api.dart';
import '../../data/tree/tree_models.dart';

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
    this.page = 1,
    this.loadingMore = false,
  });

  final List<NoteRow> notes;
  final int total;
  final List<NoteTag> tags;

  /// Active tag filter (null = all notes).
  final String? tag;

  /// Highest server page loaded — the paging cursor. Deriving it from
  /// `notes.length ~/ pageSize` desyncs after local deletes; a counter
  /// doesn't.
  final int page;
  final bool loadingMore;

  bool get hasMore => notes.length < total;

  NotesState copyWith({
    List<NoteRow>? notes,
    int? total,
    List<NoteTag>? tags,
    String? tag,
    bool clearTag = false,
    int? page,
    bool? loadingMore,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      total: total ?? this.total,
      tags: tags ?? this.tags,
      tag: clearTag ? null : (tag ?? this.tag),
      page: page ?? this.page,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// Thrown by [NoteFiling.capture] when the note was saved but filing it in
/// the open folder would change who can read it (the folder is shared). The
/// note sits at the top level until the person agrees; [refusal] says what
/// would change.
class NoteNeedsConfirm implements Exception {
  const NoteNeedsConfirm({required this.note, required this.refusal});

  final NoteRow note;
  final TreeVisibilityRefusal refusal;
}

/// Capturing and deleting notes from the folder tree. The brain creates a
/// note at the top level (`POST /api/notes` takes no folder), so capturing
/// into a folder is a create followed by the tree's item move.
///
/// It holds the two clients themselves, not a `Ref`: the provider is
/// auto-disposed as soon as nothing reads it, and a capture is still running
/// then.
class NoteFiling {
  NoteFiling(this._notes, this._tree);

  final NotesApi _notes;
  final TreeApi _tree;

  /// Save a title-only note and file it in [folderId] (null is the top
  /// level). Throws [NoteNeedsConfirm] when the folder is shared: the note
  /// exists, at the top level, and [fileConfirmed] finishes the job.
  Future<NoteRow> capture(String title, {String? folderId}) async {
    final note = await _notes.create(title.trim());
    if (folderId == null) return note;
    try {
      await _tree.move(TreeKind.notes, [note.id], folderId);
    } on TreeVisibilityRefusal catch (refusal) {
      throw NoteNeedsConfirm(note: note, refusal: refusal);
    }
    return note;
  }

  /// File a captured note in a shared folder, now that the person has seen
  /// who will be able to read it.
  Future<void> fileConfirmed(
    String noteId,
    String folderId,
    TreeVisibilityRefusal refusal,
  ) async {
    await _tree.move(
      TreeKind.notes,
      [noteId],
      folderId,
      confirm: true,
      seen: refusal.seen,
    );
  }

  Future<void> delete(String id) => _notes.delete(id);
}

@riverpod
NoteFiling noteFiling(Ref ref) =>
    NoteFiling(ref.watch(notesApiProvider), ref.watch(treeApiProvider));

/// Owns the flat notes list shown for a brain older than the folder tree:
/// first page on build, older pages via [loadMore],
/// a tag filter, and optimistic quick-add/delete (a failure reloads so the
/// screen never lies for long).
@riverpod
class NotesController extends _$NotesController {
  @override
  Future<NotesState> build() {
    // Rebuilt with the client: another login, or another brain.
    ref.watch(notesApiProvider);
    return _fetch(tag: null);
  }

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
    final next = await AsyncValue.guard(() => _fetch(tag: tag));
    if (ref.mounted) state = next;
  }

  /// Switch the tag filter (null = all) and reload from page 1.
  Future<void> setTag(String? tag) async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() => _fetch(tag: tag));
    if (ref.mounted) state = next;
  }

  /// Append the next server page (no-op while one is already loading).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final page = await ref
          .read(notesApiProvider)
          .list(page: nextPage, tag: current.tag);
      if (!ref.mounted) return;
      // Rebase on the LIVE state, not the pre-await snapshot — an optimistic
      // delete/edit that landed mid-fetch must not be resurrected.
      final now = state.value;
      if (now == null || now.tag != current.tag) return;
      final seen = {for (final n in now.notes) n.id};
      state = AsyncData(now.copyWith(
        notes: [
          ...now.notes,
          for (final n in page.notes)
            if (!seen.contains(n.id)) n,
        ],
        total: page.total,
        tags: page.tags,
        page: nextPage,
        loadingMore: false,
      ));
    } catch (_) {
      if (!ref.mounted) return;
      final now = state.value;
      if (now != null) state = AsyncData(now.copyWith(loadingMore: false));
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
      if (!ref.mounted) return;
      if (current == null || current.tag != null) {
        final next = await AsyncValue.guard(() => _fetch(tag: null));
        if (ref.mounted) state = next;
      } else {
        final now = state.value ?? current;
        state = AsyncData(now.copyWith(
          notes: [row, ...now.notes],
          total: now.total + 1,
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
      if (ref.mounted) await _reloadSilently();
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
      final next = await _fetch(tag: state.value?.tag);
      if (ref.mounted) state = AsyncData(next);
    } catch (_) {
      /* keep current; pull-to-refresh reconciles */
    }
  }
}

/// One note by id — backs the note view screen. Class-based so the edit
/// sheet saves THROUGH the controller (UI → controller → data source, per
/// the layering rule) and the open screen reflects the save without a
/// refetch.
@riverpod
class NoteViewController extends _$NoteViewController {
  @override
  Future<NoteRow> build(String id) => ref.watch(notesApiProvider).get(id);

  /// `PATCH /api/notes/{id}` via the api; the saved row becomes this
  /// screen's state and is returned so the caller can sync the list.
  Future<NoteRow> save({
    String? title,
    String? content,
    List<String>? tags,
  }) async {
    final saved = await ref
        .read(notesApiProvider)
        .update(id, title: title, content: content, tags: tags);
    if (ref.mounted) state = AsyncData(saved);
    return saved;
  }
}
