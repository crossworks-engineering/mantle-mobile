// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_identity.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A bare client for one brain, used to ask it who a held login is. Not the
/// app's client: that one is the login in use's, and its auth handler signs
/// that login out on a 401. A provider so tests can answer for the brain.
/// It names the phone build too, as every request does.

@ProviderFor(identityDioFactory)
final identityDioFactoryProvider = IdentityDioFactoryProvider._();

/// A bare client for one brain, used to ask it who a held login is. Not the
/// app's client: that one is the login in use's, and its auth handler signs
/// that login out on a 401. A provider so tests can answer for the brain.
/// It names the phone build too, as every request does.

final class IdentityDioFactoryProvider
    extends
        $FunctionalProvider<
          Dio Function(String baseUrl),
          Dio Function(String baseUrl),
          Dio Function(String baseUrl)
        >
    with $Provider<Dio Function(String baseUrl)> {
  /// A bare client for one brain, used to ask it who a held login is. Not the
  /// app's client: that one is the login in use's, and its auth handler signs
  /// that login out on a 401. A provider so tests can answer for the brain.
  /// It names the phone build too, as every request does.
  IdentityDioFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'identityDioFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$identityDioFactoryHash();

  @$internal
  @override
  $ProviderElement<Dio Function(String baseUrl)> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Dio Function(String baseUrl) create(Ref ref) {
    return identityDioFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio Function(String baseUrl) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio Function(String baseUrl)>(value),
    );
  }
}

String _$identityDioFactoryHash() =>
    r'ba6b17ef50d58f33440d42f692e6315c8d08e8b1';

@ProviderFor(sessionIdentity)
final sessionIdentityProvider = SessionIdentityProvider._();

final class SessionIdentityProvider
    extends
        $FunctionalProvider<SessionIdentity, SessionIdentity, SessionIdentity>
    with $Provider<SessionIdentity> {
  SessionIdentityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionIdentityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionIdentityHash();

  @$internal
  @override
  $ProviderElement<SessionIdentity> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionIdentity create(Ref ref) {
    return sessionIdentity(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionIdentity value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionIdentity>(value),
    );
  }
}

String _$sessionIdentityHash() => r'0f377aac2e6f803bf10d5d983110337c6d286177';

/// Learns the login in use's pair once it is signed in (a sign-in, a switch,
/// the first start after the update that added the pair). Watched once from
/// the app root; nothing reads its value.

@ProviderFor(BrainIdentitySync)
final brainIdentitySyncProvider = BrainIdentitySyncProvider._();

/// Learns the login in use's pair once it is signed in (a sign-in, a switch,
/// the first start after the update that added the pair). Watched once from
/// the app root; nothing reads its value.
final class BrainIdentitySyncProvider
    extends $NotifierProvider<BrainIdentitySync, void> {
  /// Learns the login in use's pair once it is signed in (a sign-in, a switch,
  /// the first start after the update that added the pair). Watched once from
  /// the app root; nothing reads its value.
  BrainIdentitySyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brainIdentitySyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brainIdentitySyncHash();

  @$internal
  @override
  BrainIdentitySync create() => BrainIdentitySync();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$brainIdentitySyncHash() => r'f54f080f4b4dce648116bee72b121d3ca72f9d24';

/// Learns the login in use's pair once it is signed in (a sign-in, a switch,
/// the first start after the update that added the pair). Watched once from
/// the app root; nothing reads its value.

abstract class _$BrainIdentitySync extends $Notifier<void> {
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
