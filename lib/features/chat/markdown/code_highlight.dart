import 'package:flutter/widgets.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/shell.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../theme/mantle_theme.dart';

/// Syntax highlighting for fenced code blocks (` ```dart ` …) via
/// re_highlight (a pure-Dart highlight.js port). The colour map is built from
/// the ACTIVE theme's tokens — foreground + the chart ramp — so highlighted
/// code follows light/dark and every one of the 42 colour themes instead of
/// shipping a fixed palette.
///
/// A curated common set, NOT `languages/all.dart` — the full ~190-grammar
/// registry ground the kernel compile to a crawl (30+ min test builds).
/// Aliases (`js`, `ts`, `py`, `sh`, `html`, …) resolve via each Mode's own
/// alias list through `getLanguage`.
final Highlight _highlight = Highlight()
  ..registerLanguages({
    'bash': langBash,
    'c': langC,
    'cpp': langCpp,
    'csharp': langCsharp,
    'css': langCss,
    'dart': langDart,
    'diff': langDiff,
    'dockerfile': langDockerfile,
    'go': langGo,
    'ini': langIni,
    'java': langJava,
    'javascript': langJavascript,
    'json': langJson,
    'kotlin': langKotlin,
    'lua': langLua,
    'markdown': langMarkdown,
    'php': langPhp,
    'python': langPython,
    'ruby': langRuby,
    'rust': langRust,
    'shell': langShell,
    'sql': langSql,
    'swift': langSwift,
    'typescript': langTypescript,
    'xml': langXml,
    'yaml': langYaml,
  });

/// Highlight [source] as [language]. Returns null when the language is
/// unknown/unsupported — the caller falls back to the default plain
/// code-block rendering.
TextSpan? highlightedCode(
  BuildContext context,
  String source,
  String? language, {
  required TextStyle baseStyle,
}) {
  final lang = language?.trim().toLowerCase();
  if (lang == null || lang.isEmpty) return null;
  if (_highlight.getLanguage(lang) == null) return null; // aliases resolve too

  final theme = ShadTheme.of(context);
  final colors = MantleColors.of(context);
  final b = theme.brightness;
  Color chart(int n) => colors.chart(b, n);
  final muted = theme.colorScheme.mutedForeground;

  // highlight.js scope → themed style. Chart-ramp assignments follow the
  // usual highlight-theme groupings (keywords/strings/numbers/titles/meta).
  final styles = <String, TextStyle>{
    'root': baseStyle,
    'keyword': TextStyle(color: chart(1), fontWeight: FontWeight.w600),
    'built_in': TextStyle(color: chart(2)),
    'type': TextStyle(color: chart(2)),
    'literal': TextStyle(color: chart(4)),
    'number': TextStyle(color: chart(4)),
    'operator': baseStyle,
    'punctuation': baseStyle,
    'property': TextStyle(color: chart(2)),
    'regexp': TextStyle(color: chart(3)),
    'string': TextStyle(color: chart(3)),
    'char.escape': TextStyle(color: chart(4)),
    'subst': baseStyle,
    'symbol': TextStyle(color: chart(4)),
    'variable': baseStyle,
    'variable.language': TextStyle(color: chart(1)),
    'variable.constant': TextStyle(color: chart(4)),
    'title': TextStyle(color: chart(5)),
    'title.class': TextStyle(color: chart(2)),
    'title.function': TextStyle(color: chart(5)),
    'params': baseStyle,
    'comment': TextStyle(color: muted, fontStyle: FontStyle.italic),
    'doctag': TextStyle(color: muted),
    'meta': TextStyle(color: chart(4)),
    'meta.prompt': TextStyle(color: muted),
    'section': TextStyle(color: chart(5), fontWeight: FontWeight.w600),
    'tag': TextStyle(color: chart(1)),
    'name': TextStyle(color: chart(1)),
    'attr': TextStyle(color: chart(2)),
    'attribute': TextStyle(color: chart(2)),
    'bullet': TextStyle(color: chart(4)),
    'code': TextStyle(color: chart(3)),
    'emphasis': const TextStyle(fontStyle: FontStyle.italic),
    'strong': const TextStyle(fontWeight: FontWeight.w700),
    'formula': TextStyle(color: chart(4)),
    'link': TextStyle(color: chart(2)),
    'quote': TextStyle(color: muted, fontStyle: FontStyle.italic),
    'selector-tag': TextStyle(color: chart(1)),
    'selector-id': TextStyle(color: chart(5)),
    'selector-class': TextStyle(color: chart(2)),
    'selector-attr': TextStyle(color: chart(2)),
    'selector-pseudo': TextStyle(color: chart(3)),
    'template-tag': TextStyle(color: chart(1)),
    'template-variable': TextStyle(color: chart(4)),
    'addition': TextStyle(color: chart(3)),
    'deletion': TextStyle(color: theme.colorScheme.destructive),
  };

  try {
    final result = _highlight.highlight(code: source, language: lang);
    final renderer = TextSpanRenderer(baseStyle, styles);
    result.render(renderer);
    return renderer.span;
  } catch (_) {
    return null; // any parse hiccup → default plain rendering
  }
}
