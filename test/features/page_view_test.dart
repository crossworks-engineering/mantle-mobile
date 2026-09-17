// PageViewScreen against the golden page: test/fixtures/golden_page.md is the
// server's own markdown export (mantle doc-to-markdown) of a page that uses
// every node the web editor can make (dev brain page 90971a5c…). One test per
// construct, so a regression names the block. Network is mocked: the file
// bytes are a 1×1 PNG, the drawing a one-rect SVG.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/chat/chat_api.dart' show fileBytesProvider;
import 'package:jackdaw/data/nodes/nodes_api.dart';
import 'package:jackdaw/data/pages/pages_api.dart';
import 'package:jackdaw/data/pages/pages_models.dart';
import 'package:jackdaw/features/pages/page_view_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../helpers/pump_screen.dart';

class MockPagesApi extends Mock implements PagesApi {}

class MockNodesApi extends Mock implements NodesApi {}

const _pageId = '90971a5c-95b3-4365-aac6-b070f7108eb5';
const _imageId = '87e0f992-2536-4c9f-8e81-b2118f92906d';
const _drawId = '5483e1d6-6b40-44bf-a925-16aaba540dee';
const _noteId = '916d094a-d901-402e-a1f1-8994eea8257c';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
const _svg = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
    '<rect width="10" height="10"/></svg>';

PageRow _meta({bool hasDraft = false}) => PageRow(
      id: _pageId,
      parentId: null,
      title: 'Golden page — phone render parity',
      icon: '🧪',
      tags: const ['golden'],
      summary: null,
      updatedAt: DateTime.utc(2026, 9, 17),
      hasDraft: hasDraft,
    );

