// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationRouter)
final notificationRouterProvider = NotificationRouterProvider._();

final class NotificationRouterProvider
    extends
        $FunctionalProvider<
          NotificationRouter,
          NotificationRouter,
          NotificationRouter
        >
    with $Provider<NotificationRouter> {
  NotificationRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationRouterHash();

  @$internal
  @override
  $ProviderElement<NotificationRouter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationRouter create(Ref ref) {
    return notificationRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationRouter>(value),
    );
  }
}

String _$notificationRouterHash() =>
    r'73c073966b090af8ce2ddae515a7b7d7be47a390';
