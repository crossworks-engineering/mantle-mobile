// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Kinds whose tree this brain does not serve (a 404 on the root: a brain
/// older than the tree). A screen that finds its kind here shows the list it
/// had before the tree and stops asking.
///
/// Per brain and per login: it watches the tree client, which is rebuilt
/// with the HTTP client whenever either changes, so a switch to a newer
/// brain starts clean.
///
/// Not for ever: the brain may be updated while the app runs. When the app
/// comes back to the front, a mark older than [reprobeAfter] is dropped, so
/// the screen asks for the tree once more.

@ProviderFor(TreeUnavailableKinds)
final treeUnavailableKindsProvider = TreeUnavailableKindsProvider._();

/// Kinds whose tree this brain does not serve (a 404 on the root: a brain
/// older than the tree). A screen that finds its kind here shows the list it
/// had before the tree and stops asking.
///
/// Per brain and per login: it watches the tree client, which is rebuilt
/// with the HTTP client whenever either changes, so a switch to a newer
/// brain starts clean.
///
/// Not for ever: the brain may be updated while the app runs. When the app
/// comes back to the front, a mark older than [reprobeAfter] is dropped, so
/// the screen asks for the tree once more.
final class TreeUnavailableKindsProvider
    extends $NotifierProvider<TreeUnavailableKinds, Set<TreeKind>> {
  /// Kinds whose tree this brain does not serve (a 404 on the root: a brain
  /// older than the tree). A screen that finds its kind here shows the list it
  /// had before the tree and stops asking.
  ///
  /// Per brain and per login: it watches the tree client, which is rebuilt
  /// with the HTTP client whenever either changes, so a switch to a newer
  /// brain starts clean.
  ///
  /// Not for ever: the brain may be updated while the app runs. When the app
  /// comes back to the front, a mark older than [reprobeAfter] is dropped, so
  /// the screen asks for the tree once more.
  TreeUnavailableKindsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'treeUnavailableKindsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$treeUnavailableKindsHash();

  @$internal
  @override
  TreeUnavailableKinds create() => TreeUnavailableKinds();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<TreeKind> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<TreeKind>>(value),
    );
  }
}

String _$treeUnavailableKindsHash() =>
    r'1d6341dbc2365aae860046df7782cf83c731160a';

/// Kinds whose tree this brain does not serve (a 404 on the root: a brain
/// older than the tree). A screen that finds its kind here shows the list it
/// had before the tree and stops asking.
///
/// Per brain and per login: it watches the tree client, which is rebuilt
/// with the HTTP client whenever either changes, so a switch to a newer
/// brain starts clean.
///
/// Not for ever: the brain may be updated while the app runs. When the app
/// comes back to the front, a mark older than [reprobeAfter] is dropped, so
/// the screen asks for the tree once more.

