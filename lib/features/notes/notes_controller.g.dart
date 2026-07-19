// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the notes list: first page on build, older pages via [loadMore],
/// a tag filter, and optimistic quick-add/delete (a failure reloads so the
/// screen never lies for long).

@ProviderFor(NotesController)
final notesControllerProvider = NotesControllerProvider._();

/// Owns the notes list: first page on build, older pages via [loadMore],
/// a tag filter, and optimistic quick-add/delete (a failure reloads so the
/// screen never lies for long).
final class NotesControllerProvider
    extends $AsyncNotifierProvider<NotesController, NotesState> {
  /// Owns the notes list: first page on build, older pages via [loadMore],
  /// a tag filter, and optimistic quick-add/delete (a failure reloads so the
  /// screen never lies for long).
  NotesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notesControllerHash();

  @$internal
  @override
  NotesController create() => NotesController();
}

String _$notesControllerHash() => r'28798e32166875bbef683963cb0f827dc8096f82';

/// Owns the notes list: first page on build, older pages via [loadMore],
/// a tag filter, and optimistic quick-add/delete (a failure reloads so the
/// screen never lies for long).

abstract class _$NotesController extends $AsyncNotifier<NotesState> {
  FutureOr<NotesState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<NotesState>, NotesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<NotesState>, NotesState>,
              AsyncValue<NotesState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// One note by id — backs the note view screen.

@ProviderFor(noteContent)
final noteContentProvider = NoteContentFamily._();

/// One note by id — backs the note view screen.

final class NoteContentProvider
    extends $FunctionalProvider<AsyncValue<NoteRow>, NoteRow, FutureOr<NoteRow>>
    with $FutureModifier<NoteRow>, $FutureProvider<NoteRow> {
  /// One note by id — backs the note view screen.
  NoteContentProvider._({
    required NoteContentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'noteContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteContentHash();

  @override
  String toString() {
    return r'noteContentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<NoteRow> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<NoteRow> create(Ref ref) {
    final argument = this.argument as String;
    return noteContent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoteContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteContentHash() => r'50a30b5de9f716ac2ecd7c031bdb77e3d4f0d643';

/// One note by id — backs the note view screen.

final class NoteContentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<NoteRow>, String> {
  NoteContentFamily._()
    : super(
        retry: null,
        name: r'noteContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One note by id — backs the note view screen.

  NoteContentProvider call(String id) =>
      NoteContentProvider._(argument: id, from: this);

  @override
  String toString() => r'noteContentProvider';
}
