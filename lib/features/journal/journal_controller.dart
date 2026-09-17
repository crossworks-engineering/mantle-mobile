import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/chat/chat_repository.dart';
import '../../data/journal/journal_api.dart';
import '../../data/journal/journal_models.dart';

part 'journal_controller.g.dart';

/// Owns the journal: newest-first entries (first page) and quick capture.
/// [capture] posts the body and slots the saved row in date order;
/// [transcribe] routes a voice note through the assistant's STT endpoint (the
/// same pipeline the chat composer uses) so an entry can be spoken instead of
/// typed.
///
/// The list is ordered here, by the date the screen shows
/// ([JournalRow.displayDate]: the entry's own date when it has one, else when
/// it was created). The server orders by creation, and an entry written today
/// about last week must sit under last week.
@riverpod
class JournalController extends _$JournalController {
  @override
  Future<List<JournalRow>> build() async {
    return newestFirst((await ref.read(journalApiProvider).list()).journals);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(
      () async =>
          newestFirst((await ref.read(journalApiProvider).list()).journals),
    );
    if (ref.mounted) state = next;
  }

  /// Save an entry. Throws on failure so the composer keeps the text for a
  /// retry; on success the saved row (with its server-derived title) lands
  /// where its date puts it.
  Future<void> capture(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final row = await ref.read(journalApiProvider).create(trimmed);
    if (!ref.mounted) return;
    final current = state.value;
    if (current != null) {
      state = AsyncData(newestFirst([row, ...current]));
    }
  }

  /// Rewrite an entry's body. Server first (the sheet shows a failure), then
  /// the row is swapped in place; its date does not change, so its place in
  /// the list does not either.
  Future<void> edit(String id, {required String body}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final row = await ref.read(journalApiProvider).update(id, body: trimmed);
    if (!ref.mounted) return;
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final r in current)
          if (r.id == id) row else r,
      ]);
    }
  }

  /// Delete an entry, optimistically; a failure reloads so the list never
  /// lies for long.
  Future<void> delete(String id) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final r in current)
          if (r.id != id) r,
      ]);
    }
    try {
      await ref.read(journalApiProvider).delete(id);
    } catch (_) {
      await _reloadSilently();
    }
  }

  /// Answer one of the assistant's open questions. The gap flips to
  /// resolved in place and the answer lands where its date puts it.
  Future<void> answerGap(String id, {required String answer}) async {
    final trimmed = answer.trim();
    if (trimmed.isEmpty) return;
    final result =
        await ref.read(journalApiProvider).resolveGap(id, answer: trimmed);
    if (!ref.mounted) return;
    final current = state.value;
    if (current != null) {
      state = AsyncData(newestFirst([
        result.answer,
        for (final r in current)
          if (r.id == id) result.gap else r,
      ]));
    }
  }

  Future<void> _reloadSilently() async {
    try {
      final rows =
          newestFirst((await ref.read(journalApiProvider).list()).journals);
      if (ref.mounted) state = AsyncData(rows);
    } catch (_) {
      /* keep current; refresh reconciles */
    }
  }

  /// Voice note → text, via `POST /api/assistant/transcribe` (shared with the
  /// chat composer — one STT pipeline for the whole app).
  Future<String> transcribe(String audioPath) =>
      ref.read(chatRepositoryProvider).transcribe(audioPath);
}

/// Newest [JournalRow.displayDate] first; ties broken by creation time so two
/// entries for the same day keep the order they were written in.
List<JournalRow> newestFirst(List<JournalRow> rows) {
  final sorted = [...rows]..sort((a, b) {
      final byDate = b.displayDate.compareTo(a.displayDate);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
  return sorted;
}
