// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'direct_push_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The direct-connection push transport (no-Google Android). State is whether
/// the foreground service is running; [enable]/[disable] start/stop it and
/// record the choice ([AppDatabase.directPushWantedKey]), which
/// [DirectPushFollow] keeps true across switches and restarts. Android only:
/// the UI hides it elsewhere.

@ProviderFor(DirectPushController)
final directPushControllerProvider = DirectPushControllerProvider._();

/// The direct-connection push transport (no-Google Android). State is whether
/// the foreground service is running; [enable]/[disable] start/stop it and
/// record the choice ([AppDatabase.directPushWantedKey]), which
/// [DirectPushFollow] keeps true across switches and restarts. Android only:
/// the UI hides it elsewhere.
final class DirectPushControllerProvider
    extends $AsyncNotifierProvider<DirectPushController, bool> {
  /// The direct-connection push transport (no-Google Android). State is whether
  /// the foreground service is running; [enable]/[disable] start/stop it and
  /// record the choice ([AppDatabase.directPushWantedKey]), which
  /// [DirectPushFollow] keeps true across switches and restarts. Android only:
  /// the UI hides it elsewhere.
  DirectPushControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directPushControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directPushControllerHash();

  @$internal
  @override
  DirectPushController create() => DirectPushController();
}

String _$directPushControllerHash() =>
    r'fe2e4a90a5001c7a7361a32fc20e286e51e4e845';

/// The direct-connection push transport (no-Google Android). State is whether
/// the foreground service is running; [enable]/[disable] start/stop it and
/// record the choice ([AppDatabase.directPushWantedKey]), which
/// [DirectPushFollow] keeps true across switches and restarts. Android only:
/// the UI hides it elsewhere.

abstract class _$DirectPushController extends $AsyncNotifier<bool> {
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

/// Keeps the direct connection on the login in use while the person wants
/// it on. A switch or a sign-out stops the service (the session wipe); this
/// starts it again for whoever is active next, at launch and whenever the
/// client changes (another login, or another brain).
///
/// It also carries the choice over from a build before several logins: that
/// build started the service without a login id, so the service stops itself
/// at its next start. Its leftover address means the person had it on.
///
/// keepAlive + watched once from the app root, like the alarm sync. Nothing
/// reads its (void) value.

@ProviderFor(DirectPushFollow)
final directPushFollowProvider = DirectPushFollowProvider._();

/// Keeps the direct connection on the login in use while the person wants
/// it on. A switch or a sign-out stops the service (the session wipe); this
/// starts it again for whoever is active next, at launch and whenever the
/// client changes (another login, or another brain).
///
/// It also carries the choice over from a build before several logins: that
/// build started the service without a login id, so the service stops itself
/// at its next start. Its leftover address means the person had it on.
///
/// keepAlive + watched once from the app root, like the alarm sync. Nothing
/// reads its (void) value.
final class DirectPushFollowProvider
    extends $NotifierProvider<DirectPushFollow, void> {
  /// Keeps the direct connection on the login in use while the person wants
  /// it on. A switch or a sign-out stops the service (the session wipe); this
  /// starts it again for whoever is active next, at launch and whenever the
  /// client changes (another login, or another brain).
  ///
  /// It also carries the choice over from a build before several logins: that
  /// build started the service without a login id, so the service stops itself
  /// at its next start. Its leftover address means the person had it on.
  ///
  /// keepAlive + watched once from the app root, like the alarm sync. Nothing
  /// reads its (void) value.
  DirectPushFollowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directPushFollowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directPushFollowHash();

  @$internal
  @override
  DirectPushFollow create() => DirectPushFollow();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$directPushFollowHash() => r'af7dbd3380ce6d2078039abd25c7aecb0c23eba0';

/// Keeps the direct connection on the login in use while the person wants
/// it on. A switch or a sign-out stops the service (the session wipe); this
/// starts it again for whoever is active next, at launch and whenever the
/// client changes (another login, or another brain).
///
/// It also carries the choice over from a build before several logins: that
/// build started the service without a login id, so the service stops itself
/// at its next start. Its leftover address means the person had it on.
///
/// keepAlive + watched once from the app root, like the alarm sync. Nothing
/// reads its (void) value.

abstract class _$DirectPushFollow extends $Notifier<void> {
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
