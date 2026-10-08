// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'up_next_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads the home screen's "Up next": the upcoming events and the tasks not
/// yet done, read through the brain's own event and task routes, cut by
/// [buildUpNext].
///
/// Fresh when the app comes back to the foreground, and when the events or
/// tasks screens change something ([refreshUpNextIfShown]). A refresh keeps
/// the rows on screen while it runs.

@ProviderFor(UpNextController)
final upNextControllerProvider = UpNextControllerProvider._();

/// Loads the home screen's "Up next": the upcoming events and the tasks not
/// yet done, read through the brain's own event and task routes, cut by
/// [buildUpNext].
///
/// Fresh when the app comes back to the foreground, and when the events or
/// tasks screens change something ([refreshUpNextIfShown]). A refresh keeps
/// the rows on screen while it runs.
final class UpNextControllerProvider
    extends $AsyncNotifierProvider<UpNextController, UpNext> {
  /// Loads the home screen's "Up next": the upcoming events and the tasks not
  /// yet done, read through the brain's own event and task routes, cut by
  /// [buildUpNext].
  ///
  /// Fresh when the app comes back to the foreground, and when the events or
  /// tasks screens change something ([refreshUpNextIfShown]). A refresh keeps
  /// the rows on screen while it runs.
  UpNextControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'upNextControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$upNextControllerHash();

  @$internal
  @override
  UpNextController create() => UpNextController();
}

String _$upNextControllerHash() => r'4174df09b764ffefcf8bbc544b0bb3bfd571af32';

/// Loads the home screen's "Up next": the upcoming events and the tasks not
/// yet done, read through the brain's own event and task routes, cut by
/// [buildUpNext].
///
/// Fresh when the app comes back to the foreground, and when the events or
/// tasks screens change something ([refreshUpNextIfShown]). A refresh keeps
/// the rows on screen while it runs.

abstract class _$UpNextController extends $AsyncNotifier<UpNext> {
  FutureOr<UpNext> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UpNext>, UpNext>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UpNext>, UpNext>,
              AsyncValue<UpNext>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
