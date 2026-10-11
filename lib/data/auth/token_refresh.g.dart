// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_refresh.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tokenRefreshGate)
final tokenRefreshGateProvider = TokenRefreshGateProvider._();

final class TokenRefreshGateProvider
    extends
        $FunctionalProvider<
          TokenRefreshGate,
          TokenRefreshGate,
          TokenRefreshGate
        >
    with $Provider<TokenRefreshGate> {
  TokenRefreshGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tokenRefreshGateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tokenRefreshGateHash();

  @$internal
  @override
  $ProviderElement<TokenRefreshGate> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TokenRefreshGate create(Ref ref) {
    return tokenRefreshGate(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TokenRefreshGate value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TokenRefreshGate>(value),
    );
  }
}

String _$tokenRefreshGateHash() => r'ad4b2febb0c399ef49ab8f852f17529b38811b37';

@ProviderFor(tokenRefresher)
final tokenRefresherProvider = TokenRefresherProvider._();

final class TokenRefresherProvider
    extends $FunctionalProvider<TokenRefresher, TokenRefresher, TokenRefresher>
    with $Provider<TokenRefresher> {
  TokenRefresherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tokenRefresherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tokenRefresherHash();

  @$internal
  @override
  $ProviderElement<TokenRefresher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TokenRefresher create(Ref ref) {
    return tokenRefresher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TokenRefresher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TokenRefresher>(value),
    );
  }
}

String _$tokenRefresherHash() => r'9c09f89b54087985438ea6e4d13ca33b67622a90';

/// Refreshes the login in use's token once it is signed in: at start, after
/// a sign-in and after a switch, and on a return to the foreground when the
/// last refresh is more than [_resumeEvery] old (a phone that keeps the app
/// alive for weeks still rotates in time). Watched once from the app root;
/// nothing reads its value.

@ProviderFor(TokenRefreshSync)
final tokenRefreshSyncProvider = TokenRefreshSyncProvider._();

/// Refreshes the login in use's token once it is signed in: at start, after
/// a sign-in and after a switch, and on a return to the foreground when the
/// last refresh is more than [_resumeEvery] old (a phone that keeps the app
/// alive for weeks still rotates in time). Watched once from the app root;
/// nothing reads its value.
final class TokenRefreshSyncProvider
    extends $NotifierProvider<TokenRefreshSync, void> {
  /// Refreshes the login in use's token once it is signed in: at start, after
  /// a sign-in and after a switch, and on a return to the foreground when the
  /// last refresh is more than [_resumeEvery] old (a phone that keeps the app
  /// alive for weeks still rotates in time). Watched once from the app root;
  /// nothing reads its value.
  TokenRefreshSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tokenRefreshSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tokenRefreshSyncHash();

  @$internal
  @override
  TokenRefreshSync create() => TokenRefreshSync();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$tokenRefreshSyncHash() => r'42246cea43647c8a156393bd42edd9891e984fbf';

/// Refreshes the login in use's token once it is signed in: at start, after
/// a sign-in and after a switch, and on a return to the foreground when the
/// last refresh is more than [_resumeEvery] old (a phone that keeps the app
/// alive for weeks still rotates in time). Watched once from the app root;
/// nothing reads its value.

abstract class _$TokenRefreshSync extends $Notifier<void> {
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
