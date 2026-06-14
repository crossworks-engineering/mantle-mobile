// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lifecycle.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Current app lifecycle state, fed by the root widget's `WidgetsBindingObserver`
/// (see `main.dart`). Providers that hold a live connection — the chat SSE
/// stream — watch this so they pause while the app is backgrounded and
/// reconnect on resume, instead of leaving a dead socket open.

@ProviderFor(AppLifecycle)
final appLifecycleProvider = AppLifecycleProvider._();

/// Current app lifecycle state, fed by the root widget's `WidgetsBindingObserver`
/// (see `main.dart`). Providers that hold a live connection — the chat SSE
/// stream — watch this so they pause while the app is backgrounded and
/// reconnect on resume, instead of leaving a dead socket open.
final class AppLifecycleProvider
    extends $NotifierProvider<AppLifecycle, AppLifecycleState> {
  /// Current app lifecycle state, fed by the root widget's `WidgetsBindingObserver`
  /// (see `main.dart`). Providers that hold a live connection — the chat SSE
  /// stream — watch this so they pause while the app is backgrounded and
  /// reconnect on resume, instead of leaving a dead socket open.
  AppLifecycleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLifecycleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLifecycleHash();

  @$internal
  @override
  AppLifecycle create() => AppLifecycle();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLifecycleState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLifecycleState>(value),
    );
  }
}

String _$appLifecycleHash() => r'f0e8421a6dcfaa2507ea3467e1e84acd675ca719';

/// Current app lifecycle state, fed by the root widget's `WidgetsBindingObserver`
/// (see `main.dart`). Providers that hold a live connection — the chat SSE
/// stream — watch this so they pause while the app is backgrounded and
/// reconnect on resume, instead of leaving a dead socket open.

abstract class _$AppLifecycle extends $Notifier<AppLifecycleState> {
  AppLifecycleState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppLifecycleState, AppLifecycleState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppLifecycleState, AppLifecycleState>,
              AppLifecycleState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
