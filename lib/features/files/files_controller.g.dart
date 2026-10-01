// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'files_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fileFiling)
final fileFilingProvider = FileFilingProvider._();

final class FileFilingProvider
    extends $FunctionalProvider<FileFiling, FileFiling, FileFiling>
    with $Provider<FileFiling> {
  FileFilingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileFilingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileFilingHash();

  @$internal
  @override
  $ProviderElement<FileFiling> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileFiling create(Ref ref) {
    return fileFiling(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileFiling value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileFiling>(value),
    );
  }
}

String _$fileFilingHash() => r'd389cad5cc3c81c21ab8d38464ff76dd08b1a375';

/// Owns one folder's listing for a brain older than the folder tree (a
/// family by ltree path: each drilled folder
/// screen gets its own instance). Upload refreshes; delete is optimistic
/// with a silent reload on failure.

@ProviderFor(FilesController)
final filesControllerProvider = FilesControllerFamily._();

/// Owns one folder's listing for a brain older than the folder tree (a
/// family by ltree path: each drilled folder
/// screen gets its own instance). Upload refreshes; delete is optimistic
/// with a silent reload on failure.
final class FilesControllerProvider
    extends $AsyncNotifierProvider<FilesController, FolderContents> {
  /// Owns one folder's listing for a brain older than the folder tree (a
  /// family by ltree path: each drilled folder
  /// screen gets its own instance). Upload refreshes; delete is optimistic
  /// with a silent reload on failure.
  FilesControllerProvider._({
    required FilesControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'filesControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$filesControllerHash();

  @override
  String toString() {
    return r'filesControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FilesController create() => FilesController();

  @override
  bool operator ==(Object other) {
    return other is FilesControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$filesControllerHash() => r'ba66e1c42d1c8d6cb46f9fc6458db2c12273c733';

/// Owns one folder's listing for a brain older than the folder tree (a
/// family by ltree path: each drilled folder
/// screen gets its own instance). Upload refreshes; delete is optimistic
/// with a silent reload on failure.

final class FilesControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          FilesController,
          AsyncValue<FolderContents>,
          FolderContents,
          FutureOr<FolderContents>,
          String
        > {
  FilesControllerFamily._()
    : super(
        retry: null,
        name: r'filesControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Owns one folder's listing for a brain older than the folder tree (a
  /// family by ltree path: each drilled folder
  /// screen gets its own instance). Upload refreshes; delete is optimistic
  /// with a silent reload on failure.

  FilesControllerProvider call(String path) =>
      FilesControllerProvider._(argument: path, from: this);

  @override
  String toString() => r'filesControllerProvider';
}

/// Owns one folder's listing for a brain older than the folder tree (a
/// family by ltree path: each drilled folder
/// screen gets its own instance). Upload refreshes; delete is optimistic
/// with a silent reload on failure.

abstract class _$FilesController extends $AsyncNotifier<FolderContents> {
  late final _$args = ref.$arg as String;
  String get path => _$args;

  FutureOr<FolderContents> build(String path);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<FolderContents>, FolderContents>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FolderContents>, FolderContents>,
              AsyncValue<FolderContents>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
