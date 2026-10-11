// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pages_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the flat pages index shown for a brain older than the tree. Loads
/// every page on build; [search] swaps in the server's filtered list (`q`
/// matches title, content text and summary) and an empty query restores it.

@ProviderFor(PagesController)
final pagesControllerProvider = PagesControllerProvider._();

/// Owns the flat pages index shown for a brain older than the tree. Loads
/// every page on build; [search] swaps in the server's filtered list (`q`
/// matches title, content text and summary) and an empty query restores it.
final class PagesControllerProvider
    extends $AsyncNotifierProvider<PagesController, PagesIndex> {
  /// Owns the flat pages index shown for a brain older than the tree. Loads
  /// every page on build; [search] swaps in the server's filtered list (`q`
  /// matches title, content text and summary) and an empty query restores it.
  PagesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pagesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pagesControllerHash();

  @$internal
  @override
  PagesController create() => PagesController();
}

String _$pagesControllerHash() => r'24e10e3ed6cfc2b22c0e7eccb5fe05359df2905b';

/// Owns the flat pages index shown for a brain older than the tree. Loads
/// every page on build; [search] swaps in the server's filtered list (`q`
/// matches title, content text and summary) and an empty query restores it.

abstract class _$PagesController extends $AsyncNotifier<PagesIndex> {
  FutureOr<PagesIndex> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PagesIndex>, PagesIndex>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PagesIndex>, PagesIndex>,
              AsyncValue<PagesIndex>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Everything the viewer needs for one page, fetched concurrently: metadata,
/// the markdown export, and backlinks. Backlinks are best-effort (a failure
/// yields an empty list rather than sinking the page).

@ProviderFor(pageContent)
final pageContentProvider = PageContentFamily._();

/// Everything the viewer needs for one page, fetched concurrently: metadata,
/// the markdown export, and backlinks. Backlinks are best-effort (a failure
/// yields an empty list rather than sinking the page).

final class PageContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<PageContent>,
          PageContent,
          FutureOr<PageContent>
        >
    with $FutureModifier<PageContent>, $FutureProvider<PageContent> {
  /// Everything the viewer needs for one page, fetched concurrently: metadata,
  /// the markdown export, and backlinks. Backlinks are best-effort (a failure
  /// yields an empty list rather than sinking the page).
  PageContentProvider._({
    required PageContentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pageContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pageContentHash();

  @override
  String toString() {
    return r'pageContentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PageContent> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PageContent> create(Ref ref) {
    final argument = this.argument as String;
    return pageContent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PageContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pageContentHash() => r'd66487f943ba9fbe83d387e094750cbbd1582e5a';

/// Everything the viewer needs for one page, fetched concurrently: metadata,
/// the markdown export, and backlinks. Backlinks are best-effort (a failure
/// yields an empty list rather than sinking the page).

final class PageContentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PageContent>, String> {
  PageContentFamily._()
    : super(
        retry: null,
        name: r'pageContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Everything the viewer needs for one page, fetched concurrently: metadata,
  /// the markdown export, and backlinks. Backlinks are best-effort (a failure
  /// yields an empty list rather than sinking the page).

  PageContentProvider call(String pageId) =>
      PageContentProvider._(argument: pageId, from: this);

  @override
  String toString() => r'pageContentProvider';
}

/// The pages of [folderId] (null is the top level) for a Folder index block:
/// title only, by name, read from the reader's own tree so it is always what
/// THIS reader may see. Never stored; asked again each time a page opens.

@ProviderFor(folderIndex)
final folderIndexProvider = FolderIndexFamily._();

/// The pages of [folderId] (null is the top level) for a Folder index block:
/// title only, by name, read from the reader's own tree so it is always what
/// THIS reader may see. Never stored; asked again each time a page opens.

final class FolderIndexProvider
    extends
        $FunctionalProvider<
          AsyncValue<FolderIndex>,
          FolderIndex,
          FutureOr<FolderIndex>
        >
    with $FutureModifier<FolderIndex>, $FutureProvider<FolderIndex> {
  /// The pages of [folderId] (null is the top level) for a Folder index block:
  /// title only, by name, read from the reader's own tree so it is always what
  /// THIS reader may see. Never stored; asked again each time a page opens.
  FolderIndexProvider._({
    required FolderIndexFamily super.from,
    required String? super.argument,
  }) : super(
         retry: noTreeRetry,
         name: r'folderIndexProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$folderIndexHash();

  @override
  String toString() {
    return r'folderIndexProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FolderIndex> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FolderIndex> create(Ref ref) {
    final argument = this.argument as String?;
    return folderIndex(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FolderIndexProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$folderIndexHash() => r'38e9d2457cf5fb19e0d3e1d36f88d056c6f25d3f';

/// The pages of [folderId] (null is the top level) for a Folder index block:
/// title only, by name, read from the reader's own tree so it is always what
/// THIS reader may see. Never stored; asked again each time a page opens.

final class FolderIndexFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<FolderIndex>, String?> {
  FolderIndexFamily._()
    : super(
        retry: noTreeRetry,
        name: r'folderIndexProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The pages of [folderId] (null is the top level) for a Folder index block:
  /// title only, by name, read from the reader's own tree so it is always what
  /// THIS reader may see. Never stored; asked again each time a page opens.

  FolderIndexProvider call(String? folderId) =>
      FolderIndexProvider._(argument: folderId, from: this);

  @override
  String toString() => r'folderIndexProvider';
}
