// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notesApi)
final notesApiProvider = NotesApiProvider._();

final class NotesApiProvider
    extends $FunctionalProvider<NotesApi, NotesApi, NotesApi>
    with $Provider<NotesApi> {
  NotesApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notesApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notesApiHash();

  @$internal
  @override
  $ProviderElement<NotesApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NotesApi create(Ref ref) {
    return notesApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotesApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotesApi>(value),
    );
  }
}

String _$notesApiHash() => r'04549ade0dca268a79554bb26017c5b19518cd96';
