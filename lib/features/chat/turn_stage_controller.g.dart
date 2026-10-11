// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'turn_stage_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams the responder's coarse stage label ("Thinking…", "Searching the
/// web…", …) while a send is in flight on [agentSlug]'s thread, by polling
/// `GET /api/assistant/turn/stage` every ~900ms — mirroring the web's stage
/// indicator. This is the FALLBACK for the legacy blocking path; when live
/// streaming is on the label rides the SSE bus on [ChatState.active] instead, so
/// this poller stands down (yields null) to avoid redundant requests.
///
/// Emits null between mapped steps (the typing bubble then shows dots only) and
/// stops polling the moment the optimistic `sending` message resolves. The state
/// is read from [ChatController], so this provider rebuilds — and tears its poll
/// loop down — as soon as the turn lands. autoDispose: only runs on screen.

@ProviderFor(turnStage)
final turnStageProvider = TurnStageFamily._();

/// Streams the responder's coarse stage label ("Thinking…", "Searching the
/// web…", …) while a send is in flight on [agentSlug]'s thread, by polling
/// `GET /api/assistant/turn/stage` every ~900ms — mirroring the web's stage
/// indicator. This is the FALLBACK for the legacy blocking path; when live
/// streaming is on the label rides the SSE bus on [ChatState.active] instead, so
/// this poller stands down (yields null) to avoid redundant requests.
///
/// Emits null between mapped steps (the typing bubble then shows dots only) and
/// stops polling the moment the optimistic `sending` message resolves. The state
/// is read from [ChatController], so this provider rebuilds — and tears its poll
/// loop down — as soon as the turn lands. autoDispose: only runs on screen.

final class TurnStageProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, Stream<String?>>
    with $FutureModifier<String?>, $StreamProvider<String?> {
  /// Streams the responder's coarse stage label ("Thinking…", "Searching the
  /// web…", …) while a send is in flight on [agentSlug]'s thread, by polling
  /// `GET /api/assistant/turn/stage` every ~900ms — mirroring the web's stage
  /// indicator. This is the FALLBACK for the legacy blocking path; when live
  /// streaming is on the label rides the SSE bus on [ChatState.active] instead, so
  /// this poller stands down (yields null) to avoid redundant requests.
  ///
  /// Emits null between mapped steps (the typing bubble then shows dots only) and
  /// stops polling the moment the optimistic `sending` message resolves. The state
  /// is read from [ChatController], so this provider rebuilds — and tears its poll
  /// loop down — as soon as the turn lands. autoDispose: only runs on screen.
  TurnStageProvider._({
    required TurnStageFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'turnStageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$turnStageHash();

  @override
  String toString() {
    return r'turnStageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String?> create(Ref ref) {
    final argument = this.argument as String;
    return turnStage(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TurnStageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$turnStageHash() => r'6228c6f933705f19ce5ddba17c34e30ba6776e6e';

/// Streams the responder's coarse stage label ("Thinking…", "Searching the
/// web…", …) while a send is in flight on [agentSlug]'s thread, by polling
/// `GET /api/assistant/turn/stage` every ~900ms — mirroring the web's stage
/// indicator. This is the FALLBACK for the legacy blocking path; when live
/// streaming is on the label rides the SSE bus on [ChatState.active] instead, so
/// this poller stands down (yields null) to avoid redundant requests.
///
/// Emits null between mapped steps (the typing bubble then shows dots only) and
/// stops polling the moment the optimistic `sending` message resolves. The state
/// is read from [ChatController], so this provider rebuilds — and tears its poll
/// loop down — as soon as the turn lands. autoDispose: only runs on screen.

final class TurnStageFamily extends $Family
    with $FunctionalFamilyOverride<Stream<String?>, String> {
  TurnStageFamily._()
    : super(
        retry: null,
        name: r'turnStageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Streams the responder's coarse stage label ("Thinking…", "Searching the
  /// web…", …) while a send is in flight on [agentSlug]'s thread, by polling
  /// `GET /api/assistant/turn/stage` every ~900ms — mirroring the web's stage
  /// indicator. This is the FALLBACK for the legacy blocking path; when live
  /// streaming is on the label rides the SSE bus on [ChatState.active] instead, so
  /// this poller stands down (yields null) to avoid redundant requests.
  ///
  /// Emits null between mapped steps (the typing bubble then shows dots only) and
  /// stops polling the moment the optimistic `sending` message resolves. The state
  /// is read from [ChatController], so this provider rebuilds — and tears its poll
  /// loop down — as soon as the turn lands. autoDispose: only runs on screen.

  TurnStageProvider call(String agentSlug) =>
      TurnStageProvider._(argument: agentSlug, from: this);

  @override
  String toString() => r'turnStageProvider';
}
