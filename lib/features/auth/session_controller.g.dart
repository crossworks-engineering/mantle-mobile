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

String _$sessionControllerHash() => r'4b6846e02d0ee7503eb5cea04e2e36d312f8d3eb';

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
