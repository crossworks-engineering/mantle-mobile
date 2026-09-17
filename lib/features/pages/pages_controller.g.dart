// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pages_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the pages index. Loads the whole hierarchy on build (`mode:'tree'`,
/// flat rows — the screen builds the tree); [search] swaps in the server's
/// filtered flat list (`q` matches title, content text, and summary) and an
/// empty query restores the tree.

@ProviderFor(PagesController)
final pagesControllerProvider = PagesControllerProvider._();

/// Owns the pages index. Loads the whole hierarchy on build (`mode:'tree'`,
/// flat rows — the screen builds the tree); [search] swaps in the server's
/// filtered flat list (`q` matches title, content text, and summary) and an
/// empty query restores the tree.
final class PagesControllerProvider
    extends $AsyncNotifierProvider<PagesController, PagesIndex> {
  /// Owns the pages index. Loads the whole hierarchy on build (`mode:'tree'`,
  /// flat rows — the screen builds the tree); [search] swaps in the server's
  /// filtered flat list (`q` matches title, content text, and summary) and an
  /// empty query restores the tree.
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

String _$pagesControllerHash() => r'28cd522ec84129815d247e98f2b0908414f3f2f5';

/// Owns the pages index. Loads the whole hierarchy on build (`mode:'tree'`,
/// flat rows — the screen builds the tree); [search] swaps in the server's
/// filtered flat list (`q` matches title, content text, and summary) and an
/// empty query restores the tree.

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

String _$pageContentHash() => r'39af72e426b4e485fb4bd1df73a5075526698716';

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
