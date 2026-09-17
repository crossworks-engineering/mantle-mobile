import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/mantle_theme.dart';
import 'code_highlight.dart';
import 'mantle_syntax.dart';

/// Renders an assistant reply (Mantle's GFM-superset markdown) into themed
/// Flutter widgets.
///
/// Phase 1: standard GitHub-flavored markdown. Phase 2: Mantle's custom
/// containers (`:::callouts`, `:::aside`, `:::columns`) and inline colour spans
/// (`==highlight==`, `[text]{color=chart-N}`) — parsed by mantle_syntax.dart and
/// rendered by the builders below. Every style comes from [ShadTheme] tokens, so
/// light/dark and the host bubble colour drive the output (no hardcoded
/// colours). Images and math are later phases — see docs/architecture.md.
class MantleMarkdown extends StatelessWidget {
  const MantleMarkdown(
    this.data, {
    super.key,
    this.textColor,
    this.selectable = true,
    this.imageBuilder,
  });

  /// The raw markdown string (the assistant message `text`).
  final String data;

  /// Base text colour for body copy. Defaults to the theme `foreground`; the
  /// chat bubble passes its own foreground so the markdown matches the bubble.
  final Color? textColor;

  /// Whether body text is selectable. Top-level replies are selectable; nested
  /// renders inside containers turn this off (no nested selection areas).
  final bool selectable;

  /// Renders `![alt](src)` images. Null (the default, chat bubbles) leaves
  /// image handling to the markdown package; the page viewer passes a builder
  /// that fetches Mantle file nodes through the authed client (an `Image`
  /// widget can't send the bearer header).
  final Widget Function(Uri uri, String? title, String? alt)? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return MarkdownBody(
      data: data,
      selectable: selectable,
      softLineBreak: true,
      // GitHub-flavored base (tables, strikethrough, task lists, autolinks).
      extensionSet: md.ExtensionSet.gitHubFlavored,
      // Mantle's custom dialect on top.
      blockSyntaxes: const [MantleFenceSyntax(), MathBlockSyntax()],
      inlineSyntaxes: [
        HighlightInlineSyntax(),
        ColorSpanInlineSyntax(),
        MathInlineSyntax(),
      ],
      builders: {
        kCalloutTag: _CalloutBuilder(),
        kAsideTag: _AsideBuilder(),
        kColumnsTag: _ColumnsBuilder(),
        kSpanTag: _SpanBuilder(),
        kMathTag: _MathBuilder(block: false),
        kMathBlockTag: _MathBuilder(block: true),
        'code': _CodeBuilder(),
      },
      styleSheet: _styleSheet(theme, textColor ?? theme.colorScheme.foreground),
      onTapLink: (_, href, _) => _openLink(href),
      imageBuilder: imageBuilder,
    );
  }
}

/// Opens external links; relative/internal links (`/…`, `#…`) are left for a
/// later phase (in-app routing into Mantle resources).
Future<void> _openLink(String? href) async {
  if (href == null) return;
  final uri = Uri.tryParse(href);
  if (uri == null) return;
  const external = {'http', 'https', 'mailto'};
  if (!external.contains(uri.scheme)) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

int _chartIndex(String? token) =>
    int.tryParse((token ?? 'chart-1').split('-').last) ?? 1;

// ── Math + code builders ───────────────────────────────────────────────────

/// `$…$` / `$$…$$` TeX via flutter_math_fork. Inline math rides in the text
/// line; block math centres on its own line and scrolls horizontally when
/// wider than the bubble. A TeX parse error falls back to the raw source in
/// monospace — never a crash, never silently dropped content.
class _MathBuilder extends MarkdownElementBuilder {
  _MathBuilder({required this.block});

  final bool block;

  @override
  bool isBlockElement() => block;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final theme = ShadTheme.of(context);
    final style = (preferredStyle ?? parentStyle ?? theme.textTheme.p)
        .copyWith(color: parentStyle?.color ?? theme.colorScheme.foreground);
    final tex = element.attributes['tex'] ?? '';
    final math = Math.tex(
      tex,
      mathStyle: block ? MathStyle.display : MathStyle.text,
      textStyle: style,
      onErrorFallback: (_) => Text(
        block ? '\$\$$tex\$\$' : '\$$tex\$',
        style: style.copyWith(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Menlo', 'Courier New', 'monospace'],
        ),
      ),
    );
    if (!block) return math;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(child: math),
      ),
    );
  }
}

/// Fenced code blocks with a ```language get themed syntax highlighting
/// (see code_highlight.dart). Inline code and unknown languages return null
/// so the package's default stylesheet rendering applies unchanged.
class _CodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final classAttr = element.attributes['class'] ?? '';
    if (!classAttr.startsWith('language-')) return null; // inline code
    final language = classAttr.substring('language-'.length);
    final source = element.textContent.endsWith('\n')
        ? element.textContent.substring(0, element.textContent.length - 1)
        : element.textContent;
    final base = (preferredStyle ?? parentStyle ?? const TextStyle()).copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Courier New', 'monospace'],
    );
    final span = highlightedCode(context, source, language, baseStyle: base);
    if (span == null) return null; // unknown language → default rendering
    // A custom `code` builder REPLACES the package's padded scroller, and the
    // `pre` wrapper only draws the decoration — re-apply the stylesheet's
    // 12px codeblockPadding here or the code sits flush against the border.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Text.rich(span),
    );
  }
}

// ── Block builders ─────────────────────────────────────────────────────────

