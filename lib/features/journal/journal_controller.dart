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