void main() {
  final golden = File('test/fixtures/golden_page.md').readAsStringSync();
  late MockPagesApi pages;
  late MockNodesApi nodes;

  setUp(() {
    pages = MockPagesApi();
    nodes = MockNodesApi();
    when(() => pages.backlinks(any())).thenAnswer((_) async => const []);
  });

  Future<void> pump(WidgetTester tester,
      {String? markdown, bool hasDraft = false}) async {
    when(() => pages.meta(_pageId)).thenAnswer((_) async => _meta(hasDraft: hasDraft));
    when(() => pages.markdown(_pageId)).thenAnswer((_) async => markdown ?? golden);
    await pumpScreen(
      tester,
      const PageViewScreen(pageId: _pageId),
      container: ProviderContainer(overrides: [
        pagesApiProvider.overrideWithValue(pages),
        nodesApiProvider.overrideWithValue(nodes),
        fileBytesProvider.overrideWith((ref, id) async => id == _imageId ? _png : null),
        drawSvgProvider.overrideWith((ref, id) async => id == _drawId ? _svg : null),
      ]),
    );
    // Image decoding and the SVG parse settle a frame later.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }

  Finder rich(String text) => find.textContaining(text, findRichText: true);

  testWidgets('no raw round-trip syntax survives to the screen', (tester) async {
    await pump(tester);
    // (`](` alone is NOT checked: the fixture's first paragraph carries a
    // mangled colour span the server's own exporter produced — a mantle bug,
    // recorded on the dev brain — and the phone shows that text as it is.)
    for (final raw in ['mention:node', 'mention:entity', '](page:', '](media:', '](draw:']) {
      expect(rich(raw), findsNothing, reason: raw);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('headings and inline marks', (tester) async {
    await pump(tester);
    expect(find.text('Headings'), findsOneWidget);
    expect(find.text('Level three'), findsOneWidget);
    expect(rich('bold'), findsWidgets);
    expect(rich('inline code'), findsWidgets);
  });

  testWidgets('task items are checkboxes, not [ ] text', (tester) async {
    await pump(tester);
    expect(rich('[ ]'), findsNothing);
    expect(rich('[x]'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.check_box), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.check_box_outline_blank), findsNWidgets(2));
    expect(rich('Nested bullet'), findsWidgets);
  });

  testWidgets('a six-column table renders as a Table that scrolls sideways', (tester) async {
    await pump(tester);
    final table = find.byType(Table);
    expect(table, findsOneWidget);
    expect(find.ancestor(of: table, matching: find.byType(SingleChildScrollView)), findsWidgets);
    for (final head in ['Site', 'Store', 'Status', 'Owner', 'Due', 'Notes']) {
      expect(rich(head), findsWidgets, reason: head);
    }
    expect(rich('code in a cell'), findsWidgets);
  });

  testWidgets('one callout per variant, each with its icon', (tester) async {
    await pump(tester);
    expect(find.byIcon(LucideIcons.info), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleCheckBig), findsOneWidget);
    expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
    expect(find.byIcon(LucideIcons.octagonAlert), findsOneWidget);
  });

  testWidgets('aside and columns', (tester) async {
    await pump(tester);
    expect(rich('An aside on chart-3'), findsWidgets);
    expect(rich('Left column with a list'), findsWidgets);
    expect(rich('Right column with a callout'), findsWidgets);
  });

  testWidgets('math: inline, in a cell, and a block', (tester) async {
    await pump(tester);
    expect(find.byType(Math), findsNWidgets(3));
  });

  testWidgets('three highlighted code blocks and a captioned legacy diagram', (tester) async {
    await pump(tester);
    expect(rich('greeting'), findsWidgets);
    expect(rich('solveInk'), findsWidgets);
    expect(rich('fvm flutter test'), findsWidgets);
    expect(find.text('Diagram (legacy Mermaid) — rendered on the web'), findsOneWidget);
    expect(rich('A[Phone]'), findsWidgets);
  });

  testWidgets('mentions: node chips are buttons, the entity chip is a label', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel('Open Jackdaw Colours'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Re-port the colour themes'), findsOneWidget);
    expect(find.bySemanticsLabel('Jason Schoeman'), findsOneWidget);
    expect(find.byIcon(LucideIcons.atSign), findsOneWidget);
  });

  testWidgets('tapping a node mention resolves its type', (tester) async {
    when(() => nodes.resolve(_noteId)).thenAnswer(
      (_) async => const NodeRef(id: _noteId, type: 'note', title: 'Jackdaw Colours'),
    );
    await pump(tester);
    // The golden page is taller than the test viewport; bring the chip in.
    final chip = find.bySemanticsLabel('Open Jackdaw Colours');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    verify(() => nodes.resolve(_noteId)).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('file embed and child page are chips', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel('Open file jackdaw-brand.md'), findsOneWidget);
    expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);
    expect(find.bySemanticsLabel('Open page The client repos'), findsOneWidget);
    // Tapping without a router is a no-op, never a crash.
    final chip = find.bySemanticsLabel('Open page The client repos');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the image fetches through the authed provider and opens full screen', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel('Open image Pinnacle brain pyramid'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
      findsOneWidget,
    );
    expect(find.text('Loading image…'), findsNothing);
  });

  testWidgets('the drawing renders its SVG snapshot', (tester) async {
    await pump(tester);
    expect(find.byType(SvgPicture), findsAtLeastNWidgets(1));
    expect(find.text('A drawing'), findsNothing); // no fallback chip
  });

  testWidgets('a failed image shows the alt chip, not a spinner', (tester) async {
    await pump(tester, markdown: '![Missing picture](media:no-such-file)');
    expect(find.text('Missing picture'), findsOneWidget);
    expect(find.text('Loading image…'), findsNothing);
  });

  testWidgets('internal links keep their words; the anchor is plain text', (tester) async {
    await pump(tester);
    expect(rich('The client repos'), findsWidgets);
    expect(rich('back to top'), findsWidgets);
    expect(rich('#golden-page'), findsNothing);
  });

  testWidgets('wrapped export lines join into one paragraph', (tester) async {
    await pump(tester, markdown: 'Everything below is a construct the\neditor supports.\n\n:::info\nfirst line\nsecond line\n:::');
    expect(rich('construct the editor supports'), findsOneWidget);
    expect(rich('first line second line'), findsOneWidget);
  });

  testWidgets('fenced code tokens carry no inline-code background', (tester) async {
    await pump(tester);
    final rich = tester.widgetList<Text>(find.byType(Text)).where(
      (t) => t.textSpan?.toPlainText().contains('greeting') ?? false,
    );
    expect(rich, isNotEmpty);
    var spans = 0;
    for (final t in rich) {
      t.textSpan!.visitChildren((span) {
        spans++;
        expect(span.style?.backgroundColor, isNull);
        return true;
      });
    }
    expect(spans, greaterThan(3)); // it really was highlighted token by token
  });

  testWidgets('a committed body shows even when a draft also exists', (tester) async {
    await pump(tester, hasDraft: true);
    expect(find.text('Headings'), findsOneWidget);
    expect(find.textContaining('unsaved draft'), findsNothing);
  });

  testWidgets('a draft-only page says so instead of "empty"', (tester) async {
    await pump(tester, markdown: '', hasDraft: true);
    expect(find.textContaining('unsaved draft changes'), findsOneWidget);
  });
}
