// SearchController: immediate search, min-length gate, type filter re-run,
// stale-response protection. Plus SearchResult model parsing.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/search/search_api.dart';
import 'package:mantle_companion/data/search/search_models.dart';
import 'package:mantle_companion/features/search/search_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockSearchApi extends Mock implements SearchApi {}

SearchResult hit(String id, {String type = 'note'}) => SearchResult(
      id: id,
      type: type,
      title: 'Hit $id',
      path: 'notes.$id',
      tags: const [],
      summary: 'about $id',
      updatedAt: DateTime.utc(2026, 7, 1),
      url: 'https://mantle.example/n/$id',
    );

void main() {
  late MockSearchApi api;
  setUp(() => api = MockSearchApi());

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [searchApiProvider.overrideWithValue(api)],
    );
    addTearDown(c.dispose);
    c.listen(searchControllerProvider, (_, _) {});
    return c;
  }

  test('searchNow populates results and flips searched', () async {
    when(() => api.search('printer', type: null))
        .thenAnswer((_) async => [hit('a'), hit('b')]);

    final c = make();
    await c.read(searchControllerProvider.notifier).searchNow('printer');

    final s = c.read(searchControllerProvider);
    expect(s.results.map((r) => r.id), ['a', 'b']);
    expect(s.searching, isFalse);
    expect(s.searched, isTrue);
    expect(s.error, isNull);
  });

  test('short queries never hit the server and clear results', () async {
    when(() => api.search('printer', type: null))
        .thenAnswer((_) async => [hit('a')]);

    final c = make();
    final notifier = c.read(searchControllerProvider.notifier);
    await notifier.searchNow('printer');
    await notifier.searchNow('p');

    final s = c.read(searchControllerProvider);
    expect(s.results, isEmpty);
    expect(s.searched, isFalse);
    verifyNever(() => api.search('p', type: any(named: 'type')));
  });

  test('setType re-runs the current query with the filter', () async {
    when(() => api.search('report', type: null))
        .thenAnswer((_) async => [hit('a'), hit('p', type: 'page')]);
    when(() => api.search('report', type: 'page'))
        .thenAnswer((_) async => [hit('p', type: 'page')]);

    final c = make();
    final notifier = c.read(searchControllerProvider.notifier);
    await notifier.searchNow('report');
    await notifier.setType('page');

    final s = c.read(searchControllerProvider);
    expect(s.type, 'page');
    expect(s.results.single.id, 'p');
  });

  test('a failed search surfaces an error but keeps the query', () async {
    when(() => api.search('boom', type: null)).thenThrow(Exception('offline'));

    final c = make();
    await c.read(searchControllerProvider.notifier).searchNow('boom');

    final s = c.read(searchControllerProvider);
    expect(s.error, isNotNull);
    expect(s.query, 'boom');
    expect(s.searching, isFalse);
  });

  test('a response for the PREVIOUS query never lands inside the new '
      'debounce window', () async {
    final slow = Completer<List<SearchResult>>();
    when(() => api.search('ab', type: null)).thenAnswer((_) => slow.future);
    when(() => api.search('abc', type: null)).thenAnswer((_) async => const []);

    final c = make();
    final notifier = c.read(searchControllerProvider.notifier);
    final pending = notifier.searchNow('ab'); // in flight
    notifier.onQueryChanged('abc'); // debouncing — must invalidate 'ab' NOW
    slow.complete([hit('stale')]);
    await pending;

    final s = c.read(searchControllerProvider);
    expect(s.results, isEmpty); // the stale 'ab' response never rendered
    expect(s.query, 'abc');
    expect(s.searching, isTrue); // still waiting on the debounced request
  });

  test('onQueryChanged below min length invalidates in-flight requests',
      () async {
    final slow = Completer<List<SearchResult>>();
    when(() => api.search('printer', type: null))
        .thenAnswer((_) => slow.future);

    final c = make();
    final notifier = c.read(searchControllerProvider.notifier);
    final pending = notifier.searchNow('printer');
    notifier.onQueryChanged('p'); // user deleted the query — invalidate
    slow.complete([hit('a')]);
    await pending;

    final s = c.read(searchControllerProvider);
    expect(s.results, isEmpty); // the stale response never landed
    expect(s.query, 'p');
  });

  group('models', () {
    test('SearchResult.fromJson with supersededBy', () {
      final r = SearchResult.fromJson({
        'id': 'x',
        'type': 'page',
        'title': 'T',
        'path': 'pages.t',
        'tags': ['a'],
        'summary': null,
        'updatedAt': '2026-07-01T00:00:00.000Z',
        'url': 'https://m.example/n/x',
        'supersededBy': {
          'id': 'y',
          'title': 'Newer',
          'url': 'https://m.example/n/y'
        },
      });
      expect(r.supersededBy!.id, 'y');
      expect(r.updatedAt, DateTime.utc(2026, 7, 1));
    });

    test('SearchResult.fromJson tolerates missing optionals', () {
      final r = SearchResult.fromJson({'id': 'x'});
      expect(r.type, 'node');
      expect(r.title, '');
      expect(r.tags, isEmpty);
      expect(r.updatedAt, isNull);
      expect(r.supersededBy, isNull);
    });
  });
}
