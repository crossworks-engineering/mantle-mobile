// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(JournalController)
final journalControllerProvider = JournalControllerProvider._();

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
final class JournalControllerProvider
    extends $AsyncNotifierProvider<JournalController, List<JournalRow>> {
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

String _$journalControllerHash() => r'2e471b1df6b59b097ae104a1819feca7ebdf23ca';

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
