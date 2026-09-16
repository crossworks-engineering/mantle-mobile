// JournalController orders by the date the screen shows, not by the server's
// creation order — an entry written today about last week sits under last
// week — and a captured entry lands where its date puts it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/journal/journal_api.dart';
import 'package:jackdaw/data/journal/journal_models.dart';
import 'package:jackdaw/features/journal/journal_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalApi extends Mock implements JournalApi {}

JournalRow _row(String id, {required DateTime created, DateTime? entry}) =>
    JournalRow(
      id: id,
      title: id,
      body: id,
      mood: null,
      category: null,
      entryDate: entry,
      tags: const [],
      createdAt: created,
      updatedAt: created,
    );

void main() {
  late MockJournalApi api;
  setUp(() => api = MockJournalApi());

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [journalApiProvider.overrideWithValue(api)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('newestFirst orders by displayDate, then creation', () {
    final rows = [
      _row('jun09', created: DateTime.utc(2026, 6, 9)),
      _row('jun06a', created: DateTime.utc(2026, 6, 6, 8)),
      _row('jun11', created: DateTime.utc(2026, 6, 11)),
      _row('jun06b', created: DateTime.utc(2026, 6, 6, 9)),
      // Written on the 12th, about the 1st: sorts under the 1st.
      _row('about-jun01',
          created: DateTime.utc(2026, 6, 12), entry: DateTime.utc(2026, 6, 1)),
    ];
    expect(
      newestFirst(rows).map((r) => r.id).toList(),
      ['jun11', 'jun09', 'jun06b', 'jun06a', 'about-jun01'],
    );
  });

  test('build sorts the server page', () async {
    when(() => api.list()).thenAnswer((_) async => JournalPage(
          journals: [
            _row('b', created: DateTime.utc(2026, 6, 6)),
            _row('c', created: DateTime.utc(2026, 6, 11)),
            _row('a', created: DateTime.utc(2026, 6, 9)),
          ],
          total: 3,
        ));
    final c = make();
    final rows = await c.read(journalControllerProvider.future);
    expect(rows.map((r) => r.id).toList(), ['c', 'a', 'b']);
  });

  test('capture slots the saved row by its date, not at the top', () async {
    when(() => api.list()).thenAnswer((_) async => JournalPage(
          journals: [
            _row('newer', created: DateTime.utc(2026, 6, 11)),
            _row('older', created: DateTime.utc(2026, 6, 6)),
          ],
          total: 2,
        ));
    when(() => api.create(any())).thenAnswer((_) async => _row(
          'backdated',
          created: DateTime.utc(2026, 6, 12),
          entry: DateTime.utc(2026, 6, 8),
        ));
    final c = make();
    await c.read(journalControllerProvider.future);
    await c.read(journalControllerProvider.notifier).capture('last week…');
    expect(
      c.read(journalControllerProvider).value!.map((r) => r.id).toList(),
      ['newer', 'backdated', 'older'],
    );
  });
}
