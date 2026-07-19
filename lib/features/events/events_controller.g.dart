// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EventsController)
final eventsControllerProvider = EventsControllerProvider._();

final class EventsControllerProvider
    extends $AsyncNotifierProvider<EventsController, List<EventRow>> {
  EventsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventsControllerHash();

  @$internal
  @override
  EventsController create() => EventsController();
}

String _$eventsControllerHash() => r'0000000000000000000000000000000000000000';

abstract class _$EventsController extends $AsyncNotifier<List<EventRow>> {
  FutureOr<List<EventRow>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<EventRow>>, List<EventRow>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<EventRow>>, List<EventRow>>,
              AsyncValue<List<EventRow>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(EventAlarmSync)
final eventAlarmSyncProvider = EventAlarmSyncProvider._();

final class EventAlarmSyncProvider
    extends $NotifierProvider<EventAlarmSync, void> {
  EventAlarmSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventAlarmSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventAlarmSyncHash();

  @$internal
  @override
  EventAlarmSync create() => EventAlarmSync();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$eventAlarmSyncHash() => r'0000000000000000000000000000000000000000';

abstract class _$EventAlarmSync extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
