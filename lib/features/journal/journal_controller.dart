import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/chat/chat_repository.dart';
import '../../data/journal/journal_api.dart';
import '../../data/journal/journal_models.dart';

part 'journal_controller.g.dart';

/// Owns the journal: newest-first entries (first page) and quick capture.
/// [capture] posts the body and prepends the saved row; [transcribe] routes a
/// voice note through the assistant's STT endpoint (the same pipeline the chat
/// composer uses) so an entry can be spoken instead of typed.
@riverpod
class JournalController extends _$JournalController {
  @override
  Future<List<JournalRow>> build() async {
    return (await ref.read(journalApiProvider).list()).journals;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async => (await ref.read(journalApiProvider).list()).journals,
    );
  }

  /// Save an entry. Throws on failure so the composer keeps the text for a
  /// retry; on success the saved row (with its server-derived title) prepends.
  Future<void> capture(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final row = await ref.read(journalApiProvider).create(trimmed);
    final current = state.value;
    if (current != null) {
      state = AsyncData([row, ...current]);
    }
  }

  /// Voice note → text, via `POST /api/assistant/transcribe` (shared with the
  /// chat composer — one STT pipeline for the whole app).
  Future<String> transcribe(String audioPath) =>
      ref.read(chatRepositoryProvider).transcribe(audioPath);
}
