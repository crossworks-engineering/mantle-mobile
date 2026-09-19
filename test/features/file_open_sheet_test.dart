import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/data/files/file_open_service.dart';
import 'package:jackdaw/data/files/files_models.dart';
import 'package:jackdaw/features/files/file_open_sheet.dart';

import '../helpers/pump_screen.dart';

FileRow row(int size) => FileRow(
  id: 'f1',
  parentPath: 'files',
  title: 'Report',
  filename: 'Report.pdf',
  extension: 'pdf',
  mimeType: 'application/pdf',
  sizeBytes: size,
  summary: null,
  updatedAt: null,
);

/// A service whose download the test finishes (or fails) by hand.
class _FakeService extends FileOpenService {
  _FakeService({this.outcome = FileOpenOutcome.opened}) : super(Dio());

  final FileOpenOutcome outcome;
  final gate = Completer<File>();
  void Function(int, int)? progress;
  CancelToken? token;
  var opened = 0;
  var sharedCount = 0;

  @override
  Future<File> download(
    FileRow f, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) {
    progress = onProgress;
    token = cancelToken;
    return gate.future;
  }

  @override
  Future<FileOpenOutcome> open(File file, FileRow f) async {
    opened++;
    return outcome;
  }

  @override
  Future<bool> share(File file, FileRow f) async {
    sharedCount++;
    return true;
  }
}

Future<_FakeService> _pump(
  WidgetTester tester,
  FileRow f, {
  FileOpenOutcome outcome = FileOpenOutcome.opened,
}) async {
  final service = _FakeService(outcome: outcome);
  // The panel reads the server address (for "Open in Mantle") from settings.
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [
      fileOpenServiceProvider.overrideWithValue(service),
      appDatabaseProvider.overrideWithValue(db),
    ],
  );
  await pumpScreen(tester, FileOpenPanel(file: f), container: container);
  return service;
}

void main() {
  testWidgets('Open downloads with progress, then hands the file over', (
    tester,
  ) async {
    final service = await _pump(tester, row(2048));
    expect(find.text('application/pdf · 2 KB'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(find.text('Downloading…'), findsOneWidget);
    expect(find.text('Open'), findsNothing);

    service.progress!(1024, 2048);
    await tester.pump();
    expect(find.text('Downloading… 50%'), findsOneWidget);

    service.gate.complete(File('/tmp/Report.pdf'));
    await tester.pumpAndSettle();
    expect(service.opened, 1);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('a large file names its size on the button', (tester) async {
    await _pump(tester, row(300 * 1024 * 1024));
    expect(find.text('Download 300.0 MB and open'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('says so when no app opens the type and it was shared instead', (
    tester,
  ) async {
    final service = await _pump(
      tester,
      row(10),
      outcome: FileOpenOutcome.shared,
    );
    await tester.tap(find.text('Open'));
    service.gate.complete(File('/tmp/Report.pdf'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No app on this phone opens this type'),
      findsOneWidget,
    );
  });

  testWidgets('Cancel stops the download and returns to the buttons', (
    tester,
  ) async {
    final service = await _pump(tester, row(10));
    await tester.tap(find.text('Open'));
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    expect(service.token!.isCancelled, isTrue);
    service.gate.completeError(
      DioException.requestCancelled(
        requestOptions: RequestOptions(),
        reason: 'cancelled',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.textContaining("Couldn't"), findsNothing);
  });

  testWidgets('a failed download says so and can be retried', (tester) async {
    final service = await _pump(tester, row(10));
    await tester.tap(find.text('Open'));
    service.gate.completeError(StateError('network'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't download the file."), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('Share sends the downloaded copy to the share sheet', (
    tester,
  ) async {
    final service = await _pump(tester, row(10));
    await tester.tap(find.text('Share'));
    service.gate.complete(File('/tmp/Report.pdf'));
    await tester.pumpAndSettle();
    expect(service.sharedCount, 1);
    expect(service.opened, 0);
  });
}
