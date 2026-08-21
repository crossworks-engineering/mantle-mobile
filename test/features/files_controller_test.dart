// FilesController: folder+file load, optimistic delete with rollback,
// upload → reload. Plus FolderRow/FileRow model parsing.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/files/files_api.dart';
import 'package:jackdaw/data/files/files_models.dart';
import 'package:jackdaw/features/files/files_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockFilesApi extends Mock implements FilesApi {}

class MockDio extends Mock implements Dio {}

FolderRow folder(String slug) => FolderRow(
      id: 'folder-$slug',
      path: 'files.$slug',
      title: slug,
      slug: slug,
      description: '',
      childFolderCount: 0,
      fileCount: 1,
    );

FileRow file(String id, {String mime = 'application/pdf'}) => FileRow(
      id: id,
      parentPath: 'files',
      title: id,
      filename: '$id.pdf',
      extension: 'pdf',
      mimeType: mime,
      sizeBytes: 2048,
      summary: null,
      updatedAt: DateTime.utc(2026, 7, 1),
    );

void main() {
  late MockFilesApi api;
  setUp(() => api = MockFilesApi());

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [filesApiProvider.overrideWithValue(api)],
    );
    addTearDown(c.dispose);
    c.listen(filesControllerProvider('files'), (_, _) {});
    return c;
  }

  test('loads folders and files together', () async {
    when(() => api.folders('files')).thenAnswer((_) async => [folder('work')]);
    when(() => api.files('files')).thenAnswer((_) async => [file('a')]);

    final c = make();
    final contents = await c.read(filesControllerProvider('files').future);

    expect(contents.folders.single.slug, 'work');
    expect(contents.files.single.id, 'a');
    expect(contents.isEmpty, isFalse);
  });

  test('deleteFile is optimistic; failure reloads from the server', () async {
    var listCalls = 0;
    when(() => api.folders('files')).thenAnswer((_) async => const []);
    when(() => api.files('files')).thenAnswer((_) async {
      listCalls++;
      return [file('a'), file('b')];
    });
    when(() => api.delete('a')).thenThrow(Exception('offline'));

    final c = make();
    await c.read(filesControllerProvider('files').future);
    await c.read(filesControllerProvider('files').notifier).deleteFile('a');

    final contents = c.read(filesControllerProvider('files')).value!;
    expect(listCalls, 2); // initial + rollback reload
    expect(contents.files.map((f) => f.id), ['a', 'b']);
  });

  test('deleteFile removes the row when the server accepts', () async {
    when(() => api.folders('files')).thenAnswer((_) async => const []);
    when(() => api.files('files')).thenAnswer((_) async => [file('a'), file('b')]);
    when(() => api.delete('a')).thenAnswer((_) async {});

    final c = make();
    await c.read(filesControllerProvider('files').future);
    await c.read(filesControllerProvider('files').notifier).deleteFile('a');

    final contents = c.read(filesControllerProvider('files')).value!;
    expect(contents.files.map((f) => f.id), ['b']);
  });

  test('upload posts to the folder then reloads', () async {
    when(() => api.folders('files')).thenAnswer((_) async => const []);
    when(() => api.files('files')).thenAnswer((_) async => [file('a')]);
    when(() => api.upload(
          parentPath: 'files',
          localPath: '/tmp/x.pdf',
          filename: 'x.pdf',
        )).thenAnswer((_) async => file('x'));

    final c = make();
    await c.read(filesControllerProvider('files').future);
    await c
        .read(filesControllerProvider('files').notifier)
        .upload(localPath: '/tmp/x.pdf', filename: 'x.pdf');

    verify(() => api.upload(
          parentPath: 'files',
          localPath: '/tmp/x.pdf',
          filename: 'x.pdf',
        )).called(1);
    verify(() => api.files('files')).called(2); // initial + post-upload reload
  });

  test('upload failure rethrows so the screen can explain', () async {
    when(() => api.folders('files')).thenAnswer((_) async => const []);
    when(() => api.files('files')).thenAnswer((_) async => const []);
    when(() => api.upload(
          parentPath: 'files',
          localPath: '/tmp/dup.pdf',
          filename: 'dup.pdf',
        )).thenThrow(Exception('409'));

    final c = make();
    await c.read(filesControllerProvider('files').future);

    expect(
      () => c
          .read(filesControllerProvider('files').notifier)
          .upload(localPath: '/tmp/dup.pdf', filename: 'dup.pdf'),
      throwsA(isA<Exception>()),
    );
  });

  group('FilesApi.upload error mapping', () {
    test('409/413 become typed FileUploadException; others rethrow raw',
        () async {
      final tmp = File(
          '${Directory.systemTemp.createTempSync('files_api_test').path}/x.pdf')
        ..writeAsStringSync('pdf-ish');
      addTearDown(() => tmp.parent.deleteSync(recursive: true));

      DioException status(int code) => DioException(
            requestOptions: RequestOptions(path: '/api/files/files'),
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: RequestOptions(path: '/api/files/files'),
              statusCode: code,
            ),
          );

      Future<void> expectUpload(DioException e, Matcher matcher) async {
        final dio = MockDio();
        when(() => dio.post<Map<String, dynamic>>(any(),
            data: any(named: 'data'))).thenThrow(e);
        await expectLater(
          FilesApi(dio).upload(
            parentPath: 'files',
            localPath: tmp.path,
            filename: 'x.pdf',
          ),
          throwsA(matcher),
        );
      }

      await expectUpload(status(409), isA<FileUploadException>());
      await expectUpload(status(413), isA<FileUploadException>());
      // A connection error whose URL merely CONTAINS "409" must stay raw.
      await expectUpload(
        DioException(
          requestOptions: RequestOptions(path: 'http://192.168.1.20:4090/x'),
          type: DioExceptionType.connectionError,
        ),
        isA<DioException>(),
      );
    });
  });

  group('models', () {
    test('FileRow.fromJson + size label + isImage', () {
      final f = FileRow.fromJson({
        'id': 'x',
        'parentPath': 'files.work',
        'title': 'Photo',
        'filename': 'photo.jpg',
        'extension': 'jpg',
        'mimeType': 'image/jpeg',
        'sizeBytes': 1536,
        'updatedAt': '2026-07-01T00:00:00.000Z',
      });
      expect(f.isImage, isTrue);
      expect(f.sizeLabel, '2 KB');
    });

    test('sizeLabel ranges', () {
      FileRow of(int bytes) => FileRow.fromJson({
            'id': 'x',
            'filename': 'f',
            'sizeBytes': bytes,
          });
      expect(of(512).sizeLabel, '512 B');
      expect(of(2 * 1024 * 1024).sizeLabel, '2.0 MB');
    });

    test('FolderRow.fromJson defaults', () {
      final f = FolderRow.fromJson({'id': 'x', 'path': 'files.a', 'slug': 'a'});
      expect(f.title, '');
      expect(f.fileCount, 0);
    });
  });
}
