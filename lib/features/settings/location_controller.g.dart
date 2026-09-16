// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the "share location with messages" opt-in. Enabling it first requests
/// the OS *when-in-use* permission and only persists `true` if granted; on
/// refusal the state surfaces a [LocationException] and stays off. Disabling
/// just clears the flag. Mirrors the other settings controllers.

@ProviderFor(LocationController)
final locationControllerProvider = LocationControllerProvider._();

/// Owns the "share location with messages" opt-in. Enabling it first requests
/// the OS *when-in-use* permission and only persists `true` if granted; on
/// refusal the state surfaces a [LocationException] and stays off. Disabling
/// just clears the flag. Mirrors the other settings controllers.
final class LocationControllerProvider
    extends $AsyncNotifierProvider<LocationController, bool> {
  /// Owns the "share location with messages" opt-in. Enabling it first requests
  /// the OS *when-in-use* permission and only persists `true` if granted; on
  /// refusal the state surfaces a [LocationException] and stays off. Disabling
  /// just clears the flag. Mirrors the other settings controllers.
  LocationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationControllerHash();

  @$internal
  @override
  LocationController create() => LocationController();
}

String _$locationControllerHash() =>
    r'35a146423dc58bb18ec8801be73618ee21fd2239';

/// Owns the "share location with messages" opt-in. Enabling it first requests
/// the OS *when-in-use* permission and only persists `true` if granted; on
/// refusal the state surfaces a [LocationException] and stays off. Disabling
/// just clears the flag. Mirrors the other settings controllers.

abstract class _$LocationController extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
