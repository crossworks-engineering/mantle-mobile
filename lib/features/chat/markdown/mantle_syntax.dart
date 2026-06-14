// Custom `markdown` syntaxes that mirror Mantle's GFM-superset dialect:
//   - Container fences: `:::info|success|warning|danger`, `:::aside [chart-N]`,
//     `:::columns … +++ … :::`  (block-level)
//   - Inline highlight: `==text==`
//   - Inline colour span: `[text]{color=chart-N}` / `{highlight=chart-N}`
//
// Block fences capture their inner content as RAW markdown (stored in the `md`
// attribute) so the renderer can recurse with a nested MantleMarkdown — that
// keeps full markdown working inside containers without re-implementing the
// block walker. Rendering lives in mantle_markdown.dart; this file is parser-only
// (no Flutter deps). See docs/architecture.md "Rendering assistant replies".

import 'package:markdown/markdown.dart' as md;

/// Element tags emitted by these syntaxes; the renderer registers a builder per
/// tag (see mantle_markdown.dart).
const String kCalloutTag = 'mantleCallout';
const String kAsideTag = 'mantleAside';
const String kColumnsTag = 'mantleColumns';
const String kColumnTag = 'mantleColumn';
const String kSpanTag = 'mantleSpan';

const Set<String> _calloutVariants = {'info', 'success', 'warning', 'danger'};

/// `:::kind [arg]` … `:::` containers. One syntax handles all three kinds; an
/// unknown variant defaults to `info`, an unknown/missing aside colour to
/// `chart-1`, matching Mantle's parser.
class MantleFenceSyntax extends md.BlockSyntax {
  const MantleFenceSyntax();

  // Any `:::word` opens a container (matching Mantle): `aside`/`columns` are
  // special, every other kind is a callout whose variant defaults to `info`.
  static final RegExp _open = RegExp(
    r'^:::([A-Za-z]+)(?:\s+([A-Za-z0-9-]+))?\s*$',
    caseSensitive: false,
  );
  static final RegExp _close = RegExp(r'^:::\s*$');
  static final RegExp _columnSep = RegExp(r'^\+\+\+\s*$');

  @override
  RegExp get pattern => _open;

  @override
  md.Node parse(md.BlockParser parser) {
    final open = _open.firstMatch(parser.current.content)!;
    final kind = open.group(1)!.toLowerCase();
    final arg = open.group(2)?.toLowerCase();
    parser.advance(); // consume the opening fence

    final body = <String>[];
    while (!parser.isDone) {
      final line = parser.current.content;
      if (_close.hasMatch(line)) {
        parser.advance(); // consume the closing fence
        break;
      }
      body.add(line);
      parser.advance();
    }

    switch (kind) {
      case 'columns':
        return _columns(body);
      case 'aside':
        return _aside(body, arg);
      default:
        return _callout(kind, body);
    }
  }

  md.Element _callout(String variant, List<String> body) {
    final v = _calloutVariants.contains(variant) ? variant : 'info';
    return md.Element(kCalloutTag, const <md.Node>[])
      ..attributes['variant'] = v
      ..attributes['md'] = body.join('\n');
  }

  md.Element _aside(List<String> body, String? arg) {
    final color = (arg != null && _chartTokens.contains(arg)) ? arg : 'chart-1';
    return md.Element(kAsideTag, const <md.Node>[])
      ..attributes['color'] = color
      ..attributes['md'] = body.join('\n');
  }

  md.Element _columns(List<String> body) {
    final segments = <List<String>>[[]];
    for (final line in body) {
      if (_columnSep.hasMatch(line)) {
        segments.add([]);
      } else {
        segments.last.add(line);
      }
    }
    final columns = <md.Node>[
      for (final seg in segments)
        md.Element(kColumnTag, const <md.Node>[])
          ..attributes['md'] = seg.join('\n').trim(),
    ];
    return md.Element(kColumnsTag, columns);
  }
}

const Set<String> _chartTokens = {
  'chart-1',
  'chart-2',
  'chart-3',
  'chart-4',
  'chart-5',
};

/// `==text==` → a `mantleSpan` with `highlight=default`. Inner markdown is
/// parsed recursively (so emphasis inside still resolves at the AST level).
class HighlightInlineSyntax extends md.InlineSyntax {
  HighlightInlineSyntax() : super(r'==(?=\S)([\s\S]*?\S)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element(kSpanTag, parser.document.parseInline(match[1]!))
        ..attributes['highlight'] = 'default',
    );
    return true;
  }
}

/// `[text]{color=chart-N}` and/or `{highlight=chart-N}` → a `mantleSpan` with
/// `text-color` and/or `highlight` attributes. The valid tokens are baked into
/// the pattern, so `[text]{anything-else}` simply doesn't match and falls
/// through to normal link/text handling (we must never match-without-consuming,
/// which would loop the inline parser).
class ColorSpanInlineSyntax extends md.InlineSyntax {
  ColorSpanInlineSyntax()
      : super(
          r'\[(?=\S)([\s\S]*?\S)\]\{((?:(?:color|highlight)=chart-[1-5]\s*)+)\}',
        );

  static final RegExp _attr = RegExp(r'(color|highlight)=(chart-[1-5])');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element(kSpanTag, parser.document.parseInline(match[1]!));
    for (final m in _attr.allMatches(match[2]!)) {
      if (m[1] == 'color') {
        element.attributes['text-color'] = m[2]!;
      } else {
        element.attributes['highlight'] = m[2]!;
      }
    }
    parser.addNode(element);
    return true;
  }
}
