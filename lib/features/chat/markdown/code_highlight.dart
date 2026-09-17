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
/// re_highlight (a pure-Dart highlight.js port). The colour map is the ACTIVE
/// theme's own code palette — the web's `code-keyword` / `code-string` /
/// `code-number` / `code-title` / `code-variable` inks, ported per theme — so
/// a code block on the phone is coloured exactly as the same block on the web,
/// in light and dark, for every colour theme. The five inks are solved
/// against the neutral surfaces (code sits on `muted`), so they are legible by
/// construction; chart colours are 3:1 data ink and are not used for text here.
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
  final code = MantleColors.of(context).tokens(theme.brightness);
  final muted = theme.colorScheme.mutedForeground;

  // highlight.js scope → the web's five code inks, grouped the way
  // mantle's `.code-view` hljs rules group them: keyword (brand hue), string,
  // number/literal, title/section, variable/attribute.
  final keyword = TextStyle(color: code.codeKeyword, fontWeight: FontWeight.w600);
  final string = TextStyle(color: code.codeString);
  final number = TextStyle(color: code.codeNumber);
  final title = TextStyle(color: code.codeTitle);
  final variable = TextStyle(color: code.codeVariable);
  final comment = TextStyle(color: muted, fontStyle: FontStyle.italic);
  final styles = <String, TextStyle>{
    'root': baseStyle,
    'keyword': keyword,
    'built_in': title,
    'type': title,
    'literal': number,
    'number': number,
    'operator': baseStyle,
    'punctuation': baseStyle,
    'property': variable,
    'regexp': string,
    'string': string,
    'char.escape': number,
    'subst': baseStyle,
    'symbol': number,
    'variable': baseStyle,
    'variable.language': keyword,
    'variable.constant': number,
    'title': title,
    'title.class': title,
    'title.function': title,
    'params': baseStyle,
    'comment': comment,
    'doctag': TextStyle(color: muted),
    'meta': number,
    'meta.prompt': TextStyle(color: muted),
    'section': TextStyle(color: code.codeTitle, fontWeight: FontWeight.w600),
    'tag': keyword,
    'name': keyword,
    'attr': variable,
    'attribute': variable,
    'bullet': number,
    'code': string,
    'emphasis': const TextStyle(fontStyle: FontStyle.italic),
    'strong': const TextStyle(fontWeight: FontWeight.w700),
    'formula': number,
    'link': title,
    'quote': comment,
    'selector-tag': keyword,
    'selector-id': title,
    'selector-class': variable,
    'selector-attr': variable,
    'selector-pseudo': string,
    'template-tag': keyword,
    'template-variable': number,
    'addition': string,
    'deletion': TextStyle(color: code.destructiveInk),
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
