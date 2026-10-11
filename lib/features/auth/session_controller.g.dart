// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Single source of truth for "where should the app be?". Derived from the
/// persisted server URL + the presence of a bearer token; the router redirects
/// on it. Mutations (set server, sign in/out, switch) update it and the router
/// follows.
///
/// The device can hold SEVERAL logins ([SessionRepository]); this controller
/// is about the ACTIVE one. The server address and the bearer it reads are
/// the active session's, so the three states mean what they always meant.
///
/// Adding a login does not run alongside the one in use. It steps OUT of it
/// first (nobody active, so no bearer is attached to anything) and then walks
/// the same setup → login screens a first sign-in does. That is deliberate:
/// the Dio client is built from the active server address, and pointing it at
/// a second brain while the first login's bearer was still being attached
/// would send one brain's credential to another.

@ProviderFor(SessionController)
final sessionControllerProvider = SessionControllerProvider._();

/// Single source of truth for "where should the app be?". Derived from the
/// persisted server URL + the presence of a bearer token; the router redirects
/// on it. Mutations (set server, sign in/out, switch) update it and the router
/// follows.
///
/// The device can hold SEVERAL logins ([SessionRepository]); this controller
/// is about the ACTIVE one. The server address and the bearer it reads are
/// the active session's, so the three states mean what they always meant.
///
/// Adding a login does not run alongside the one in use. It steps OUT of it
/// first (nobody active, so no bearer is attached to anything) and then walks
/// the same setup → login screens a first sign-in does. That is deliberate:
/// the Dio client is built from the active server address, and pointing it at
/// a second brain while the first login's bearer was still being attached
/// would send one brain's credential to another.
final class SessionControllerProvider
    extends $AsyncNotifierProvider<SessionController, AuthStatus> {
  /// Single source of truth for "where should the app be?". Derived from the
  /// persisted server URL + the presence of a bearer token; the router redirects
  /// on it. Mutations (set server, sign in/out, switch) update it and the router
  /// follows.
  ///
  /// The device can hold SEVERAL logins ([SessionRepository]); this controller
  /// is about the ACTIVE one. The server address and the bearer it reads are
  /// the active session's, so the three states mean what they always meant.
  ///
  /// Adding a login does not run alongside the one in use. It steps OUT of it
  /// first (nobody active, so no bearer is attached to anything) and then walks
  /// the same setup → login screens a first sign-in does. That is deliberate:
  /// the Dio client is built from the active server address, and pointing it at
  /// a second brain while the first login's bearer was still being attached
  /// would send one brain's credential to another.
  SessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionControllerHash();

  @$internal
  @override
  SessionController create() => SessionController();
}

String _$sessionControllerHash() => r'41daa638efe6c7ff0742d5340686704ed6d504f6';

/// Single source of truth for "where should the app be?". Derived from the
/// persisted server URL + the presence of a bearer token; the router redirects
/// on it. Mutations (set server, sign in/out, switch) update it and the router
/// follows.
///
/// The device can hold SEVERAL logins ([SessionRepository]); this controller
/// is about the ACTIVE one. The server address and the bearer it reads are
/// the active session's, so the three states mean what they always meant.
///
/// Adding a login does not run alongside the one in use. It steps OUT of it
/// first (nobody active, so no bearer is attached to anything) and then walks
/// the same setup → login screens a first sign-in does. That is deliberate:
/// the Dio client is built from the active server address, and pointing it at
/// a second brain while the first login's bearer was still being attached
/// would send one brain's credential to another.

abstract class _$SessionController extends $AsyncNotifier<AuthStatus> {
  FutureOr<AuthStatus> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AuthStatus>, AuthStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AuthStatus>, AuthStatus>,
              AsyncValue<AuthStatus>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Bumped whenever the login in use changes (sign-in, sign-out, switch, a
/// refused bearer). Watched by the Dio client, and through it by everything
/// that holds data fetched as a particular login.

@ProviderFor(SessionEpoch)
final sessionEpochProvider = SessionEpochProvider._();

/// Bumped whenever the login in use changes (sign-in, sign-out, switch, a
/// refused bearer). Watched by the Dio client, and through it by everything
/// that holds data fetched as a particular login.
final class SessionEpochProvider extends $NotifierProvider<SessionEpoch, int> {
  /// Bumped whenever the login in use changes (sign-in, sign-out, switch, a
  /// refused bearer). Watched by the Dio client, and through it by everything
  /// that holds data fetched as a particular login.
  SessionEpochProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionEpochProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionEpochHash();

  @$internal
  @override
  SessionEpoch create() => SessionEpoch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$sessionEpochHash() => r'0c3db6ed6998d232ba29c8489eb32d468e8fb136';

/// Bumped whenever the login in use changes (sign-in, sign-out, switch, a
/// refused bearer). Watched by the Dio client, and through it by everything
/// that holds data fetched as a particular login.

abstract class _$SessionEpoch extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The signed-in email for display, null when signed out. Invalidated by the
/// session controller whenever the account changes.

@ProviderFor(accountEmail)
final accountEmailProvider = AccountEmailProvider._();

/// The signed-in email for display, null when signed out. Invalidated by the
/// session controller whenever the account changes.

final class AccountEmailProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The signed-in email for display, null when signed out. Invalidated by the
  /// session controller whenever the account changes.
  AccountEmailProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountEmailProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountEmailHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return accountEmail(ref);
  }
}

String _$accountEmailHash() => r'e3e8502e2266703d90d5077510b57c899c8c4c35';

/// Every login held on this device, the one in use first, then most recently
/// used. Invalidated by the session controller on every change.

@ProviderFor(heldSessions)
final heldSessionsProvider = HeldSessionsProvider._();

/// Every login held on this device, the one in use first, then most recently
/// used. Invalidated by the session controller on every change.

final class HeldSessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HeldSession>>,
          List<HeldSession>,
          FutureOr<List<HeldSession>>
        >
    with
        $FutureModifier<List<HeldSession>>,
        $FutureProvider<List<HeldSession>> {
  /// Every login held on this device, the one in use first, then most recently
  /// used. Invalidated by the session controller on every change.
  HeldSessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'heldSessionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$heldSessionsHash();

  @$internal
  @override
  $FutureProviderElement<List<HeldSession>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<HeldSession>> create(Ref ref) {
    return heldSessions(ref);
  }
}

String _$heldSessionsHash() => r'a08fd739dac50222daeebc1c51c014dbc055bfb4';

/// The email the login screen should start with: set when the person is sent
/// there to sign BACK in to a login the device still lists, read once.

@ProviderFor(PendingLoginEmail)
final pendingLoginEmailProvider = PendingLoginEmailProvider._();

/// The email the login screen should start with: set when the person is sent
/// there to sign BACK in to a login the device still lists, read once.
final class PendingLoginEmailProvider
    extends $NotifierProvider<PendingLoginEmail, String?> {
  /// The email the login screen should start with: set when the person is sent
  /// there to sign BACK in to a login the device still lists, read once.
  PendingLoginEmailProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingLoginEmailProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingLoginEmailHash();

  @$internal
  @override
  PendingLoginEmail create() => PendingLoginEmail();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$pendingLoginEmailHash() => r'6a1e34e90f9d85e9156d91c1bf0c144796656c31';

/// The email the login screen should start with: set when the person is sent
/// there to sign BACK in to a login the device still lists, read once.

abstract class _$PendingLoginEmail extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
