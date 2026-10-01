// The folder tree's controllers: paging by cursor, a refresh that keeps the
// rows on screen, the older-brain marker, search that never shows a stale
// answer, and capturing a note into the open folder.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/notes/notes_api.dart';
import 'package:jackdaw/data/notes/notes_models.dart';
import 'package:jackdaw/data/tree/tree_api.dart';
import 'package:jackdaw/data/tree/tree_models.dart';
import 'package:jackdaw/features/notes/notes_controller.dart';
import 'package:jackdaw/features/pages/pages_controller.dart';
import 'package:jackdaw/features/tree/tree_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockTreeApi extends Mock implements TreeApi {}

class MockNotesApi extends Mock implements NotesApi {}

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/tree/$name.json').readAsStringSync())
        as Map<String, dynamic>;

TreeFolderPage page(String name) => TreeFolderPage.fromJson(fixture(name));

const archive = '16b94e03-c2f8-443c-bf24-d5671ecbba5f';

void main() {
  late MockTreeApi api;
  late MockNotesApi notes;

  setUpAll(() {
    registerFallbackValue(TreeKind.pages);
    registerFallbackValue(TreeMarkView.recent);
  });

  setUp(() {
    api = MockTreeApi();
    notes = MockNotesApi();
  });

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        treeApiProvider.overrideWithValue(api),
        notesApiProvider.overrideWithValue(notes),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('a folder', () {
    test('loads its subfolders and the first page of items', () async {
      when(() => api.folder(TreeKind.pages))
          .thenAnswer((_) async => page('tree_pages_root'));
      final c = make();
      c.listen(treeFolderControllerProvider(TreeKind.pages, null), (_, _) {});

      final state =
          await c.read(treeFolderControllerProvider(TreeKind.pages, null).future);

      expect(state.folder, isNull);
      expect(state.folders, hasLength(3));
      expect(state.items, hasLength(2));
      expect(state.hasMore, isFalse);
    });

    test('loadMore appends by cursor and keeps the subfolders', () async {
      final p1 = page('tree_pages_archive_p1');
      when(() => api.folder(TreeKind.pages, folderId: archive))
          .thenAnswer((_) async => p1);
      when(() => api.folder(TreeKind.pages,
              folderId: archive, cursor: p1.nextCursor))
          .thenAnswer((_) async => page('tree_pages_archive_p2'));
      final c = make();
      final provider = treeFolderControllerProvider(TreeKind.pages, archive);
      c.listen(provider, (_, _) {});
      await c.read(provider.future);

      await c.read(provider.notifier).loadMore();
      final state = c.read(provider).value!;

      expect(state.items, hasLength(60));
      expect({for (final i in state.items) i.id}, hasLength(60));
      expect(state.hasMore, isFalse);
      expect(state.loadingMore, isFalse);
      expect(state.folder!.name, 'Archive');

      // At the end, another call asks nothing.
      await c.read(provider.notifier).loadMore();
      verify(() => api.folder(TreeKind.pages,
          folderId: archive, cursor: p1.nextCursor)).called(1);
    });

    test('a failed loadMore keeps what is there and can be tried again',
        () async {
      final p1 = page('tree_pages_archive_p1');
      when(() => api.folder(TreeKind.pages, folderId: archive))
          .thenAnswer((_) async => p1);
      when(() => api.folder(TreeKind.pages,
          folderId: archive,
          cursor: p1.nextCursor)).thenThrow(Exception('offline'));
      final c = make();
      final provider = treeFolderControllerProvider(TreeKind.pages, archive);
      c.listen(provider, (_, _) {});
      await c.read(provider.future);

      await c.read(provider.notifier).loadMore();
      final state = c.read(provider).value!;

      expect(state.items, hasLength(50));
      expect(state.hasMore, isTrue);
      expect(state.loadingMore, isFalse);
    });

    test('refresh keeps the rows on screen while it asks, and after a failure',
        () async {
      var calls = 0;
      final second = Completer<TreeFolderPage>();
      when(() => api.folder(TreeKind.pages)).thenAnswer((_) {
        calls++;
        return calls == 1
            ? Future.value(page('tree_pages_root'))
            : second.future;
      });
      final c = make();
      final provider = treeFolderControllerProvider(TreeKind.pages, null);
      c.listen(provider, (_, _) {});
      await c.read(provider.future);

      final refreshing = c.read(provider.notifier).refresh();
      expect(c.read(provider).value!.items, hasLength(2));
      second.completeError(Exception('offline'));
      await refreshing;

      expect(c.read(provider).hasError, isFalse);
      expect(c.read(provider).value!.items, hasLength(2));
    });

    test('a refresh that lands after the screen is gone does not throw',
        () async {
      var calls = 0;
      final second = Completer<TreeFolderPage>();
      when(() => api.folder(TreeKind.pages)).thenAnswer((_) {
        calls++;
        return calls == 1
            ? Future.value(page('tree_pages_root'))
            : second.future;
      });
      final c = make();
      final provider = treeFolderControllerProvider(TreeKind.pages, null);
      final sub = c.listen(provider, (_, _) {});
      await c.read(provider.future);

      final refreshing = c.read(provider.notifier).refresh();
      sub.close();
      await Future<void>.delayed(Duration.zero);
      second.complete(page('tree_pages_root'));

      await expectLater(refreshing, completes);
    });

    test('removeItem takes the row out at once', () async {
      when(() => api.folder(TreeKind.pages))
          .thenAnswer((_) async => page('tree_pages_root'));
      final c = make();
      final provider = treeFolderControllerProvider(TreeKind.pages, null);
      c.listen(provider, (_, _) {});
      final before = await c.read(provider.future);

      c.read(provider.notifier).removeItem(before.items.first.id);

      expect(c.read(provider).value!.items.single.id, before.items.last.id);
    });

    test('a brain older than the tree is remembered for the kind', () async {
      when(() => api.folder(TreeKind.pages)).thenThrow(const TreeUnavailable());
      when(() => api.folder(TreeKind.notes))
          .thenAnswer((_) async => page('tree_notes_root'));
      final c = make();
      c.listen(treeUnavailableKindsProvider, (_, _) {});
      final provider = treeFolderControllerProvider(TreeKind.pages, null);
      c.listen(provider, (_, _) {});

      await expectLater(c.read(provider.future), throwsA(isA<TreeUnavailable>()));

      expect(c.read(treeUnavailableKindsProvider), {TreeKind.pages});
    });

    test('a folder that is gone is not "no tree"', () async {
      when(() => api.folder(TreeKind.pages, folderId: 'gone'))
          .thenThrow(const TreeFolderMissing());
      final c = make();
      c.listen(treeUnavailableKindsProvider, (_, _) {});
      final provider = treeFolderControllerProvider(TreeKind.pages, 'gone');
      c.listen(provider, (_, _) {});

      await expectLater(
          c.read(provider.future), throwsA(isA<TreeFolderMissing>()));

      expect(c.read(treeUnavailableKindsProvider), isEmpty);
    });
  });

  group('search', () {
    final found = TreeSearchResult.fromJson(fixture('tree_pages_search'));

    test('finds folders and items, each with where it lives', () async {
      when(() => api.search(TreeKind.pages, 'engineering'))
          .thenAnswer((_) async => found);
      final c = make();
      final provider = treeSearchControllerProvider(TreeKind.pages);
      c.listen(provider, (_, _) {});

      c.read(provider.notifier).onQueryChanged(' engineering ');
      expect(c.read(provider).searching, isTrue);
      await c.read(provider.notifier).searchNow();

      final state = c.read(provider);
      expect(state.active, isTrue);
      expect(state.searching, isFalse);
      expect(state.folders.single.name, 'Engineering');
      expect(state.items.first.crumbs.single.name, 'Engineering');
    });

    test('an answer for words since replaced is dropped', () async {
      final slow = Completer<TreeSearchResult>();
      when(() => api.search(TreeKind.pages, 'eng'))
          .thenAnswer((_) => slow.future);
      final c = make();
      final provider = treeSearchControllerProvider(TreeKind.pages);
      c.listen(provider, (_, _) {});

      c.read(provider.notifier).onQueryChanged('eng');
      final running = c.read(provider.notifier).searchNow();
      c.read(provider.notifier).onQueryChanged('');
      slow.complete(found);
      await running;

      expect(c.read(provider).active, isFalse);
      expect(c.read(provider).items, isEmpty);
    });

    test('a tag narrows with no words typed; clearing it leaves search',
        () async {
      when(() => api.search(TreeKind.notes, '', tag: 'idea')).thenAnswer(
        (_) async => const TreeSearchResult(
          folders: [],
          items: [],
          nextCursor: null,
        ),
      );
      final c = make();
      final provider = treeSearchControllerProvider(TreeKind.notes);
      c.listen(provider, (_, _) {});

      await c.read(provider.notifier).setTag('idea');
      expect(c.read(provider).active, isTrue);
      expect(c.read(provider).tag, 'idea');

      await c.read(provider.notifier).setTag(null);
      expect(c.read(provider).active, isFalse);
    });

    test('a failure says so and can be retried', () async {
      when(() => api.search(TreeKind.pages, 'x'))
          .thenThrow(Exception('offline'));
      final c = make();
      final provider = treeSearchControllerProvider(TreeKind.pages);
      c.listen(provider, (_, _) {});

      c.read(provider.notifier).onQueryChanged('x');
      await c.read(provider.notifier).searchNow();

      expect(c.read(provider).failed, isTrue);
      expect(c.read(provider).active, isTrue);
    });
  });

  group('capturing a note', () {
    NoteRow note(String id) => NoteRow(
          id: id,
          title: 'Idea',
          content: '',
          tags: const [],
          summary: null,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );

    test('at the top level is a create and nothing else', () async {
      when(() => notes.create('Idea')).thenAnswer((_) async => note('n1'));
      final c = make();

      final saved = await c.read(noteFilingProvider).capture(' Idea ');

      expect(saved.id, 'n1');
      verifyNever(() => api.move(any(), any(), any()));
    });

    test('into a folder is a create, then the move', () async {
      when(() => notes.create('Idea')).thenAnswer((_) async => note('n1'));
      when(() => api.move(TreeKind.notes, ['n1'], 'f1'))
          .thenAnswer((_) async => const []);
      final c = make();

      await c.read(noteFilingProvider).capture('Idea', folderId: 'f1');

      verify(() => api.move(TreeKind.notes, ['n1'], 'f1')).called(1);
    });

    test('into a shared folder waits for a yes, then says what was seen',
        () async {
      final refusal =
          TreeVisibilityRefusal.tryParse(fixture('tree_move_visibility_409'))!;
      when(() => notes.create('Idea')).thenAnswer((_) async => note('n1'));
      when(() => api.move(TreeKind.notes, ['n1'], 'f1')).thenThrow(refusal);
      when(() => api.move(TreeKind.notes, ['n1'], 'f1',
          confirm: true, seen: 1)).thenAnswer((_) async => const []);
      final c = make();
      final filing = c.read(noteFilingProvider);

      NoteNeedsConfirm? pending;
      try {
        await filing.capture('Idea', folderId: 'f1');
      } on NoteNeedsConfirm catch (e) {
        pending = e;
      }

      expect(pending!.note.id, 'n1');
      expect(pending.refusal.to, 'team');

      await filing.fileConfirmed('n1', 'f1', pending.refusal);
      verify(() => api.move(TreeKind.notes, ['n1'], 'f1',
          confirm: true, seen: 1)).called(1);
    });
  });

  group('capturing a note: the move fails (M6)', () {
    NoteRow note(String id) => NoteRow(
          id: id,
          title: 'Idea',
          content: '',
          tags: const [],
          summary: null,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );

    test('a failed move is "saved, not filed", with the note', () async {
      when(() => notes.create('Idea')).thenAnswer((_) async => note('n1'));
      when(() => api.move(TreeKind.notes, ['n1'], 'f1'))
          .thenThrow(Exception('offline'));
      final c = make();

      await expectLater(
        c.read(noteFilingProvider).capture('Idea', folderId: 'f1'),
        throwsA(isA<NoteNotFiled>().having((e) => e.note?.id, 'note', 'n1')),
      );
    });

    test("the move's failed ids are read, not ignored", () async {
      when(() => notes.create('Idea')).thenAnswer((_) async => note('n1'));
      when(() => api.move(TreeKind.notes, ['n1'], 'f1'))
          .thenAnswer((_) async => const ['n1']);
      final c = make();

      await expectLater(
        c.read(noteFilingProvider).capture('Idea', folderId: 'f1'),
        throwsA(isA<NoteNotFiled>()),
      );
    });

    test('a confirmed move that fails for the note says so', () async {
      final refusal =
          TreeVisibilityRefusal.tryParse(fixture('tree_move_visibility_409'))!;
      when(() => api.move(TreeKind.notes, ['n1'], 'f1',
          confirm: true, seen: 1)).thenAnswer((_) async => const ['n1']);
      final c = make();

      await expectLater(
        c.read(noteFilingProvider).fileConfirmed('n1', 'f1', refusal),
        throwsA(isA<NoteNotFiled>()),
      );
    });

    test('a failed create is not "saved"', () async {
      when(() => notes.create('Idea')).thenThrow(Exception('offline'));
      final c = make();

      await expectLater(
        c.read(noteFilingProvider).capture('Idea', folderId: 'f1'),
        throwsA(isNot(isA<NoteNotFiled>())),
      );
    });
  });

  group('a Folder index', () {
    test('reads the whole folder by name, page after page', () async {
      final p1 = page('tree_pages_archive_p1');
      when(() => api.folder(TreeKind.pages,
          folderId: archive,
          sort: TreeSort.name)).thenAnswer((_) async => p1);
      when(() => api.folder(TreeKind.pages,
              folderId: archive, sort: TreeSort.name, cursor: p1.nextCursor))
          .thenAnswer((_) async => page('tree_pages_archive_p2'));
      final c = make();

      final index = await c.read(folderIndexProvider(archive).future);

      expect(index.folder!.name, 'Archive');
      expect(index.items, hasLength(60));
      expect(index.more, isFalse);
    });

    test('stops at the cap and says the list was cut', () async {
      final p1 = page('tree_pages_archive_p1');
      when(() => api.folder(
            TreeKind.pages,
            folderId: archive,
            sort: TreeSort.name,
            cursor: any(named: 'cursor'),
          )).thenAnswer((_) async => p1);
      final c = make();

      final index = await c.read(folderIndexProvider(archive).future);

      expect(index.more, isTrue);
      expect(index.items, hasLength(50 * kFolderIndexMaxPages));
    });
  });
}
