// The theme port, proven against its source. `tool/themes/` is a copy of
// mantle's generated themes.css + theme registry; `lib/theme/mantle_themes.g.dart`
// is what tool/generate_themes.dart makes of it. These tests read the copy
// with their own small parser and check the generated registry token by
// token, so a stale port, a dropped theme, or a colour that stopped being
// per-theme fails here with the theme and token named — not on a phone.
//
// Freshness of the copy itself (against mantle main) is CI's job
// (.github/workflows/verify.yml, the themes-upstream job).

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/theme/mantle_theme.dart';

/// `selector { --token: value; … }` → `{ firstSelector: { token: value } }`,
/// the same keying the generator uses (see tool/generate_themes.dart).
Map<String, Map<String, String>> _cssBlocks(String css) {
  final blocks = <String, Map<String, String>>{};
  for (final m in RegExp(r'([^{}]+)\{([^{}]*)\}').allMatches(css)) {
    final selector = m
        .group(1)!
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .trim();
    if (selector.isEmpty || selector.startsWith('@')) continue;
    final tokens = <String, String>{};
    for (final d in RegExp(r'--([\w-]+)\s*:\s*([^;]+);').allMatches(m.group(2)!)) {
      tokens[d.group(1)!] = d.group(2)!.trim();
    }
    if (tokens.isNotEmpty) blocks[selector.split(',').first.trim()] = tokens;
  }
  return blocks;
}

/// `#rrggbb` → the ARGB int a `Color` literal carries.
int _argb(String hex) => int.parse('ff${hex.substring(1)}', radix: 16);

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

/// Every token the port carries, by name, off a mode's tokens.
Map<String, Color> _ported(MantleModeTokens t) => {
      'background': t.scheme.background,
      'foreground': t.scheme.foreground,
      'card': t.scheme.card,
      'card-foreground': t.scheme.cardForeground,
      'popover': t.scheme.popover,
      'popover-foreground': t.scheme.popoverForeground,
      'primary': t.scheme.primary,
      'primary-foreground': t.scheme.primaryForeground,
      'secondary': t.scheme.secondary,
      'secondary-foreground': t.scheme.secondaryForeground,
      'muted': t.scheme.muted,
      'muted-foreground': t.scheme.mutedForeground,
      'accent': t.scheme.accent,
      'accent-foreground': t.scheme.accentForeground,
      'destructive': t.scheme.destructive,
      'destructive-foreground': t.scheme.destructiveForeground,
      'border': t.scheme.border,
      'input': t.scheme.input,
      'ring': t.scheme.ring,
      'chart-1': t.chart[0],
      'chart-2': t.chart[1],
      'chart-3': t.chart[2],
      'chart-4': t.chart[3],
      'chart-5': t.chart[4],
      'primary-ink': t.primaryInk,
      'destructive-ink': t.destructiveInk,
      'success': t.success,
      'success-foreground': t.successForeground,
      'success-ink': t.successInk,
      'warning': t.warning,
      'warning-foreground': t.warningForeground,
      'warning-ink': t.warningInk,
      'info': t.info,
      'info-foreground': t.infoForeground,
      'info-ink': t.infoInk,
      'code-keyword': t.codeKeyword,
      'code-string': t.codeString,
      'code-number': t.codeNumber,
      'code-title': t.codeTitle,
      'code-variable': t.codeVariable,
    };