abstract class _$TreeUnavailableKinds extends $Notifier<Set<TreeKind>> {
  Set<TreeKind> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<TreeKind>, Set<TreeKind>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<TreeKind>, Set<TreeKind>>,
              Set<TreeKind>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// One folder of one kind's tree: a family by kind and folder id (null is the
/// root), so each level a person drills into keeps its own rows and going
/// back up shows them at once.

@ProviderFor(TreeFolderController)
final treeFolderControllerProvider = TreeFolderControllerFamily._();

/// One folder of one kind's tree: a family by kind and folder id (null is the
/// root), so each level a person drills into keeps its own rows and going
/// back up shows them at once.
final class TreeFolderControllerProvider
    extends $AsyncNotifierProvider<TreeFolderController, TreeFolderState> {
  /// One folder of one kind's tree: a family by kind and folder id (null is the
  /// root), so each level a person drills into keeps its own rows and going
  /// back up shows them at once.
  TreeFolderControllerProvider._({
    required TreeFolderControllerFamily super.from,
    required (TreeKind, String?) super.argument,
  }) : super(
         retry: noTreeRetry,
         name: r'treeFolderControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$treeFolderControllerHash();

  @override
  String toString() {
    return r'treeFolderControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  TreeFolderController create() => TreeFolderController();

  @override
  bool operator ==(Object other) {
    return other is TreeFolderControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$treeFolderControllerHash() =>
    r'a5c6be62b627c85ec79db33f63988ae2cd26736a';

/// One folder of one kind's tree: a family by kind and folder id (null is the
/// root), so each level a person drills into keeps its own rows and going
/// back up shows them at once.

final class TreeFolderControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TreeFolderController,
          AsyncValue<TreeFolderState>,
          TreeFolderState,
          FutureOr<TreeFolderState>,
          (TreeKind, String?)
        > {
  TreeFolderControllerFamily._()
    : super(
        retry: noTreeRetry,
        name: r'treeFolderControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One folder of one kind's tree: a family by kind and folder id (null is the
  /// root), so each level a person drills into keeps its own rows and going
  /// back up shows them at once.

  TreeFolderControllerProvider call(TreeKind kind, String? folderId) =>
      TreeFolderControllerProvider._(argument: (kind, folderId), from: this);

  @override
  String toString() => r'treeFolderControllerProvider';
}

/// One folder of one kind's tree: a family by kind and folder id (null is the
/// root), so each level a person drills into keeps its own rows and going
/// back up shows them at once.

abstract class _$TreeFolderController extends $AsyncNotifier<TreeFolderState> {
  late final _$args = ref.$arg as (TreeKind, String?);
  TreeKind get kind => _$args.$1;
  String? get folderId => _$args.$2;

  FutureOr<TreeFolderState> build(TreeKind kind, String? folderId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TreeFolderState>, TreeFolderState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TreeFolderState>, TreeFolderState>,
              AsyncValue<TreeFolderState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}

/// Search as you type within one kind, with the same stale-answer guard as
/// the global search: only the latest request may write results.

@ProviderFor(TreeSearchController)
final treeSearchControllerProvider = TreeSearchControllerFamily._();

/// Search as you type within one kind, with the same stale-answer guard as
/// the global search: only the latest request may write results.
final class TreeSearchControllerProvider
    extends $NotifierProvider<TreeSearchController, TreeSearchState> {
  /// Search as you type within one kind, with the same stale-answer guard as
  /// the global search: only the latest request may write results.
  TreeSearchControllerProvider._({
    required TreeSearchControllerFamily super.from,
    required TreeKind super.argument,
  }) : super(
         retry: null,
         name: r'treeSearchControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$treeSearchControllerHash();

  @override
  String toString() {
    return r'treeSearchControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TreeSearchController create() => TreeSearchController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TreeSearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TreeSearchState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TreeSearchControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$treeSearchControllerHash() =>
    r'74768353794e8868b543c405a83d7cff70cfe17d';

/// Search as you type within one kind, with the same stale-answer guard as
/// the global search: only the latest request may write results.

final class TreeSearchControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TreeSearchController,
          TreeSearchState,
          TreeSearchState,
          TreeSearchState,
          TreeKind
        > {
  TreeSearchControllerFamily._()
    : super(
        retry: null,
        name: r'treeSearchControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Search as you type within one kind, with the same stale-answer guard as
  /// the global search: only the latest request may write results.

  TreeSearchControllerProvider call(TreeKind kind) =>
      TreeSearchControllerProvider._(argument: kind, from: this);

  @override
  String toString() => r'treeSearchControllerProvider';
}

/// Search as you type within one kind, with the same stale-answer guard as
/// the global search: only the latest request may write results.

abstract class _$TreeSearchController extends $Notifier<TreeSearchState> {
  late final _$args = ref.$arg as TreeKind;
  TreeKind get kind => _$args;

  TreeSearchState build(TreeKind kind);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TreeSearchState, TreeSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TreeSearchState, TreeSearchState>,
              TreeSearchState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// This login's recently opened items of a kind, newest first, each with the
/// crumbs of where it lives. Fetched when the Recent view is opened; the view
/// is never remembered, so every screen opens on Folders.

@ProviderFor(treeRecent)
final treeRecentProvider = TreeRecentFamily._();

/// This login's recently opened items of a kind, newest first, each with the
/// crumbs of where it lives. Fetched when the Recent view is opened; the view
/// is never remembered, so every screen opens on Folders.

final class TreeRecentProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TreeItem>>,
          List<TreeItem>,
          FutureOr<List<TreeItem>>
        >
    with $FutureModifier<List<TreeItem>>, $FutureProvider<List<TreeItem>> {
  /// This login's recently opened items of a kind, newest first, each with the
  /// crumbs of where it lives. Fetched when the Recent view is opened; the view
  /// is never remembered, so every screen opens on Folders.
  TreeRecentProvider._({
    required TreeRecentFamily super.from,
    required TreeKind super.argument,
  }) : super(
         retry: noTreeRetry,
         name: r'treeRecentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$treeRecentHash();

  @override
  String toString() {
    return r'treeRecentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TreeItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TreeItem>> create(Ref ref) {
    final argument = this.argument as TreeKind;
    return treeRecent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TreeRecentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$treeRecentHash() => r'5e3db3ab7d4bf87496a468cfc34aaf2392c348f1';

/// This login's recently opened items of a kind, newest first, each with the
/// crumbs of where it lives. Fetched when the Recent view is opened; the view
/// is never remembered, so every screen opens on Folders.

final class TreeRecentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TreeItem>>, TreeKind> {
  TreeRecentFamily._()
    : super(
        retry: noTreeRetry,
        name: r'treeRecentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// This login's recently opened items of a kind, newest first, each with the
  /// crumbs of where it lives. Fetched when the Recent view is opened; the view
  /// is never remembered, so every screen opens on Folders.

  TreeRecentProvider call(TreeKind kind) =>
      TreeRecentProvider._(argument: kind, from: this);

  @override
  String toString() => r'treeRecentProvider';
}

/// The tags on a kind's items, most used first, for the filter row. A brain
/// that cannot answer simply shows no row.

@ProviderFor(treeTags)
final treeTagsProvider = TreeTagsFamily._();

/// The tags on a kind's items, most used first, for the filter row. A brain
/// that cannot answer simply shows no row.

final class TreeTagsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TreeTag>>,
          List<TreeTag>,
          FutureOr<List<TreeTag>>
        >
    with $FutureModifier<List<TreeTag>>, $FutureProvider<List<TreeTag>> {
  /// The tags on a kind's items, most used first, for the filter row. A brain
  /// that cannot answer simply shows no row.
  TreeTagsProvider._({
    required TreeTagsFamily super.from,
    required TreeKind super.argument,
  }) : super(
         retry: null,
         name: r'treeTagsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$treeTagsHash();

  @override
  String toString() {
    return r'treeTagsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TreeTag>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TreeTag>> create(Ref ref) {
    final argument = this.argument as TreeKind;
    return treeTags(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TreeTagsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$treeTagsHash() => r'2d5fefce9dd1a56f708ae682989364082f46c6e0';

/// The tags on a kind's items, most used first, for the filter row. A brain
/// that cannot answer simply shows no row.

final class TreeTagsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TreeTag>>, TreeKind> {
  TreeTagsFamily._()
    : super(
        retry: null,
        name: r'treeTagsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The tags on a kind's items, most used first, for the filter row. A brain
  /// that cannot answer simply shows no row.

  TreeTagsProvider call(TreeKind kind) =>
      TreeTagsProvider._(argument: kind, from: this);

  @override
  String toString() => r'treeTagsProvider';
}
