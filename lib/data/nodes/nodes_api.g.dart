// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nodes_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(nodesApi)
final nodesApiProvider = NodesApiProvider._();

final class NodesApiProvider
    extends $FunctionalProvider<NodesApi, NodesApi, NodesApi>
    with $Provider<NodesApi> {
  NodesApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nodesApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nodesApiHash();

  @$internal
  @override
  $ProviderElement<NodesApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NodesApi create(Ref ref) {
    return nodesApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NodesApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NodesApi>(value),
    );
  }
}

String _$nodesApiHash() => r'eb266e08ab7a43944380da8b4e75e95aad83eebb';

/// `GET /api/draws/{id}/svg` — a drawing's committed SVG snapshot, as the
/// JSON form (`{ svg }`) so the bearer rides the request. Null when the
/// drawing has no snapshot or cannot be fetched; the renderer shows a chip.
/// Kept alive so a page rebuild does not re-fetch every embedded drawing.

@ProviderFor(drawSvg)
final drawSvgProvider = DrawSvgFamily._();

/// `GET /api/draws/{id}/svg` — a drawing's committed SVG snapshot, as the
/// JSON form (`{ svg }`) so the bearer rides the request. Null when the
/// drawing has no snapshot or cannot be fetched; the renderer shows a chip.
/// Kept alive so a page rebuild does not re-fetch every embedded drawing.

final class DrawSvgProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// `GET /api/draws/{id}/svg` — a drawing's committed SVG snapshot, as the
  /// JSON form (`{ svg }`) so the bearer rides the request. Null when the
  /// drawing has no snapshot or cannot be fetched; the renderer shows a chip.
  /// Kept alive so a page rebuild does not re-fetch every embedded drawing.
  DrawSvgProvider._({
    required DrawSvgFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'drawSvgProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$drawSvgHash();

  @override
  String toString() {
    return r'drawSvgProvider'
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
    return drawSvg(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DrawSvgProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$drawSvgHash() => r'eceb207c77d998509cda32c28eb0e20f905d1e8c';

/// `GET /api/draws/{id}/svg` — a drawing's committed SVG snapshot, as the
/// JSON form (`{ svg }`) so the bearer rides the request. Null when the
/// drawing has no snapshot or cannot be fetched; the renderer shows a chip.
/// Kept alive so a page rebuild does not re-fetch every embedded drawing.

final class DrawSvgFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  DrawSvgFamily._()
    : super(
        retry: null,
        name: r'drawSvgProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// `GET /api/draws/{id}/svg` — a drawing's committed SVG snapshot, as the
  /// JSON form (`{ svg }`) so the bearer rides the request. Null when the
  /// drawing has no snapshot or cannot be fetched; the renderer shows a chip.
  /// Kept alive so a page rebuild does not re-fetch every embedded drawing.

  DrawSvgProvider call(String drawId) =>
      DrawSvgProvider._(argument: drawId, from: this);

  @override
  String toString() => r'drawSvgProvider';
}