void main() {
  final css = File('tool/themes/themes.css').readAsStringSync();
  final registry = File('tool/themes/theme-registry.gen.ts').readAsStringSync();
  final blocks = _cssBlocks(css);
  final webIds = RegExp(r"id: '([^']+)'")
      .allMatches(registry)
      .map((m) => m.group(1)!)
      .toList();
  final webLabels = {
    for (final m in RegExp(r"id: '([^']+)',\s*label: '([^']+)'").allMatches(registry))
      m.group(1)!: m.group(2)!,
  };

  test('the phone has every web theme, and nothing else, in web order', () {
    expect(kMantleThemes.map((t) => t.id).toList(), webIds);
    expect(webIds, contains('jackdaw'));
    expect(webIds, contains('jackdaw-harvest'));
    expect(webIds, contains('pinnacle'));
    expect(webIds.toSet().length, webIds.length, reason: 'duplicate ids');
  });

  test('labels are the web labels', () {
    for (final def in kMantleThemes) {
      expect(def.label, webLabels[def.id], reason: def.id);
    }
  });

  test('every ported token equals themes.css, both modes, every theme', () {
    final mismatches = <String>[];
    for (final def in kMantleThemes) {
      final base = def.id == 'clean-slate';
      final light = base ? blocks[':root']! : blocks['[data-color-theme="${def.id}"]']!;
      final dark = base ? blocks['.dark']! : blocks['.dark[data-color-theme="${def.id}"]']!;
      for (final (mode, tokens, ported) in [
        ('light', light, _ported(def.light)),
        ('dark', dark, _ported(def.dark)),
      ]) {
        for (final entry in ported.entries) {
          final want = tokens[entry.key];
          if (want == null) {
            mismatches.add('${def.id}/$mode --${entry.key}: not in themes.css');
            continue;
          }
          if (entry.value.toARGB32() != _argb(want)) {
            mismatches.add(
              '${def.id}/$mode --${entry.key}: phone ${_hex(entry.value)} web $want',
            );
          }
        }
      }
    }
    expect(mismatches, isEmpty, reason: mismatches.take(20).join('\n'));
  });

  test('picker swatches are the registry swatches of each mode', () {
    final swatch = RegExp(
      r"id: '([^']+)'.*?light: \[([^\]]*)\],\s*dark: \[([^\]]*)\]",
      dotAll: true,
    );
    List<int> list(String s) => RegExp(r"'(#[0-9a-f]{6})'")
        .allMatches(s)
        .map((m) => _argb(m.group(1)!))
        .toList();
    final byId = {
      for (final m in swatch.allMatches(registry))
        m.group(1)!: (list(m.group(2)!), list(m.group(3)!)),
    };
    for (final def in kMantleThemes) {
      final (light, dark) = byId[def.id]!;
      expect(def.light.swatches.map((c) => c.toARGB32()), light, reason: def.id);
      expect(def.dark.swatches.map((c) => c.toARGB32()), dark, reason: def.id);
    }
  });

  test('status colours are per theme, not one set', () {
    // The web derives them from each theme's own chroma: mono's success is as
    // quiet as its destructive, cyberpunk's as loud. If every theme carried
    // the same green the port would have regressed to a single palette.
    // (The solver lands many quiet themes on the same green — 32 of the 86
    // mode blocks share one value today — so the bar is "several", not
    // "all distinct".)
    final greens = {
      for (final t in kMantleThemes) ...[
        t.light.success.toARGB32(),
        t.dark.success.toARGB32(),
      ],
    };
    expect(greens.length, greaterThan(10));
    expect(
      MantleTheme.defFor('mono').light.success,
      isNot(MantleTheme.defFor('cyberpunk').light.success),
    );
  });

  test('every fill has a distinct ink (fills never double as text)', () {
    for (final def in kMantleThemes) {
      for (final t in [def.light, def.dark]) {
        expect(t.successInk, isNotNull, reason: def.id);
        expect(t.primaryInk, isNot(t.scheme.primaryForeground), reason: def.id);
      }
    }
  });

  test('defFor falls back to the default for an unknown id', () {
    expect(MantleTheme.defFor('no-such-theme').id, MantleTheme.defaultId);
    expect(MantleTheme.has('jackdaw'), isTrue);
    expect(MantleTheme.has('no-such-theme'), isFalse);
    expect(MantleTheme.has(null), isFalse);
  });
}
