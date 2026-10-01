// The folder browser as the three screens use it: folders first, drilling
// and the trail, search and Recent with where each hit lives, capturing a
// note into the open folder, and the list a brain older than the tree gets.
// Tree responses are the real ones in test/fixtures/tree/.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/files/files_api.dart';
import 'package:jackdaw/data/notes/notes_api.dart';
import 'package:jackdaw/data/notes/notes_models.dart';
import 'package:jackdaw/data/pages/pages_api.dart';
import 'package:jackdaw/data/pages/pages_models.dart';
import 'package:jackdaw/data/tree/tree_api.dart';
import 'package:jackdaw/data/tree/tree_models.dart';
import 'package:jackdaw/features/files/files_screen.dart';
import 'package:jackdaw/features/notes/notes_screen.dart';
import 'package:jackdaw/features/pages/pages_screen.dart';
import 'package:jackdaw/features/tree/tree_rows.dart';
import 'package:jackdaw/features/voice/voice_capture.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../helpers/pump_screen.dart';

class MockTreeApi extends Mock implements TreeApi {}

class MockPagesApi extends Mock implements PagesApi {}

class MockNotesApi extends Mock implements NotesApi {}

class MockFilesApi extends Mock implements FilesApi {}

/// No speech-to-text in a widget test: the capture field is then a plain
/// input, and no recorder plugin is touched.
class SttDown extends SttAvailability {
  @override
  bool build() => false;
}

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/tree/$name.json').readAsStringSync())
        as Map<String, dynamic>;

TreeFolderPage page(String name) => TreeFolderPage.fromJson(fixture(name));

const clients = '8da11d85-78e6-46e9-a27b-334812cd19fd';
const acme = '26190ec8-d7cf-4959-911d-133cc1b2abab';
const contracts = 'ec345602-6749-4e1b-8574-226266655b97';

