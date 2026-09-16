// The styling guide's hard rules, held by a test instead of by prose. Each
// count is a ceiling that only ever falls: to add a violation you have to
// raise the number here, in the same diff, where a reviewer sees it.
//
// Scope: lib/features and lib/widgets (the screens). lib/theme is where the
// literals are allowed to live.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final files = [
    ...Directory('lib/features').listSync(recursive: true),
    ...Directory('lib/widgets').listSync(recursive: true),
  ]
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  Map<String, int> count(RegExp pattern) {
    final hits = <String, int>{};
    for (final f in files) {
      final n = pattern.allMatches(f.readAsStringSync()).length;
      if (n > 0) hits[f.path] = n;
    }
    return hits;
  }

  int total(Map<String, int> hits) => hits.values.fold(0, (a, b) => a + b);

  test('no hardcoded colours in screens (theme tokens only)', () {
    final hits = count(RegExp(r'Color\(0x|Color\.fromARGB|(?<![A-Za-z])Colors\.'));
    expect(total(hits), 0, reason: 'colour literals: $hits');
  });

  test('no hand-picked font sizes in screens (scale entries only)', () {
    // A numeric fontSize. Proportional sizes (an avatar glyph scaling with its
    // circle) are not literals and are not counted.
    final hits = count(RegExp(r'fontSize:\s*\d'));
    expect(total(hits), 0, reason: 'fontSize literals: $hits');
  });

  test('no Material widgets (shadcn_ui only)', () {
    final hits = count(RegExp(r"package:flutter/material\.dart'(?!\s*show ThemeMode)"));
    expect(total(hits), 0, reason: 'material imports: $hits');
    final scaffolds = count(RegExp(r'\bScaffold\(|\bAppBar\('));
    expect(total(scaffolds), 0, reason: 'Scaffold/AppBar: $scaffolds');
  });

  test('every date is formatted by core/format/dates.dart', () {
    // The tell-tale of a hand-rolled formatter.
    final hits = count(RegExp(r"padLeft\(2, '0'\)\}-"));
    expect(total(hits), 0, reason: 'hand-rolled ISO dates: $hits');
  });

  test('destructive confirms go through confirmDestructive', () {
    final hits = count(RegExp(r'ShadDialog\.alert\('))
      ..remove('lib/widgets/confirm_dialog.dart'); // the helper itself
    expect(total(hits), 0, reason: 'inline alert dialogs: $hits');
  });
}
