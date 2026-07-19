// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the journal: newest-first entries (first page) and quick capture.
/// [capture] posts the body and prepends the saved row; [transcribe] routes a
/// voice note through the assistant's STT endpoint (the same pipeline the chat
/// composer uses) so an entry can be spoken instead of typed.

@ProviderFor(JournalController)
final journalControllerProvider = JournalControllerProvider._();

/// Owns the journal: newest-first entries (first page) and quick capture.
/// [capture] posts the body and prepends the saved row; [transcribe] routes a
/// voice note through the assistant's STT endpoint (the same pipeline the chat
/// composer uses) so an entry can be spoken instead of typed.
final class JournalControllerProvider
    extends $AsyncNotifierProvider<JournalController, List<JournalRow>> {
  /// Owns the journal: newest-first entries (first page) and quick capture.
  /// [capture] posts the body and prepends the saved row; [transcribe] routes a
  /// voice note through the assistant's STT endpoint (the same pipeline the chat
  /// composer uses) so an entry can be spoken instead of typed.
  JournalControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalControllerHash();

  @$internal
  @override
  JournalController create() => JournalController();
}

String _$journalControllerHash() => r'0a537b8f7d6c56b9594dcc0b84c953df77c4613f';

/// Owns the journal: newest-first entries (first page) and quick capture.
/// [capture] posts the body and prepends the saved row; [transcribe] routes a
/// voice note through the assistant's STT endpoint (the same pipeline the chat
/// composer uses) so an entry can be spoken instead of typed.

abstract class _$JournalController extends $AsyncNotifier<List<JournalRow>> {
  FutureOr<List<JournalRow>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<JournalRow>>, List<JournalRow>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<JournalRow>>, List<JournalRow>>,
              AsyncValue<List<JournalRow>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
