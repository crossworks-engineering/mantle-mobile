// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app router. A single [SessionController]-driven `redirect` is the whole
/// auth gate: while the session loads we show a splash; then we route to setup,
/// login, or home. `refreshListenable` re-runs the redirect whenever the
/// session changes (set server / sign in / sign out / token cleared on 401).

@ProviderFor(goRouter)
final goRouterProvider = GoRouterProvider._();

/// The app router. A single [SessionController]-driven `redirect` is the whole
/// auth gate: while the session loads we show a splash; then we route to setup,
/// login, or home. `refreshListenable` re-runs the redirect whenever the
/// session changes (set server / sign in / sign out / token cleared on 401).

final class GoRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// The app router. A single [SessionController]-driven `redirect` is the whole
  /// auth gate: while the session loads we show a splash; then we route to setup,
  /// login, or home. `refreshListenable` re-runs the redirect whenever the
  /// session changes (set server / sign in / sign out / token cleared on 401).
  GoRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'goRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$goRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return goRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$goRouterHash() => r'94e1ce865794aaed4580a30c83fcd891709cd3bf';
