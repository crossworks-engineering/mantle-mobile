import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/files/file_open_service.dart';
import 'package:jackdaw/data/files/files_models.dart';

FileRow row(
  String id,
  String filename,
  int size, {
  String mime = 'application/pdf',
  String ext = 'pdf',
}) => FileRow(
  id: id,
  parentPath: 'files',
  title: filename,
  filename: filename,
  extension: ext,
  mimeType: mime,
  sizeBytes: size,
  summary: null,
  updatedAt: null,
);

/// Serves `size` bytes for any file id, and counts the requests.
class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter({this.fail = false});

  final bool fail;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (fail) return ResponseBody.fromString('nope', 500);
    final size = int.parse(options.path.split('/').last.split('-').last);
    return ResponseBody.fromBytes(
      List.filled(size, 7),
      200,
      headers: {
        Headers.contentLengthHeader: ['$size'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeLauncher implements FileLauncher {
  _FakeLauncher({this.opens = true, this.shares = true});

  final bool opens;
  final bool shares;
  final opened = <String>[];
  final shared = <String>[];

  @override
  Future<bool> open(String path, String mimeType) async {
    opened.add(path);
    return opens;
  }

  @override
  Future<bool> share(String path, String mimeType, String filename) async {
    shared.add(path);
    return shares;
  }
}

void main() {
  late Directory tmp;
  late _BytesAdapter adapter;

  FileOpenService service({FileLauncher? launcher, bool fail = false}) {
    adapter = _BytesAdapter(fail: fail);
    final dio = Dio(BaseOptions(baseUrl: 'https://brain.example'))
      ..httpClientAdapter = adapter;
    return FileOpenService(
      dio,
      launcher: launcher ?? _FakeLauncher(),
      cacheRoot: () async => tmp,
    );
  }

  setUp(() => tmp = Directory.systemTemp.createTempSync('file_open_test'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test(
    'downloads the raw bytes into the cache under the real filename',
    () async {
      final s = service();
      final progress = <int>[];
      final f = await s.download(
        row('f-10', 'Report.pdf', 10),
        onProgress: (got, _) => progress.add(got),
      );

      expect(f.path, endsWith('/opened_files/f-10/Report.pdf'));
      expect(f.lengthSync(), 10);
      expect(adapter.requests.single.path, '/api/files/files/f-10');
      expect(adapter.requests.single.queryParameters, {'raw': '1'});
      expect(progress, isNotEmpty);
      expect(File('${f.path}.part').existsSync(), isFalse);
    },
  );

  test('a whole cached copy is reused; a short one is fetched again', () async {
    final s = service();
    final f = await s.download(row('f-10', 'a.pdf', 10));
    await s.download(row('f-10', 'a.pdf', 10));
    expect(adapter.requests, hasLength(1));

    f.writeAsBytesSync([1, 2, 3]);
    await s.download(row('f-10', 'a.pdf', 10));
    expect(adapter.requests, hasLength(2));
    expect(f.lengthSync(), 10);
  });

  test('a failed download leaves nothing behind that looks complete', () async {
    final s = service(fail: true);
    await expectLater(
      s.download(row('f-10', 'a.pdf', 10)),
      throwsA(isA<DioException>()),
    );
    expect(await s.cached(row('f-10', 'a.pdf', 10)), isNull);
    final dir = Directory('${tmp.path}/opened_files/f-10');
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('open hands the file to a viewer', () async {
    final launcher = _FakeLauncher();
    final s = service(launcher: launcher);
    final r = row('f-10', 'a.pdf', 10);
    expect(await s.open(await s.download(r), r), FileOpenOutcome.opened);
    expect(launcher.shared, isEmpty);
  });

  test('with no app for the type it falls back to the share sheet', () async {
    final launcher = _FakeLauncher(opens: false);
    final s = service(launcher: launcher);
    final r = row(
      'f-10',
      'model.step',
      10,
      mime: 'application/octet-stream',
      ext: 'step',
    );
    expect(await s.open(await s.download(r), r), FileOpenOutcome.shared);
    expect(launcher.shared.single, endsWith('model.step'));
  });

  test('reports failure when neither a viewer nor sharing works', () async {
    final s = service(launcher: _FakeLauncher(opens: false, shares: false));
    final r = row('f-10', 'a.pdf', 10);
    expect(await s.open(await s.download(r), r), FileOpenOutcome.failed);
  });

  test(
    'prune drops the oldest files first and never the one being opened',
    () async {
      final s = service();
      final old = await s.download(row('old-40', 'old.pdf', 40));
      final mid = await s.download(row('mid-40', 'mid.pdf', 40));
      final now = await s.download(row('new-40', 'new.pdf', 40));
      old.setLastModifiedSync(DateTime(2026, 1, 1));
      mid.setLastModifiedSync(DateTime(2026, 2, 1));
      now.setLastModifiedSync(DateTime(2026, 3, 1));

      await s.prune(capBytes: 90);
      expect(old.existsSync(), isFalse);
      expect(mid.existsSync(), isTrue);
      expect(now.existsSync(), isTrue);

      // Over the cap even alone: the file about to be opened still survives.
      await s.prune(capBytes: 10, keep: 'new-40');
      expect(mid.existsSync(), isFalse);
      expect(now.existsSync(), isTrue);
    },
  );

  test('clearCache removes every downloaded file', () async {
    final s = service();
    final f = await s.download(row('f-10', 'a.pdf', 10));
    await s.clearCache();
    expect(f.existsSync(), isFalse);
    expect(Directory('${tmp.path}/opened_files').existsSync(), isFalse);
    await s.clearCache(); // idempotent
  });

  group('safeFilename', () {
    test('strips path separators and leading dots', () {
      expect(
        safeFilename(row('i', '../../etc/passwd', 1, ext: '')),
        '_.._etc_passwd',
      );
      expect(safeFilename(row('i', '.hidden.pdf', 1)), 'hidden.pdf');
    });

    test('adds a missing extension so the OS can pick a viewer', () {
      expect(
        safeFilename(row('i', 'Quarterly report', 1)),
        'Quarterly report.pdf',
      );
      expect(safeFilename(row('i', 'Report.PDF', 1)), 'Report.PDF');
    });

    test('falls back to the id when there is no usable name', () {
      expect(safeFilename(row('abc', '', 1, ext: '')), 'abc');
    });
  });
}
