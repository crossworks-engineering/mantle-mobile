// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_access_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Who the login in use is, and what the phone offers it ([LoginAccess]).
///
/// Cache first: the answer stored for this login (at sign-in, or the last
/// start) is the state at once, so a member never sees an Admin user's screen
/// while whoami is on its way; whoami then refreshes it. With nothing cached
/// (the first start after the update from a build that served Admin users
/// only) it waits for whoami, and falls back to the Admin user's surface when
/// whoami cannot be reached: every login on such a phone was one.
///
/// Rebuilt whenever the login in use changes. Never fails.

@ProviderFor(LoginAccessController)
final loginAccessControllerProvider = LoginAccessControllerProvider._();

/// Who the login in use is, and what the phone offers it ([LoginAccess]).
///
/// Cache first: the answer stored for this login (at sign-in, or the last
/// start) is the state at once, so a member never sees an Admin user's screen
/// while whoami is on its way; whoami then refreshes it. With nothing cached
/// (the first start after the update from a build that served Admin users
/// only) it waits for whoami, and falls back to the Admin user's surface when
/// whoami cannot be reached: every login on such a phone was one.
///
/// Rebuilt whenever the login in use changes. Never fails.
final class LoginAccessControllerProvider
    extends $AsyncNotifierProvider<LoginAccessController, LoginAccess> {
  /// Who the login in use is, and what the phone offers it ([LoginAccess]).
  ///
  /// Cache first: the answer stored for this login (at sign-in, or the last
  /// start) is the state at once, so a member never sees an Admin user's screen
  /// while whoami is on its way; whoami then refreshes it. With nothing cached
  /// (the first start after the update from a build that served Admin users
  /// only) it waits for whoami, and falls back to the Admin user's surface when
  /// whoami cannot be reached: every login on such a phone was one.
  ///
  /// Rebuilt whenever the login in use changes. Never fails.
  LoginAccessControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loginAccessControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loginAccessControllerHash();

  @$internal
  @override
  LoginAccessController create() => LoginAccessController();
}

String _$loginAccessControllerHash() =>
    r'a0d731c79f123b56b32a672ef1774f0930bc079a';

/// Who the login in use is, and what the phone offers it ([LoginAccess]).
///
/// Cache first: the answer stored for this login (at sign-in, or the last
/// start) is the state at once, so a member never sees an Admin user's screen
/// while whoami is on its way; whoami then refreshes it. With nothing cached
/// (the first start after the update from a build that served Admin users
/// only) it waits for whoami, and falls back to the Admin user's surface when
/// whoami cannot be reached: every login on such a phone was one.
///
/// Rebuilt whenever the login in use changes. Never fails.

abstract class _$LoginAccessController extends $AsyncNotifier<LoginAccess> {
  FutureOr<LoginAccess> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<LoginAccess>, LoginAccess>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<LoginAccess>, LoginAccess>,
              AsyncValue<LoginAccess>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The login in use's access as it stands: null while it is being worked
/// out (at start, and for the moment after a sign-in or a switch, when the
/// last answer is another login's). A screen then offers only what every
/// login has.

@ProviderFor(currentAccess)
final currentAccessProvider = CurrentAccessProvider._();

/// The login in use's access as it stands: null while it is being worked
/// out (at start, and for the moment after a sign-in or a switch, when the
/// last answer is another login's). A screen then offers only what every
/// login has.

final class CurrentAccessProvider
    extends $FunctionalProvider<LoginAccess?, LoginAccess?, LoginAccess?>
    with $Provider<LoginAccess?> {
  /// The login in use's access as it stands: null while it is being worked
  /// out (at start, and for the moment after a sign-in or a switch, when the
  /// last answer is another login's). A screen then offers only what every
  /// login has.
  CurrentAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAccessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAccessHash();

  @$internal
  @override
  $ProviderElement<LoginAccess?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LoginAccess? create(Ref ref) {
    return currentAccess(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoginAccess? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoginAccess?>(value),
    );
  }
}

String _$currentAccessHash() => r'eca3bdbf13d0fc97710a65ac904773521ff749a4';
