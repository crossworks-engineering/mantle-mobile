// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Single source of truth for "where should the app be?". Derived from the
/// persisted server URL + the presence of a bearer token; the router redirects
/// on it. Mutations (set server, sign in/out) update it and the router follows.

@ProviderFor(SessionController)
final sessionControllerProvider = SessionControllerProvider._();

/// Single source of truth for "where should the app be?". Derived from the
/// persisted server URL + the presence of a bearer token; the router redirects
/// on it. Mutations (set server, sign in/out) update it and the router follows.
final class SessionControllerProvider
    extends $AsyncNotifierProvider<SessionController, AuthStatus> {
  /// Single source of truth for "where should the app be?". Derived from the
  /// persisted server URL + the presence of a bearer token; the router redirects
  /// on it. Mutations (set server, sign in/out) update it and the router follows.
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

String _$sessionControllerHash() => r'89426b241ec5504e1121066645de28c634a0cea1';

/// Single source of truth for "where should the app be?". Derived from the
/// persisted server URL + the presence of a bearer token; the router redirects
/// on it. Mutations (set server, sign in/out) update it and the router follows.

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
