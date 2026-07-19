// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(journalApi)
final journalApiProvider = JournalApiProvider._();

final class JournalApiProvider
    extends $FunctionalProvider<JournalApi, JournalApi, JournalApi>
    with $Provider<JournalApi> {
  JournalApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalApiHash();

  @$internal
  @override
  $ProviderElement<JournalApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JournalApi create(Ref ref) {
    return journalApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JournalApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JournalApi>(value),
    );
  }
}

String _$journalApiHash() => r'0000000000000000000000000000000000000000';
