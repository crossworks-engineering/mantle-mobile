// The journal's EntrySheet: a plain entry edits and can be deleted (behind a
// confirm); an assistant's open question takes an answer instead. The
// screen itself owns an AudioRecorder, which needs a platform, so the sheet
// is tested on its own.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/journal/journal_api.dart';
import 'package:jackdaw/data/journal/journal_models.dart';
import 'package:jackdaw/features/journal/journal_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../helpers/pump_screen.dart';

class MockJournalApi extends Mock implements JournalApi {}

JournalRow _entry(String id, {String? kind, String? status}) => JournalRow(
      id: id,
      title: 'Title $id',
      body: 'Body $id',
      mood: null,
      category: null,
      entryDate: null,
      tags: const [],
      createdAt: DateTime.utc(2026, 9, 10),
      updatedAt: DateTime.utc(2026, 9, 10),
      kind: kind,
      status: status,
      author: kind == 'gap' ? 'agent' : 'user',
      agentSlug: kind == 'gap' ? 'saskia' : null,
    );

void main() {
  late MockJournalApi api;
  setUp(() {
    api = MockJournalApi();
    when(() => api.list())
        .thenAnswer((_) async => const JournalPage(journals: [], total: 0));
  });

  // A ShadSheet only builds inside a sheet route, so a host opens it the way
  // the screen does, through showShadSheet.
  Future<void> pump(WidgetTester tester, JournalRow entry) async {
    await pumpScreen(
      tester,
      _Host(entry: entry),
      container: ProviderContainer(
        overrides: [journalApiProvider.overrideWithValue(api)],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a plain entry offers Save and Delete, and Delete asks first',
      (tester) async {
    await pump(tester, _entry('a'));
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Answer'), findsNothing);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete entry?'), findsOneWidget);
  });

  testWidgets("an open question shows the agent's question and takes an "
      'answer', (tester) async {
    final gap = _entry('q', kind: 'gap', status: 'open');
    expect(gap.isOpenGap, isTrue);
    await pump(tester, gap);

    expect(find.text('A question for you'), findsOneWidget);
    expect(find.text('From saskia'), findsOneWidget);
    expect(find.text('Body q'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('a resolved question is an ordinary entry again',
      (tester) async {
    await pump(tester, _entry('q', kind: 'gap', status: 'resolved'));
    expect(find.text('Answer'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });
}

class _Host extends StatelessWidget {
  const _Host({required this.entry});

  final JournalRow entry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ShadButton(
        onPressed: () => showShadSheet<void>(
          context: context,
          builder: (_) => EntrySheet(entry: entry),
        ),
        child: const Text('open'),
      ),
    );
  }
}
