// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_capture.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Makes a recorder per [VoiceCapture]. Tests override it with a fake.

@ProviderFor(voiceRecorderFactory)
final voiceRecorderFactoryProvider = VoiceRecorderFactoryProvider._();

/// Makes a recorder per [VoiceCapture]. Tests override it with a fake.

final class VoiceRecorderFactoryProvider
    extends
        $FunctionalProvider<
          VoiceRecorderFactory,
          VoiceRecorderFactory,
          VoiceRecorderFactory
        >
    with $Provider<VoiceRecorderFactory> {
  /// Makes a recorder per [VoiceCapture]. Tests override it with a fake.
  VoiceRecorderFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceRecorderFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceRecorderFactoryHash();

  @$internal
  @override
  $ProviderElement<VoiceRecorderFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VoiceRecorderFactory create(Ref ref) {
    return voiceRecorderFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoiceRecorderFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoiceRecorderFactory>(value),
    );
  }
}

String _$voiceRecorderFactoryHash() =>
    r'03a7e0ccbd562b340d6efb8400bcde337ee3049c';

/// The app's one speech-to-text path: `POST /api/assistant/transcribe`
/// through the brain's default STT worker (the same pipeline as Telegram
/// voice notes). Read at transcribe time, never at build, so a screen that
/// only shows a mic does not build the chat repository.

@ProviderFor(voiceTranscriber)
final voiceTranscriberProvider = VoiceTranscriberProvider._();

/// The app's one speech-to-text path: `POST /api/assistant/transcribe`
/// through the brain's default STT worker (the same pipeline as Telegram
/// voice notes). Read at transcribe time, never at build, so a screen that
/// only shows a mic does not build the chat repository.

final class VoiceTranscriberProvider
    extends
        $FunctionalProvider<
          VoiceTranscriber,
          VoiceTranscriber,
          VoiceTranscriber
        >
    with $Provider<VoiceTranscriber> {
  /// The app's one speech-to-text path: `POST /api/assistant/transcribe`
  /// through the brain's default STT worker (the same pipeline as Telegram
  /// voice notes). Read at transcribe time, never at build, so a screen that
  /// only shows a mic does not build the chat repository.
  VoiceTranscriberProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceTranscriberProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceTranscriberHash();

  @$internal
  @override
  $ProviderElement<VoiceTranscriber> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VoiceTranscriber create(Ref ref) {
    return voiceTranscriber(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoiceTranscriber value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoiceTranscriber>(value),
    );
  }
}

String _$voiceTranscriberHash() => r'158f53dcc1007d6d2fff80bb1b0f42e92877368d';

/// Whether the brain can transcribe at all. Flips to false for the rest of
/// the session on the first 412 ("no default STT worker configured"); every
/// mic watches it and hides, so a brain without a worker says so once
/// instead of failing on every hold.

@ProviderFor(SttAvailability)
final sttAvailabilityProvider = SttAvailabilityProvider._();

/// Whether the brain can transcribe at all. Flips to false for the rest of
/// the session on the first 412 ("no default STT worker configured"); every
/// mic watches it and hides, so a brain without a worker says so once
/// instead of failing on every hold.
final class SttAvailabilityProvider
    extends $NotifierProvider<SttAvailability, bool> {
  /// Whether the brain can transcribe at all. Flips to false for the rest of
  /// the session on the first 412 ("no default STT worker configured"); every
  /// mic watches it and hides, so a brain without a worker says so once
  /// instead of failing on every hold.
  SttAvailabilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sttAvailabilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sttAvailabilityHash();

  @$internal
  @override
  SttAvailability create() => SttAvailability();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$sttAvailabilityHash() => r'e3e49fce82aa0283296f4a510ac60794befa7bc2';

/// Whether the brain can transcribe at all. Flips to false for the rest of
/// the session on the first 412 ("no default STT worker configured"); every
/// mic watches it and hides, so a brain without a worker says so once
/// instead of failing on every hold.

abstract class _$SttAvailability extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
