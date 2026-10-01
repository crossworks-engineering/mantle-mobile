// TreeApi against a stubbed brain: the requests it builds and how it reads
// the tree's refusals. The bodies are the real ones (test/fixtures/tree/).

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/files/files_api.dart';
import 'package:jackdaw/data/tree/tree_api.dart';
import 'package:jackdaw/data/tree/tree_models.dart';

import '../helpers/stub_dio.dart';

String raw(String name) =>
    File('test/fixtures/tree/$name.json').readAsStringSync();

void main() {
  test('a folder page: kind in the path, folder, cursor and sort in the query',
      () async {
    final adapter =
        StubAdapter((_) => (status: 200, body: raw('tree_pages_archive_p2')));
    final api = TreeApi(stubDio(adapter));

    final page = await api.folder(
      TreeKind.pages,
      folderId: 'f-1',
      cursor: 'abc',
      sort: TreeSort.name,
    );

    final sent = adapter.requests.single;
    expect(sent.path, '/api/tree/pages');
    expect(sent.queryParameters,
        {'folder': 'f-1', 'cursor': 'abc', 'sort': 'name'});
    expect(page.items, hasLength(10));
  });

  test('the root sends no folder at all', () async {
    final adapter =
        StubAdapter((_) => (status: 200, body: raw('tree_pages_root')));
    await TreeApi(stubDio(adapter)).folder(TreeKind.pages);

    expect(adapter.requests.single.queryParameters, isEmpty);
  });

  test('404 on the root is a brain older than the tree', () async {
    final api = TreeApi(stubDio(
      StubAdapter((_) => (status: 404, body: raw('tree_kind_404'))),
    ));

    await expectLater(
      api.folder(TreeKind.pages),
      throwsA(isA<TreeUnavailable>()),
    );
  });

  test('404 with a folder named is that folder, gone or not shared', () async {
    final api = TreeApi(stubDio(
      StubAdapter((_) => (status: 404, body: raw('tree_folder_404'))),
    ));

    await expectLater(
      api.folder(TreeKind.pages, folderId: 'f-gone'),
      throwsA(isA<TreeFolderMissing>()),
    );
  });

  test('any other failure is passed on untouched', () async {
    final api = TreeApi(stubDio(
      StubAdapter((_) => (status: 500, body: '{"error":"boom"}')),
    ));

    await expectLater(
      api.folder(TreeKind.pages),
      throwsA(isA<DioException>()),
    );
  });

  test('search and marks name their view', () async {
    final adapter = StubAdapter(
      (o) => (
        status: 200,
        body: o.path.endsWith('/marks')
            ? raw('tree_pages_marks_recent')
            : raw('tree_pages_search'),
      ),
    );
    final api = TreeApi(stubDio(adapter));

    final found = await api.search(TreeKind.pages, 'engineering', tag: 'idea');
    final recent = await api.marks(TreeKind.pages, TreeMarkView.recent);

    expect(adapter.requests[0].path, '/api/tree/pages/search');
    expect(adapter.requests[0].queryParameters,
        {'q': 'engineering', 'tag': 'idea'});
    expect(adapter.requests[1].path, '/api/tree/pages/marks');
    expect(adapter.requests[1].queryParameters, {'view': 'recent'});
    expect(found.items, isNotEmpty);
    expect(recent.items, isNotEmpty);
  });

  test('a move into a shared folder is refused with the list', () async {
    final adapter = StubAdapter(
      (_) => (status: 409, body: raw('tree_move_visibility_409')),
    );
    final api = TreeApi(stubDio(adapter));

    await expectLater(
      api.move(TreeKind.notes, ['n-1'], 'f-shared'),
      throwsA(
        isA<TreeVisibilityRefusal>()
            .having((r) => r.to, 'to', 'team')
            .having((r) => r.seen, 'seen', 1),
      ),
    );
    expect(adapter.requests.single.data, {'ids': ['n-1'], 'folderId': 'f-shared'});
  });

  test('the confirmed move says what the person was shown', () async {
    final adapter = StubAdapter(
      (_) => (status: 200, body: '{"moved":1,"failed":[]}'),
    );
    final api = TreeApi(stubDio(adapter));

    final failed = await api.move(
      TreeKind.notes,
      ['n-1'],
      'f-shared',
      confirm: true,
      seen: 1,
    );

    expect(failed, isEmpty);
    expect(adapter.requests.single.path, '/api/tree/notes/move');
    expect(adapter.requests.single.data,
        {'ids': ['n-1'], 'folderId': 'f-shared', 'confirm': true, 'seen': 1});
  });

  test('a move to the top level sends a null folder; failures come back',
      () async {
    final adapter = StubAdapter(
      (_) => (
        status: 200,
        body: '{"moved":0,"failed":[{"id":"n-1","error":"not found"}]}',
      ),
    );
    final failed =
        await TreeApi(stubDio(adapter)).move(TreeKind.notes, ['n-1'], null);

    expect(failed, ['n-1']);
    expect((adapter.requests.single.data as Map)['folderId'], isNull);
  });

  test('counting an open never throws', () async {
    final api = TreeApi(stubDio(
      StubAdapter((_) => (status: 404, body: '{"error":"not found"}')),
    ));

    await expectLater(api.opened('i-1'), completes);
  });

  group('uploading into a folder', () {
    late File picked;
    setUp(() {
      picked = File('${Directory.systemTemp.path}/jackdaw-upload-test.txt')
        ..writeAsStringSync('hello');
    });
    tearDown(() => picked.deleteSync());

    test('a shared folder refuses first, and is not read as a duplicate name',
        () async {
      final api = FilesApi(stubDio(
        StubAdapter(
          (_) => (status: 409, body: raw('files_upload_409_visibility')),
        ),
      ));

      await expectLater(
        api.upload(
          parentPath: 'files.brand',
          localPath: picked.path,
          filename: 'logo.png',
        ),
        throwsA(isA<TreeVisibilityRefusal>().having((r) => r.to, 'to', 'team')),
      );
    });

    test('a plain 409 is still a duplicate name', () async {
      final api = FilesApi(stubDio(
        StubAdapter((_) => (status: 409, body: '{"error":"exists"}')),
      ));

      await expectLater(
        api.upload(
          parentPath: 'files',
          localPath: picked.path,
          filename: 'a.txt',
        ),
        throwsA(isA<FileUploadException>()),
      );
    });

    test('confirm goes as a form field ahead of the file', () async {
      final adapter = StubAdapter(
        (_) => (
          status: 200,
          body: jsonEncode({
            'file': {'id': 'f1', 'filename': 'a.txt', 'title': 'a.txt'},
          }),
        ),
      );
      await FilesApi(stubDio(adapter)).upload(
        parentPath: 'files.brand',
        localPath: picked.path,
        filename: 'a.txt',
        confirm: true,
      );

      final form = adapter.requests.single.data as FormData;
      expect(form.fields.map((f) => f.key), ['parentPath', 'confirm']);
      expect(form.fields.last.value, 'true');
      expect(form.files.single.key, 'file');
    });
  });
}
