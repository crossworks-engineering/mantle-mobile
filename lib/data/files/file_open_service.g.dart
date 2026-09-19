// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_open_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fileOpenService)
final fileOpenServiceProvider = FileOpenServiceProvider._();

final class FileOpenServiceProvider
    extends
        $FunctionalProvider<FileOpenService, FileOpenService, FileOpenService>
    with $Provider<FileOpenService> {
  FileOpenServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileOpenServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileOpenServiceHash();

  @$internal
  @override
  $ProviderElement<FileOpenService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileOpenService create(Ref ref) {
    return fileOpenService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileOpenService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileOpenService>(value),
    );
  }
}

String _$fileOpenServiceHash() => r'61155bcd2233b5ddfb9a3b0b8ec12307cb4d2a1b';
