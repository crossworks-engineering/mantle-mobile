// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_wipe.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionWipe)
final sessionWipeProvider = SessionWipeProvider._();

final class SessionWipeProvider
    extends $FunctionalProvider<SessionWipe, SessionWipe, SessionWipe>
    with $Provider<SessionWipe> {
  SessionWipeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionWipeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionWipeHash();

  @$internal
  @override
  $ProviderElement<SessionWipe> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionWipe create(Ref ref) {
    return sessionWipe(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionWipe value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionWipe>(value),
    );
  }
}

String _$sessionWipeHash() => r'd3f7519e63c00524bb34ff8f20bc2591b6c54698';
