// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pages_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PagesController)
final pagesControllerProvider = PagesControllerProvider._();

final class PagesControllerProvider
    extends $AsyncNotifierProvider<PagesController, PagesIndex> {
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

String _$pagesControllerHash() => r'0000000000000000000000000000000000000000';

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

@ProviderFor(pageContent)
final pageContentProvider = PageContentFamily._();

final class PageContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<PageContent>,
          PageContent,
          FutureOr<PageContent>
        >
    with $FutureModifier<PageContent>, $FutureProvider<PageContent> {
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
  $FutureProviderElement<PageContent> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

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

String _$pageContentHash() => r'0000000000000000000000000000000000000000';

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

  PageContentProvider call(String pageId) =>
      PageContentProvider._(argument: pageId, from: this);

  @override
  String toString() => r'pageContentProvider';
}
