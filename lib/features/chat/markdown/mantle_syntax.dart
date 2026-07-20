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
const String kMathTag = 'mantleMath';
const String kMathBlockTag = 'mantleMathBlock';

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

/// Inline `$…$` TeX. Guards against currency: the opening `$` must not be
/// followed by whitespace or another `$`, the closing `$` must not be
/// preceded by whitespace or followed by a digit ("$5 and $6" never
/// matches), and digits-plus-punctuation-only content ("$5,000$"-shaped
/// accidents) falls through to plain text. The TeX rides in the `tex`
/// attribute RAW — never re-parsed as markdown.
class MathInlineSyntax extends md.InlineSyntax {
  MathInlineSyntax() : super(r'\$(?![\s$])((?:\\[\s\S]|[^$\n])+?)(?<!\s)\$(?!\d)');

  static final RegExp _currencyish = RegExp(r'^[\d.,\s]+$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match[1]!;
    if (_currencyish.hasMatch(tex)) {
      // Digits-and-punctuation only — treat as currency, NOT math. Emit the
      // matched text verbatim and return true so the parser consumes it:
      // returning false here would match-without-consuming and loop the
      // inline parser forever (see ColorSpanInlineSyntax's warning above).
      parser.addNode(md.Text(match[0]!));
      return true;
    }
    parser.addNode(md.Element.empty(kMathTag)..attributes['tex'] = tex);
    return true;
  }
}

/// Block `$$ … $$` TeX — either one line (`$$E=mc^2$$`) or a fenced block
/// OPENED by a bare `$$` line and closed by a line ending in `$$`. A line
/// that merely *starts* with `$$` followed by prose (`$$50 below the
/// open…`) never opens a block — without that guard an unclosed open would
/// swallow the rest of the message into one broken TeX blob.
class MathBlockSyntax extends md.BlockSyntax {
  const MathBlockSyntax();

  static final RegExp _open = RegExp(r'^\s*\$\$(.*)$');

  @override
  RegExp get pattern => _open;

  @override
  bool canParse(md.BlockParser parser) {
    final m = _open.firstMatch(parser.current.content);
    if (m == null) return false;
    final rest = m.group(1)!.trim();
    return rest.isEmpty || rest.endsWith(r'$$');
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final first = _open.firstMatch(parser.current.content)!.group(1)!.trim();
    parser.advance();

    final lines = <String>[];
    if (first.isNotEmpty) {
      if (first.endsWith(r'$$')) {
        // Single-line form: `$$E=mc^2$$`.
        return md.Element.empty(kMathBlockTag)
          ..attributes['tex'] =
              first.substring(0, first.length - 2).trim();
      }
      lines.add(first);
    }
    while (!parser.isDone) {
      final line = parser.current.content;
      final trimmed = line.trim();
      parser.advance();
      if (trimmed == r'$$') break;
      if (trimmed.endsWith(r'$$')) {
        lines.add(trimmed.substring(0, trimmed.length - 2).trimRight());
        break;
      }
      lines.add(line);
    }
    return md.Element.empty(kMathBlockTag)
      ..attributes['tex'] = lines.join('\n').trim();
  }
}

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
