// The folder tints and the curated icon names: both mirror the web, so both
// are pinned (mantle APP_TINTS, jackdaw app-icons.ts).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/search/search_models.dart';
import 'package:jackdaw/data/tree/tree_models.dart';
import 'package:jackdaw/features/tree/tree_rows.dart';
import 'package:jackdaw/theme/app_tints.dart';
import 'package:jackdaw/theme/lucide_names.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  const white = Color(0xFFFFFFFF);
  const black = Color(0xFF000000);

  test('every tint the brain can send has a hue', () {
    expect(AppTints.keys.toList(), kTreeTints);
    expect(kTreeTints, hasLength(13));
  });

  test('a fill is mostly the page, an ink is mostly the hue', () {
    final fill = AppTints.fill('blue', white)!;
    final ink = AppTints.ink('blue', black)!;

    // 18% blue over white: light, and still bluer than it is red.
    expect(fill.computeLuminance(), greaterThan(0.7));
    expect(fill.b, greaterThan(fill.r));
    // 72% blue into black: dark enough to read on the fill.
    expect(ink.computeLuminance(), lessThan(0.25));
    expect(ink.b, greaterThan(ink.r));
  });

  test('a fill follows the theme: dark page, dark fill', () {
    final onDark = AppTints.fill('amber', const Color(0xFF111111))!;
    expect(onDark.computeLuminance(), lessThan(0.1));
  });

  test('an unknown tint is no tint', () {
    expect(AppTints.fill('mauve', white), isNull);
    expect(AppTints.ink(null, black), isNull);
  });

  test('mixing a colour with itself changes nothing', () {
    const c = Color(0xFF2B7FFF);
    final same = mixOklab(c, c, 0.4);
    expect((same.r - c.r).abs(), lessThan(0.01));
    expect((same.g - c.g).abs(), lessThan(0.01));
    expect((same.b - c.b).abs(), lessThan(0.01));
  });

  test('the curated icon set is the web\'s 171, by lucide name', () {
    expect(kLucideByName, hasLength(171));
    expect(lucideIconFor('lucide:briefcase'), LucideIcons.briefcase);
    expect(lucideIconFor('lucide:building-2'), LucideIcons.building2);
    expect(lucideIconFor('lucide:not-an-icon'), isNull);
    expect(lucideIconFor('🚀'), isNull);
    expect(emojiIconFor('🚀'), '🚀');
    expect(emojiIconFor('lucide:briefcase'), isNull);
  });

  test('a global search hit says the folder it is filed in', () {
    SearchResult hit(String path) =>
        SearchResult.fromJson({'id': 'x', 'title': 'T', 'path': path});

    expect(hit('pages.clients.acme_corp').folderPath, 'clients › acme corp');
    expect(hit('notes.meetings.2026').folderPath, 'meetings › 2026');
    expect(hit('pages').folderPath, isNull); // the top level
    expect(hit('assistant.digests').folderPath, isNull); // not a tree kind
    expect(hit('').folderPath, isNull);
  });
}