/// `:::info|success|warning|danger` — tinted panel with a left accent + icon.
class _CalloutBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final theme = ShadTheme.of(context);
    final variant = element.attributes['variant'] ?? 'info';
    final (accent, ink) = _calloutColors(context, theme, variant);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Icon(_calloutIcon(variant), size: 18, color: ink),
          ),
          Expanded(
            child: MantleMarkdown(
              element.attributes['md'] ?? '',
              textColor: theme.colorScheme.foreground,
              selectable: false,
            ),
          ),
        ],
      ),
    );
  }

  /// The callout's colours are the theme's own status role — `success`,
  /// `warning`, `info`, `destructive` — exactly as the web's callout view
  /// draws them: the FILL tints the box and its edge, the role's INK colours
  /// the icon (a fill is tuned to sit behind text, not to be a glyph on the
  /// card). So a callout is green on `mono` for the same reason it is green
  /// on `cyberpunk`, only as loud as that theme's own destructive.
  (Color fill, Color ink) _calloutColors(
    BuildContext context,
    ShadThemeData theme,
    String variant,
  ) {
    final t = MantleColors.of(context).tokens(theme.brightness);
    switch (variant) {
      case 'success':
        return (t.success, t.successInk);
      case 'warning':
        return (t.warning, t.warningInk);
      case 'danger':
        return (theme.colorScheme.destructive, t.destructiveInk);
      default:
        return (t.info, t.infoInk);
    }
  }

  IconData _calloutIcon(String variant) {
    switch (variant) {
      case 'success':
        return LucideIcons.circleCheckBig;
      case 'warning':
        return LucideIcons.triangleAlert;
      case 'danger':
        return LucideIcons.octagonAlert;
      default:
        return LucideIcons.info;
    }
  }
}

/// `:::aside [chart-N]` — softly tinted, gradient-backed side note.
class _AsideBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final theme = ShadTheme.of(context);
    final color = MantleColors.of(context).chart(
      theme.brightness,
      _chartIndex(element.attributes['color']),
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.05)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: MantleMarkdown(
        element.attributes['md'] ?? '',
        textColor: theme.colorScheme.foreground,
        selectable: false,
      ),
    );
  }
}

/// `:::columns … +++ … :::` — stacked vertically (the chat bubble is narrow, so
/// we use Mantle's mobile behaviour), each column on a muted surface.
class _ColumnsBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final theme = ShadTheme.of(context);
    final columns = (element.children ?? const <md.Node>[])
        .whereType<md.Element>()
        .where((e) => e.tag == kColumnTag)
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final col in columns)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              // card + cardForeground with a border: reads on the muted
              // assistant bubble AND on a page's plain background.
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.card,
                  border: Border.all(color: theme.colorScheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MantleMarkdown(
                  col.attributes['md'] ?? '',
                  textColor: theme.colorScheme.cardForeground,
                  selectable: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Inline builder ─────────────────────────────────────────────────────────

/// `mantleSpan` — inline colour and/or highlight. `text-color` sets the text
/// colour; `highlight` ('default' → primary, else chart-N) adds a rounded
/// background. (Nested emphasis inside a span flattens to plain styled text —
/// an accepted v1 limitation; spans almost always wrap plain text.)
class _SpanBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final theme = ShadTheme.of(context);
    final b = theme.brightness;
    final colors = MantleColors.of(context);
    var style = parentStyle ?? theme.textTheme.p;

    final textColor = element.attributes['text-color'];
    if (textColor != null) {
      style = style.copyWith(color: colors.chart(b, _chartIndex(textColor)));
    }

    final Widget text = Text(element.textContent, style: style);

    final highlight = element.attributes['highlight'];
    if (highlight == null) return text;

    final background = highlight == 'default'
        ? theme.colorScheme.primary.withValues(alpha: 0.22)
        : colors.chart(b, _chartIndex(highlight)).withValues(alpha: 0.30);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(3),
      ),
      child: text,
    );
  }
}

// ── Style sheet ────────────────────────────────────────────────────────────

MarkdownStyleSheet _styleSheet(ShadThemeData theme, Color text) {
  final scheme = theme.colorScheme;
  final t = theme.textTheme;
  final body = t.p.copyWith(color: text);

  // No dedicated monospace family is bundled; fall back across platforms.
  // One step below body on the scale (small), not a hand-picked size.
  final mono = body.copyWith(
    fontFamily: 'monospace',
    fontFamilyFallback: const ['Menlo', 'Courier New', 'monospace'],
    fontSize: t.small.fontSize,
  );

  return MarkdownStyleSheet(
    p: body,
    a: body.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    ),
    em: body.copyWith(fontStyle: FontStyle.italic),
    strong: body.copyWith(fontWeight: FontWeight.w600),
    del: body.copyWith(decoration: TextDecoration.lineThrough),
    // Headings stay bubble-sized: map down so an h1 doesn't dwarf a reply.
    h1: t.h3.copyWith(color: text),
    h2: t.h4.copyWith(color: text),
    h3: t.h4.copyWith(color: text),
    h4: body.copyWith(fontWeight: FontWeight.w600),
    h5: body.copyWith(fontWeight: FontWeight.w600),
    h6: body.copyWith(fontWeight: FontWeight.w600, color: scheme.mutedForeground),
    code: mono.copyWith(
      color: scheme.secondaryForeground,
      backgroundColor: scheme.secondary,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: scheme.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: scheme.border),
    ),
    blockquote: body.copyWith(color: scheme.mutedForeground),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: scheme.border, width: 3)),
    ),
    listBullet: body,
    checkbox: body.copyWith(color: scheme.primary),
    blockSpacing: 8,
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: scheme.border)),
    ),
    tableHead: body.copyWith(fontWeight: FontWeight.w600),
    tableBody: body,
    tableBorder: TableBorder.all(color: scheme.border),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    tableColumnWidth: const IntrinsicColumnWidth(),
  );
}
