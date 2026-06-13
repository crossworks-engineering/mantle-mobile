// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-wide singleton [AppDatabase]. Kept alive for the whole session and
/// closed on dispose. Tests override this with an in-memory database via
/// `appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(...))`.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// App-wide singleton [AppDatabase]. Kept alive for the whole session and
/// closed on dispose. Tests override this with an in-memory database via
/// `appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(...))`.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// App-wide singleton [AppDatabase]. Kept alive for the whole session and
  /// closed on dispose. Tests override this with an in-memory database via
  /// `appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(...))`.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';
