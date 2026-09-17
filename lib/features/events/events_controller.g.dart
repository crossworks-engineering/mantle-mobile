// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the upcoming-events list. Every successful load or mutation also
/// re-syncs the device's LOCAL alarms ([EventAlarms.sync]) so what's on the
/// screen and what will ring are never out of step.
///
/// "Done" is the [kEventDoneTag] tag (the server has no event status field):
/// marking done persists the tag via PATCH, keeps the row's history, and
/// cancels its alarms on the next sync.

@ProviderFor(EventsController)
final eventsControllerProvider = EventsControllerProvider._();

/// Owns the upcoming-events list. Every successful load or mutation also
/// re-syncs the device's LOCAL alarms ([EventAlarms.sync]) so what's on the
/// screen and what will ring are never out of step.
///
/// "Done" is the [kEventDoneTag] tag (the server has no event status field):
/// marking done persists the tag via PATCH, keeps the row's history, and
/// cancels its alarms on the next sync.
final class EventsControllerProvider
    extends $AsyncNotifierProvider<EventsController, List<EventRow>> {
  /// Owns the upcoming-events list. Every successful load or mutation also
  /// re-syncs the device's LOCAL alarms ([EventAlarms.sync]) so what's on the
  /// screen and what will ring are never out of step.
  ///
  /// "Done" is the [kEventDoneTag] tag (the server has no event status field):
  /// marking done persists the tag via PATCH, keeps the row's history, and
  /// cancels its alarms on the next sync.
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

String _$eventsControllerHash() => r'728a33403bc759dee63e85a58e5b0ce549435842';

/// Owns the upcoming-events list. Every successful load or mutation also
/// re-syncs the device's LOCAL alarms ([EventAlarms.sync]) so what's on the
/// screen and what will ring are never out of step.
///
/// "Done" is the [kEventDoneTag] tag (the server has no event status field):
/// marking done persists the tag via PATCH, keeps the row's history, and
/// cancels its alarms on the next sync.

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

/// Keeps device alarms fresh WITHOUT the events screen ever being opened:
/// on login and on every foreground resume it pulls the upcoming window and
/// reconciles the local schedule (an event added from the web or by the
/// assistant still rings on the phone). keepAlive + watched once from the app
/// root, like the theme scheduler — nothing reads its (void) value.

@ProviderFor(EventAlarmSync)
final eventAlarmSyncProvider = EventAlarmSyncProvider._();

/// Keeps device alarms fresh WITHOUT the events screen ever being opened:
/// on login and on every foreground resume it pulls the upcoming window and
/// reconciles the local schedule (an event added from the web or by the
/// assistant still rings on the phone). keepAlive + watched once from the app
/// root, like the theme scheduler — nothing reads its (void) value.
final class EventAlarmSyncProvider
    extends $NotifierProvider<EventAlarmSync, void> {
  /// Keeps device alarms fresh WITHOUT the events screen ever being opened:
  /// on login and on every foreground resume it pulls the upcoming window and
  /// reconciles the local schedule (an event added from the web or by the
  /// assistant still rings on the phone). keepAlive + watched once from the app
  /// root, like the theme scheduler — nothing reads its (void) value.
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

String _$eventAlarmSyncHash() => r'e628d504335a0140e66989f15cdf7cb1d2e33601';

/// Keeps device alarms fresh WITHOUT the events screen ever being opened:
/// on login and on every foreground resume it pulls the upcoming window and
/// reconciles the local schedule (an event added from the web or by the
/// assistant still rings on the phone). keepAlive + watched once from the app
/// root, like the theme scheduler — nothing reads its (void) value.

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
