// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(JournalController)
final journalControllerProvider = JournalControllerProvider._();

final class JournalControllerProvider
    extends $AsyncNotifierProvider<JournalController, List<JournalRow>> {
  JournalControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalControllerHash();

  @$internal
  @override
  JournalController create() => JournalController();
}

String _$journalControllerHash() => r'0000000000000000000000000000000000000000';

abstract class _$JournalController extends $AsyncNotifier<List<JournalRow>> {
  FutureOr<List<JournalRow>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<JournalRow>>, List<JournalRow>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<JournalRow>>, List<JournalRow>>,
              AsyncValue<List<JournalRow>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
