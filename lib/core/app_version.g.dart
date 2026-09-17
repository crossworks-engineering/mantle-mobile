// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_version.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// This build's version the way the stores show it: `1.12.0 (20)`. Read once
/// from the bundle; it cannot change while the app runs.

@ProviderFor(appVersion)
final appVersionProvider = AppVersionProvider._();

/// This build's version the way the stores show it: `1.12.0 (20)`. Read once
/// from the bundle; it cannot change while the app runs.

final class AppVersionProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// This build's version the way the stores show it: `1.12.0 (20)`. Read once
  /// from the bundle; it cannot change while the app runs.
  AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return appVersion(ref);
  }
}

String _$appVersionHash() => r'ff1eb5d2af994c051622516f93f238f401bb6abc';
