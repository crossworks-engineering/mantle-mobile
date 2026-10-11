// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(agentApi)
final agentApiProvider = AgentApiProvider._();

final class AgentApiProvider
    extends $FunctionalProvider<AgentApi, AgentApi, AgentApi>
    with $Provider<AgentApi> {
  AgentApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentApiHash();

  @$internal
  @override
  $ProviderElement<AgentApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AgentApi create(Ref ref) {
    return agentApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentApi>(value),
    );
  }
}

String _$agentApiHash() => r'61e38eb3ecccb74ffc354b1df5b0f76a55bbba29';

/// The agent's generated avatar as an SVG string (`GET /api/agents/{slug}/avatar`),
/// or `null` if the agent has none (404) or the fetch fails — the UI then shows
/// the initials fallback. Kept alive so avatars aren't re-fetched on rebuild.

@ProviderFor(agentAvatarSvg)
final agentAvatarSvgProvider = AgentAvatarSvgFamily._();

/// The agent's generated avatar as an SVG string (`GET /api/agents/{slug}/avatar`),
/// or `null` if the agent has none (404) or the fetch fails — the UI then shows
/// the initials fallback. Kept alive so avatars aren't re-fetched on rebuild.

final class AgentAvatarSvgProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The agent's generated avatar as an SVG string (`GET /api/agents/{slug}/avatar`),
  /// or `null` if the agent has none (404) or the fetch fails — the UI then shows
  /// the initials fallback. Kept alive so avatars aren't re-fetched on rebuild.
  AgentAvatarSvgProvider._({
    required AgentAvatarSvgFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'agentAvatarSvgProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$agentAvatarSvgHash();

  @override
  String toString() {
    return r'agentAvatarSvgProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return agentAvatarSvg(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AgentAvatarSvgProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentAvatarSvgHash() => r'd4aa47fe02cc831be095ae6c99d64015b24106ad';

/// The agent's generated avatar as an SVG string (`GET /api/agents/{slug}/avatar`),
/// or `null` if the agent has none (404) or the fetch fails — the UI then shows
/// the initials fallback. Kept alive so avatars aren't re-fetched on rebuild.

final class AgentAvatarSvgFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  AgentAvatarSvgFamily._()
    : super(
        retry: null,
        name: r'agentAvatarSvgProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The agent's generated avatar as an SVG string (`GET /api/agents/{slug}/avatar`),
  /// or `null` if the agent has none (404) or the fetch fails — the UI then shows
  /// the initials fallback. Kept alive so avatars aren't re-fetched on rebuild.

  AgentAvatarSvgProvider call(String slug) =>
      AgentAvatarSvgProvider._(argument: slug, from: this);

  @override
  String toString() => r'agentAvatarSvgProvider';
}
