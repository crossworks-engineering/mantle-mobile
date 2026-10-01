// The Folder index block in the page viewer. The markdown is a real export
// (test/fixtures/tree/page_folder_index.md): one block for the page's own
// folder (`folder:here`), one naming a folder by id.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/pages/pages_api.dart';
import 'package:jackdaw/data/pages/pages_models.dart';
import 'package:jackdaw/data/tree/tree_api.dart';
import 'package:jackdaw/data/tree/tree_models.dart';
import 'package:jackdaw/features/chat/markdown/mantle_refs.dart';
import 'package:jackdaw/features/pages/folder_index.dart';
import 'package:jackdaw/features/pages/page_view_screen.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_screen.dart';

class MockPagesApi extends Mock implements PagesApi {}

class MockTreeApi extends Mock implements TreeApi {}

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/tree/$name.json').readAsStringSync())
        as Map<String, dynamic>;

const pageId = '709ca7ce-c3dc-4ad0-a444-313fbb59e643';
const acme = '26190ec8-d7cf-4959-911d-133cc1b2abab';
const engineering = 'cebf879e-8209-465f-9051-4cf252188877';

TreeFolderPage folderPage(String id, String name, List<String> titles) =>
    TreeFolderPage.fromJson({
      'kind': 'pages',
      'folder': {'id': id, 'name': name, 'path': 'pages.x', 'depth': 1},
      'crumbs': <Object>[],
      'folders': <Object>[],
      'items': [
        for (final t in titles)
          {'id': 'id-$t', 'title': t, 'updatedAt': '2026-10-01T08:00:00.000Z'},
      ],
      'sort': 'name',
      'nextCursor': null,
    });

void main() {
  final markdown =
      File('test/fixtures/tree/page_folder_index.md').readAsStringSync();
  final detail = fixture('page_detail')['page'] as Map<String, dynamic>;

  group('the syntax', () {
    List<md.Node> parse(String text) => md.Document(
          blockSyntaxes: const [FolderIndexSyntax()],
          inlineSyntaxes: [RefInlineSyntax()],
        ).parse(text);

    test('a line of its own is the block, for an id and for here', () {
      final nodes = parse(markdown).whereType<md.Element>().toList();
      final blocks = nodes.where((n) => n.tag == kFolderIndexTag).toList();

      expect(blocks.map((b) => b.attributes['folder']),
          [kFolderHere, engineering]);
      expect(blocks.first.attributes['label'], 'Folder index');
    });

    test('the same link inside a sentence is its plain label', () {
      final nodes = parse('see [the index](folder:f-3) here');
      final para = nodes.single as md.Element;

      expect(para.tag, 'p');
      expect(para.textContent, 'see the index here');
      expect(para.children!.whereType<md.Element>(), isEmpty);
    });
  });

  group('in the page viewer', () {
    late MockPagesApi pages;
    late MockTreeApi tree;

    setUpAll(() {
      registerFallbackValue(TreeKind.pages);
      registerFallbackValue(TreeSort.name);
    });

    setUp(() {
      pages = MockPagesApi();
      tree = MockTreeApi();
      when(() => pages.backlinks(any())).thenAnswer((_) async => const []);
      when(() => pages.markdown(pageId)).thenAnswer((_) async => markdown);
    });

    Future<void> pump(WidgetTester tester, Map<String, dynamic> page) async {
      when(() => pages.meta(pageId))
          .thenAnswer((_) async => PageRow.fromJson(page));
      await pumpScreen(
        tester,
        const PageViewScreen(pageId: pageId),
        container: ProviderContainer(overrides: [
          pagesApiProvider.overrideWithValue(pages),
          treeApiProvider.overrideWithValue(tree),
        ]),
      );
    }

    testWidgets('lists the page\'s own folder and the named one, by name',
        (tester) async {
      when(() => tree.folder(TreeKind.pages,
              folderId: acme, sort: TreeSort.name))
          .thenAnswer((_) async =>
              folderPage(acme, 'Acme Corp', ['Acme folder index', 'Kickoff']));
      when(() => tree.folder(TreeKind.pages,
              folderId: engineering, sort: TreeSort.name))
          .thenAnswer((_) async => folderPage(
              engineering, 'Engineering', ['Engineering handbook']));
      await pump(tester, detail);

      expect(find.byType(FolderIndexBlock), findsNWidgets(2));
      expect(find.text('In Acme Corp'), findsOneWidget);
      expect(find.text('Kickoff'), findsOneWidget);
      expect(find.text('In Engineering'), findsOneWidget);
      expect(find.text('Engineering handbook'), findsOneWidget);
      expect(find.bySemanticsLabel('Open page Kickoff'), findsOneWidget);
      // Never the raw round-trip syntax.
      expect(find.textContaining('folder:'), findsNothing);
    });

    testWidgets('a page at the top level lists the top level', (tester) async {
      when(() => tree.folder(TreeKind.pages, sort: TreeSort.name)).thenAnswer(
        (_) async => TreeFolderPage.fromJson({
          ...fixture('tree_pages_root'),
        }),
      );
      when(() => tree.folder(TreeKind.pages,
              folderId: engineering, sort: TreeSort.name))
          .thenAnswer((_) async => folderPage(engineering, 'Engineering', []));
      await pump(tester, {...detail, 'folderId': null});

      expect(find.text('In Pages'), findsOneWidget);
      expect(find.text('Quarterly goals'), findsOneWidget);
      expect(find.text('No pages here yet.'), findsOneWidget);
    });

    testWidgets('a brain that does not say the folder shows the label alone',
        (tester) async {
      when(() => tree.folder(TreeKind.pages,
              folderId: engineering, sort: TreeSort.name))
          .thenAnswer((_) async => folderPage(
              engineering, 'Engineering', ['Engineering handbook']));
      await pump(tester, Map.of(detail)..remove('folderId'));

      // `here` is not known: its label, and no request for the root.
      expect(find.text('Folder index'), findsOneWidget);
      verifyNever(() => tree.folder(TreeKind.pages, sort: TreeSort.name));
      // The block that names a folder still lists it.
      expect(find.text('Engineering handbook'), findsOneWidget);
    });

    testWidgets('a folder the reader cannot open says so', (tester) async {
      when(() => tree.folder(TreeKind.pages,
          folderId: acme,
          sort: TreeSort.name)).thenThrow(const TreeFolderMissing());
      when(() => tree.folder(TreeKind.pages,
          folderId: engineering,
          sort: TreeSort.name)).thenThrow(Exception('offline'));
      await pump(tester, detail);

      expect(find.text('This folder is not shared with you.'), findsOneWidget);
      expect(find.text('Could not load this folder.'), findsOneWidget);
    });

    testWidgets('a brain with no tree shows both labels and nothing else',
        (tester) async {
      when(() => tree.folder(TreeKind.pages,
          folderId: any(named: 'folderId'),
          sort: TreeSort.name)).thenThrow(const TreeUnavailable());
      await pump(tester, detail);

      expect(find.text('Folder index'), findsNWidgets(2));
      expect(find.textContaining('Could not load'), findsNothing);
    });
  });
}
