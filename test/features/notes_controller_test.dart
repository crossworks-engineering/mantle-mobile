// NotesController: list + tag filter + paging + optimistic add/delete.
// Plus NoteRow/NotesPage model parsing.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/notes/notes_api.dart';
import 'package:jackdaw/data/notes/notes_models.dart';
import 'package:jackdaw/features/notes/notes_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockNotesApi extends Mock implements NotesApi {}

NoteRow note(String id, {String? title, List<String> tags = const []}) {
  return NoteRow(
    id: id,
    title: title ?? 'Note $id',
    content: 'content $id',
    tags: tags,
    summary: null,
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 2),
  );
}

NotesPage pageOf(List<NoteRow> notes,
    {int? total, List<NoteTag> tags = const [], int page = 1}) {
  return NotesPage(
    notes: notes,
    total: total ?? notes.length,
    page: page,
    pageSize: 50,
    tags: tags,
  );
}

void main() {
  late MockNotesApi api;
  setUp(() => api = MockNotesApi());

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [notesApiProvider.overrideWithValue(api)],
    );
    addTearDown(c.dispose);
    c.listen(notesControllerProvider, (_, _) {});
    return c;
  }

  test('loads first page with tag facets', () async {
    when(() => api.list(tag: null)).thenAnswer(
      (_) async => pageOf([note('a'), note('b')],
          tags: const [NoteTag(tag: 'work', count: 2)]),
    );

    final c = make();
    final s = await c.read(notesControllerProvider.future);

    expect(s.notes.map((n) => n.id), ['a', 'b']);
    expect(s.tags.single.tag, 'work');
    expect(s.hasMore, isFalse);
  });

  test('setTag reloads scoped to the tag', () async {
    when(() => api.list(tag: null)).thenAnswer((_) async => pageOf([note('a')]));
    when(() => api.list(tag: 'work')).thenAnswer(
      (_) async => pageOf([note('w', tags: const ['work'])]),
    );

    final c = make();
    await c.read(notesControllerProvider.future);
    await c.read(notesControllerProvider.notifier).setTag('work');

    final s = c.read(notesControllerProvider).value!;
    expect(s.tag, 'work');
    expect(s.notes.single.id, 'w');
  });

  test('add prepends when unfiltered', () async {
    when(() => api.list(tag: null)).thenAnswer((_) async => pageOf([note('a')]));
    when(() => api.create('hello')).thenAnswer((_) async => note('new', title: 'hello'));

    final c = make();
    await c.read(notesControllerProvider.future);
    await c.read(notesControllerProvider.notifier).add('hello');

    final s = c.read(notesControllerProvider).value!;
    expect(s.notes.first.id, 'new');
    expect(s.total, 2);
  });

  test('add with an active tag filter resets to all so the note is visible',
      () async {
    when(() => api.list(tag: null)).thenAnswer(
      (_) async => pageOf([note('a'), note('new', title: 'hello')]),
    );
    when(() => api.list(tag: 'work')).thenAnswer(
      (_) async => pageOf([note('w', tags: const ['work'])]),
    );
    when(() => api.create('hello')).thenAnswer((_) async => note('new', title: 'hello'));

    final c = make();
    await c.read(notesControllerProvider.future);
    await c.read(notesControllerProvider.notifier).setTag('work');
    await c.read(notesControllerProvider.notifier).add('hello');

    final s = c.read(notesControllerProvider).value!;
    expect(s.tag, isNull);
    expect(s.notes.map((n) => n.id), contains('new'));
  });

  test('delete is optimistic; a failure reloads from the server', () async {
    var calls = 0;
    when(() => api.list(tag: null)).thenAnswer((_) async {
      calls++;
      return pageOf([note('a'), note('b')]);
    });
    when(() => api.delete('a')).thenThrow(Exception('offline'));

    final c = make();
    await c.read(notesControllerProvider.future);
    await c.read(notesControllerProvider.notifier).delete('a');

    // Rolled back by the silent reload (list called again).
    final s = c.read(notesControllerProvider).value!;
    expect(calls, 2);
    expect(s.notes.map((n) => n.id), ['a', 'b']);
  });

  test('loadMore pages by counter (a local delete cannot desync the cursor) '
      'and rebases on the live state', () async {
    final first = List.generate(50, (i) => note('n$i'));
    when(() => api.list(tag: null)).thenAnswer(
      (_) async => pageOf(first, total: 60),
    );
    when(() => api.delete('n0')).thenAnswer((_) async {});
    final page2 = Completer<NotesPage>();
    when(() => api.list(page: 2, tag: null)).thenAnswer((_) => page2.future);

    final c = make();
    await c.read(notesControllerProvider.future);
    final notifier = c.read(notesControllerProvider.notifier);
    final loading = notifier.loadMore(); // page 2 in flight
    await notifier.delete('n0'); // optimistic delete mid-fetch
    page2.complete(pageOf([note('x1')], total: 60, page: 2));
    await loading;

    final s = c.read(notesControllerProvider).value!;
    expect(s.notes.map((n) => n.id), isNot(contains('n0'))); // not resurrected
    expect(s.notes.map((n) => n.id), contains('x1'));
    expect(s.page, 2);
    verify(() => api.list(page: 2, tag: null)).called(1); // counter, not ~/50
  });

  test('loadMore appends the next page and de-dupes', () async {
    final first = List.generate(50, (i) => note('n$i'));
    when(() => api.list(tag: null)).thenAnswer(
      (_) async => pageOf(first, total: 60),
    );
    when(() => api.list(page: 2, tag: null)).thenAnswer(
      (_) async => pageOf([note('n49'), note('x1'), note('x2')], total: 60, page: 2),
    );

    final c = make();
    await c.read(notesControllerProvider.future);
    await c.read(notesControllerProvider.notifier).loadMore();

    final s = c.read(notesControllerProvider).value!;
    expect(s.notes.length, 52); // 50 + 2 new (n49 de-duped)
    expect(s.loadingMore, isFalse);
  });

  group('models', () {
    test('NoteRow.fromJson + preview fallback', () {
      final n = NoteRow.fromJson({
        'id': 'x',
        'title': 'T',
        'content': '\n\nFirst real line\nmore',
        'tags': ['a', 1, 'b'],
        'summary': null,
        'createdAt': '2026-07-01T00:00:00.000Z',
        'updatedAt': '2026-07-02T00:00:00.000Z',
      });
      expect(n.tags, ['a', 'b']);
      expect(n.preview, 'First real line');
    });

    test('summary wins over content for preview', () {
      final n = NoteRow.fromJson({
        'id': 'x',
        'title': 'T',
        'content': 'body',
        'summary': ' the summary ',
        'createdAt': '2026-07-01T00:00:00.000Z',
        'updatedAt': '2026-07-02T00:00:00.000Z',
      });
      expect(n.preview, 'the summary');
    });

    test('NotesPage.fromJson defaults', () {
      final p = NotesPage.fromJson({
        'notes': [
          {
            'id': 'x',
            'title': 'T',
            'createdAt': '2026-07-01T00:00:00.000Z',
            'updatedAt': '2026-07-02T00:00:00.000Z',
          }
        ],
        'total': 1,
        'tags': [
          {'tag': 'work', 'count': 3}
        ],
      });
      expect(p.notes.single.content, '');
      expect(p.pageSize, 50);
      expect(p.tags.single.count, 3);
    });
  });
}
