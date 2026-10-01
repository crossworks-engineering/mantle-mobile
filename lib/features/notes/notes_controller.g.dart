// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(noteFiling)
final noteFilingProvider = NoteFilingProvider._();

final class NoteFilingProvider
    extends $FunctionalProvider<NoteFiling, NoteFiling, NoteFiling>
    with $Provider<NoteFiling> {
  NoteFilingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteFilingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteFilingHash();

  @$internal
  @override
  $ProviderElement<NoteFiling> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NoteFiling create(Ref ref) {
    return noteFiling(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NoteFiling value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NoteFiling>(value),
    );
  }
}

String _$noteFilingHash() => r'65946db2ba66918b4708edf0a42c9504ce551af2';

/// Owns the flat notes list shown for a brain older than the folder tree:
/// first page on build, older pages via [loadMore],
/// a tag filter, and optimistic quick-add/delete (a failure reloads so the
/// screen never lies for long).

@ProviderFor(NotesController)
final notesControllerProvider = NotesControllerProvider._();

/// Owns the flat notes list shown for a brain older than the folder tree:
/// first page on build, older pages via [loadMore],
/// a tag filter, and optimistic quick-add/delete (a failure reloads so the
/// screen never lies for long).
final class NotesControllerProvider
    extends $AsyncNotifierProvider<NotesController, NotesState> {
  /// Owns the flat notes list shown for a brain older than the folder tree:
  /// first page on build, older pages via [loadMore],
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

String _$notesControllerHash() => r'fc352ae605b9fae6bde2b543f2a9b6ac043a3c39';

/// Owns the flat notes list shown for a brain older than the folder tree:
/// first page on build, older pages via [loadMore],
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

/// One note by id — backs the note view screen. Class-based so the edit
/// sheet saves THROUGH the controller (UI → controller → data source, per
/// the layering rule) and the open screen reflects the save without a
/// refetch.

@ProviderFor(NoteViewController)
final noteViewControllerProvider = NoteViewControllerFamily._();

/// One note by id — backs the note view screen. Class-based so the edit
/// sheet saves THROUGH the controller (UI → controller → data source, per
/// the layering rule) and the open screen reflects the save without a
/// refetch.
final class NoteViewControllerProvider
    extends $AsyncNotifierProvider<NoteViewController, NoteRow> {
  /// One note by id — backs the note view screen. Class-based so the edit
  /// sheet saves THROUGH the controller (UI → controller → data source, per
  /// the layering rule) and the open screen reflects the save without a
  /// refetch.
  NoteViewControllerProvider._({
    required NoteViewControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'noteViewControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteViewControllerHash();

  @override
  String toString() {
    return r'noteViewControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  NoteViewController create() => NoteViewController();

  @override
  bool operator ==(Object other) {
    return other is NoteViewControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteViewControllerHash() =>
    r'7e3528b62059b0970a7fc1306276b16107515769';

/// One note by id — backs the note view screen. Class-based so the edit
/// sheet saves THROUGH the controller (UI → controller → data source, per
/// the layering rule) and the open screen reflects the save without a
/// refetch.

final class NoteViewControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          NoteViewController,
          AsyncValue<NoteRow>,
          NoteRow,
          FutureOr<NoteRow>,
          String
        > {
  NoteViewControllerFamily._()
    : super(
        retry: null,
        name: r'noteViewControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One note by id — backs the note view screen. Class-based so the edit
  /// sheet saves THROUGH the controller (UI → controller → data source, per
  /// the layering rule) and the open screen reflects the save without a
  /// refetch.

  NoteViewControllerProvider call(String id) =>
      NoteViewControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'noteViewControllerProvider';
}

/// One note by id — backs the note view screen. Class-based so the edit
/// sheet saves THROUGH the controller (UI → controller → data source, per
/// the layering rule) and the open screen reflects the save without a
/// refetch.

abstract class _$NoteViewController extends $AsyncNotifier<NoteRow> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<NoteRow> build(String id);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<NoteRow>, NoteRow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<NoteRow>, NoteRow>,
              AsyncValue<NoteRow>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
