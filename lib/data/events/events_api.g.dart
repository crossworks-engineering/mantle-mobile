// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(eventsApi)
final eventsApiProvider = EventsApiProvider._();

final class EventsApiProvider
    extends $FunctionalProvider<EventsApi, EventsApi, EventsApi>
    with $Provider<EventsApi> {
  EventsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventsApiHash();

  @$internal
  @override
  $ProviderElement<EventsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EventsApi create(Ref ref) {
    return eventsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EventsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EventsApi>(value),
    );
  }
}

String _$eventsApiHash() => r'0000000000000000000000000000000000000000';
