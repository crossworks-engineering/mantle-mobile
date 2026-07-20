// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'files_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns one folder's listing (a family by ltree path — each drilled folder
/// screen gets its own instance). Upload refreshes; delete is optimistic
/// with a silent reload on failure.

@ProviderFor(FilesController)
final filesControllerProvider = FilesControllerFamily._();

/// Owns one folder's listing (a family by ltree path — each drilled folder
/// screen gets its own instance). Upload refreshes; delete is optimistic
/// with a silent reload on failure.
final class FilesControllerProvider
    extends $AsyncNotifierProvider<FilesController, FolderContents> {
  /// Owns one folder's listing (a family by ltree path — each drilled folder
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

String _$filesControllerHash() => r'0e385bf03780b859e918557b1b29d0ea93043fc5';

/// Owns one folder's listing (a family by ltree path — each drilled folder
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

  /// Owns one folder's listing (a family by ltree path — each drilled folder
  /// screen gets its own instance). Upload refreshes; delete is optimistic
  /// with a silent reload on failure.

  FilesControllerProvider call(String path) =>
      FilesControllerProvider._(argument: path, from: this);

  @override
  String toString() => r'filesControllerProvider';
}

/// Owns one folder's listing (a family by ltree path — each drilled folder
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
