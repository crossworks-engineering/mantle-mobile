// FilesController: folder+file load, optimistic delete with rollback,
// upload → reload. Plus FolderRow/FileRow model parsing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/files/files_api.dart';
import 'package:mantle_companion/data/files/files_models.dart';
import 'package:mantle_companion/features/files/files_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockFilesApi extends Mock implements FilesApi {}

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