void main() {
  late MockTreeApi tree;
  late MockPagesApi pages;
  late MockNotesApi notes;
  late MockFilesApi files;

  setUpAll(() {
    registerFallbackValue(TreeKind.pages);
    registerFallbackValue(TreeMarkView.recent);
  });

  setUp(() {
    tree = MockTreeApi();
    pages = MockPagesApi();
    notes = MockNotesApi();
    files = MockFilesApi();
    when(() => tree.opened(any())).thenAnswer((_) async {});
    when(() => tree.tags(any())).thenAnswer((_) async => const []);
  });

  Future<void> pump(WidgetTester tester, Widget screen) => pumpScreen(
        tester,
        screen,
        container: ProviderContainer(overrides: [
          treeApiProvider.overrideWithValue(tree),
          pagesApiProvider.overrideWithValue(pages),
          notesApiProvider.overrideWithValue(notes),
          filesApiProvider.overrideWithValue(files),
          sttAvailabilityProvider.overrideWith(SttDown.new),
        ]),
      );

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  group('Pages', () {
    setUp(() {
      when(() => tree.folder(TreeKind.pages))
          .thenAnswer((_) async => page('tree_pages_root'));
    });

    testWidgets('opens on Folders: folders first, then pages', (tester) async {
      await pump(tester, const PagesScreen());

      expect(find.byType(TreeFolderTile), findsNWidgets(3));
      expect(find.byType(TreeItemTile), findsNWidgets(2));
      // Every folder sits above every page.
      expect(top(tester, 'Engineering'), lessThan(top(tester, 'Quarterly goals')));
      // What a folder holds, and who it is shared with.
      expect(find.text('60 items'), findsOneWidget);
      expect(find.text('1 folder · 1 item'), findsOneWidget);
      expect(find.text('Clients'), findsNWidgets(2)); // the name and the badge
      expect(find.text('Team'), findsOneWidget);
      // At the root there is no trail.
      expect(find.byType(TreeCrumbBar), findsNothing);
    });

    testWidgets('a folder draws its own icon and tint', (tester) async {
      await pump(tester, const PagesScreen());

      final glyphs =
          tester.widgetList<FolderGlyph>(find.byType(FolderGlyph)).toList();
      expect(glyphs.map((g) => g.icon), [null, 'lucide:briefcase', '🚀']);
      expect(glyphs.map((g) => g.color), [null, 'blue', 'violet']);
      expect(find.byIcon(LucideIcons.briefcase), findsOneWidget);
      expect(find.text('🚀'), findsOneWidget);
      expect(find.byIcon(LucideIcons.folder), findsOneWidget);
    });

    testWidgets('drilling in shows the folder and a trail back out',
        (tester) async {
      when(() => tree.folder(TreeKind.pages, folderId: contracts))
          .thenAnswer((_) async => page('tree_pages_folder_depth3'));
      when(() => tree.folder(TreeKind.pages, folderId: acme)).thenAnswer(
        (_) async => TreeFolderPage.fromJson({
          ...fixture('tree_pages_folder_depth3'),
          'folder': {
            'id': acme,
            'name': 'Acme Corp',
            'path': 'pages.clients.acme_corp',
            'depth': 2,
          },
          'crumbs': [
            {'id': clients, 'name': 'Clients'},
          ],
          'folders': <Object>[],
          'items': <Object>[],
        }),
      );
      await pump(tester, const PagesScreen(folderId: contracts));

      // Header and the end of the trail both name the open folder. A long
      // trail starts scrolled to its end, so the nearest steps are in reach.
      expect(find.text('Contracts'), findsNWidgets(2));
      expect(find.bySemanticsLabel('Go to Acme Corp'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Go to Acme Corp'));
      await tester.pumpAndSettle();
      expect(find.text('Acme Corp'), findsNWidgets(2));
      expect(find.text('No pages here.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Go to Pages'));
      await tester.pumpAndSettle();
      expect(find.byType(TreeCrumbBar), findsNothing);
      expect(find.text('Quarterly goals'), findsOneWidget);
    });

    testWidgets('tapping a folder opens it; Back climbs out', (tester) async {
      when(() => tree.folder(TreeKind.pages, folderId: clients)).thenAnswer(
        (_) async => TreeFolderPage.fromJson({
          ...fixture('tree_pages_root'),
          'folder': {'id': clients, 'name': 'Clients', 'path': 'pages.clients'},
          'folders': <Object>[],
          'items': <Object>[],
        }),
      );
      await pump(tester, const PagesScreen());

      await tester.tap(find.bySemanticsLabel('Open folder Clients'));
      await tester.pumpAndSettle();
      expect(find.byType(TreeCrumbBar), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(TreeCrumbBar), findsNothing);
      expect(find.text('Archive'), findsOneWidget);
    });

    testWidgets('search lists hits with the folder each lives in',
        (tester) async {
      when(() => tree.search(TreeKind.pages, 'engineering')).thenAnswer(
        (_) async => TreeSearchResult.fromJson(fixture('tree_pages_search')),
      );
      await pump(tester, const PagesScreen());

      await tester.enterText(find.byType(ShadInput), 'engineering');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Engineering handbook'), findsOneWidget);
      // The hit's folder path, under its title.
      expect(find.text('Engineering'), findsNWidgets(3));
      expect(find.text('Quarterly goals'), findsNothing);
    });

    testWidgets('Recent is one tap away and says where each page lives',
        (tester) async {
      when(() => tree.marks(TreeKind.pages, TreeMarkView.recent)).thenAnswer(
        (_) async => TreeMarkList.fromJson(fixture('tree_pages_marks_recent')),
      );
      await pump(tester, const PagesScreen());

      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      expect(find.text('Acme folder index'), findsOneWidget);
      expect(find.text('Clients › Acme Corp'), findsOneWidget);

      await tester.tap(find.text('Folders'));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsOneWidget);
    });

    testWidgets('a folder that is gone says so and offers the top level',
        (tester) async {
      when(() => tree.folder(TreeKind.pages, folderId: 'gone'))
          .thenThrow(const TreeFolderMissing());
      await pump(tester, const PagesScreen(folderId: 'gone'));

      expect(find.text('This folder is not here any more.'), findsOneWidget);
      await tester.tap(find.text('Go to Pages'));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsOneWidget);
    });

    testWidgets('a brain older than the tree gets the flat list it had',
        (tester) async {
      when(() => tree.folder(TreeKind.pages)).thenThrow(const TreeUnavailable());
      when(() => pages.list()).thenAnswer(
        (_) async => PagesIndex(
          pages: [
            PageRow(
              id: 'p1',
              title: 'An old page',
              icon: null,
              tags: const [],
              summary: null,
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          ],
          total: 1,
        ),
      );
      await pump(tester, const PagesScreen());

      expect(find.text('An old page'), findsOneWidget);
      expect(find.text('Folders'), findsNothing);
      // It asked once, and does not keep asking.
      verify(() => tree.folder(TreeKind.pages)).called(1);
    });
  });

  group('Notes', () {
    const ideas = '4aa61ac5-44d1-4bfa-8da7-c3bc77918ff5';

    NoteRow saved(String id) => NoteRow(
          id: id,
          title: 'A thought',
          content: '',
          tags: const [],
          summary: null,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );

    setUp(() {
      when(() => tree.folder(TreeKind.notes))
          .thenAnswer((_) async => page('tree_notes_root'));
      when(() => tree.folder(TreeKind.notes, folderId: ideas))
          .thenAnswer((_) async => page('tree_notes_folder_shared_team'));
      when(() => tree.tags(TreeKind.notes)).thenAnswer(
        (_) async => TreeTag.listFrom(fixture('tree_notes_tags')),
      );
    });

    testWidgets('shows the tags as filter pills', (tester) async {
      await pump(tester, const NotesScreen());

      expect(find.text('meeting 5'), findsOneWidget);
    });

    testWidgets('captures at the top level without a move', (tester) async {
      when(() => notes.create('A thought')).thenAnswer((_) async => saved('n1'));
      await pump(tester, const NotesScreen());

      await tester.enterText(find.byType(ShadInput).last, 'A thought');
      await tester.tap(find.bySemanticsLabel('Add note'));
      await tester.pumpAndSettle();

      verify(() => notes.create('A thought')).called(1);
      verifyNever(() => tree.move(any(), any(), any()));
    });

    testWidgets('captures into the open folder; a shared one asks first',
        (tester) async {
      final refusal =
          TreeVisibilityRefusal.tryParse(fixture('tree_move_visibility_409'))!;
      when(() => notes.create('A thought')).thenAnswer((_) async => saved('n1'));
      when(() => tree.move(TreeKind.notes, ['n1'], ideas)).thenThrow(refusal);
      when(() => tree.move(TreeKind.notes, ['n1'], ideas,
          confirm: true, seen: 1)).thenAnswer((_) async => const []);
      await pump(tester, const NotesScreen(folderId: ideas));

      expect(find.text('Capture a note in Ideas…'), findsOneWidget);
      await tester.enterText(find.byType(ShadInput).last, 'A thought');
      await tester.tap(find.bySemanticsLabel('Add note'));
      await tester.pumpAndSettle();

      // Nothing is filed until the person has read who will see it.
      expect(find.text('File it in a shared folder?'), findsOneWidget);
      expect(find.textContaining('readable by the team'), findsOneWidget);
      verifyNever(() => tree.move(TreeKind.notes, ['n1'], ideas,
          confirm: true, seen: 1));

      await tester.tap(find.text('File it here'));
      await tester.pumpAndSettle();

      verify(() => tree.move(TreeKind.notes, ['n1'], ideas,
          confirm: true, seen: 1)).called(1);
    });

    testWidgets('saying no leaves the note at the top level, and says so',
        (tester) async {
      final refusal =
          TreeVisibilityRefusal.tryParse(fixture('tree_move_visibility_409'))!;
      when(() => notes.create('A thought')).thenAnswer((_) async => saved('n1'));
      when(() => tree.move(TreeKind.notes, ['n1'], ideas)).thenThrow(refusal);
      await pump(tester, const NotesScreen(folderId: ideas));

      await tester.enterText(find.byType(ShadInput).last, 'A thought');
      await tester.tap(find.bySemanticsLabel('Add note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.text('Saved at the top level, not in this folder.'),
        findsOneWidget,
      );
      verifyNever(() => tree.move(TreeKind.notes, ['n1'], ideas,
          confirm: true, seen: 1));
    });

    // M6: the note exists; the screen must say where, and must not keep the
    // text for a retry that would make a second note.
    for (final (label, stub) in [
      (
        'the move fails',
        () => when(() => tree.move(TreeKind.notes, ['n1'], ideas))
            .thenThrow(Exception('offline')),
      ),
      (
        'the move answers the note as failed',
        () => when(() => tree.move(TreeKind.notes, ['n1'], ideas))
            .thenAnswer((_) async => const ['n1']),
      ),
    ]) {
      testWidgets('saved but not filed when $label: it says so and clears '
          'the text', (tester) async {
        when(() => notes.create('A thought'))
            .thenAnswer((_) async => saved('n1'));
        stub();
        await pump(tester, const NotesScreen(folderId: ideas));

        await tester.enterText(find.byType(ShadInput).last, 'A thought');
        await tester.tap(find.bySemanticsLabel('Add note'));
        await tester.pumpAndSettle();

        expect(
          find.text('Saved at the top level: it could not be filed here.'),
          findsOneWidget,
        );
        expect(find.text("Couldn't add the note."), findsNothing);
        expect(find.text('A thought'), findsNothing);
        verify(() => notes.create('A thought')).called(1);
      });
    }
  });

  group('Files', () {
    testWidgets('lists folders and files, with the upload row on top',
        (tester) async {
      when(() => tree.folder(TreeKind.files))
          .thenAnswer((_) async => page('tree_files_root'));
      await pump(tester, const FilesScreen());

      expect(find.bySemanticsLabel('Upload a document'), findsOneWidget);
      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.byType(TreeItemTile), findsWidgets);
    });

    testWidgets('a brain older than the tree gets the old folder screen',
        (tester) async {
      when(() => tree.folder(TreeKind.files)).thenThrow(const TreeUnavailable());
      when(() => files.folders('files')).thenAnswer((_) async => const []);
      when(() => files.files('files')).thenAnswer((_) async => const []);
      await pump(tester, const FilesScreen());

      expect(find.text('Nothing here yet. Upload something above.'),
          findsOneWidget);
      verify(() => files.folders('files')).called(1);
    });
  });
}
