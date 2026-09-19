import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/dio_provider.dart';
import 'files_models.dart';

part 'file_open_service.g.dart';

/// Above this the sheet names the size on the button, so a large download is
/// something the user chose and not something a tap on a row started.
const int kLargeFileBytes = 100 * 1024 * 1024;

/// The cache is pruned, oldest first, down to this after every download.
const int kFileCacheCapBytes = 500 * 1024 * 1024;

/// What happened when a downloaded file was handed to the phone.
enum FileOpenOutcome {
  /// A viewer took it (Quick Look on iOS, an "open with" target on Android).
  opened,

  /// Nothing on the phone claims this type, so the share sheet was shown
  /// instead: the user can still route the file somewhere.
  shared,

  /// Neither worked.
  failed,
}

/// The seam to the OS, so the service is testable without platform channels.
abstract class FileLauncher {
  /// True when a viewer opened [path]; false when no app handles [mimeType].
  Future<bool> open(String path, String mimeType);

  Future<bool> share(String path, String mimeType, String filename);
}

class PlatformFileLauncher implements FileLauncher {
  const PlatformFileLauncher();

  @override
  Future<bool> open(String path, String mimeType) async {
    final res = await OpenFilex.open(path, type: mimeType);
    return res.type == ResultType.done;
  }

  @override
  Future<bool> share(String path, String mimeType, String filename) async {
    final res = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: mimeType, name: filename)],
      ),
    );
    return res.status != ShareResultStatus.unavailable;
  }
}

/// Opening a brain file on the phone.
///
/// A system viewer cannot send the bearer, so the file is downloaded INSIDE the
/// app, with the bearer, and the OS is handed a local copy: no credential ever
/// leaves the app. The download streams to disk (dio `download`), because
/// holding a 300 MB video in memory the way the image preview holds a photo is
/// not an option.
///
/// The copy lives in the CACHE directory, never Documents: the OS may evict it,
/// it is not backed up, and it is not exposed to the Files app. It is removed
/// on sign-out and when the session dies ([clearCache], called from the session
/// wipe), and the cache is capped ([kFileCacheCapBytes], oldest first).
///
/// Viewing only. Editing stays on the web, per the phone's scope rule.
class FileOpenService {
  FileOpenService(
    this._dio, {
    this.launcher = const PlatformFileLauncher(),
    Future<Directory> Function()? cacheRoot,
  }) : _cacheRoot = cacheRoot ?? getTemporaryDirectory;

  final Dio _dio;
  final FileLauncher launcher;
  final Future<Directory> Function() _cacheRoot;

  static const _dirName = 'opened_files';

  Future<Directory> _dir() async =>
      Directory('${(await _cacheRoot()).path}/$_dirName');

  /// One folder per file id, so two files with the same name never collide and
  /// the viewer still sees the real filename.
  Future<File> _target(FileRow f) async =>
      File('${(await _dir()).path}/${f.id}/${safeFilename(f)}');

  /// The cached copy, when it is there and whole.
  Future<File?> cached(FileRow f) async {
    final file = await _target(f);
    if (!file.existsSync()) return null;
    if (f.sizeBytes > 0 && file.lengthSync() != f.sizeBytes) return null;
    return file;
  }

  /// Download [f] to the cache (or reuse a whole cached copy) and return it.
  /// Streams to a `.part` file and renames at the end, so a cancelled or failed
  /// download never leaves something that looks complete.
  Future<File> download(
    FileRow f, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final hit = await cached(f);
    if (hit != null) {
      hit.setLastModifiedSync(DateTime.now());
      return hit;
    }
    final target = await _target(f);
    target.parent.createSync(recursive: true);
    final part = File('${target.path}.part');
    try {
      await _dio.download(
        '/api/files/files/${f.id}',
        part.path,
        queryParameters: const {'raw': '1'},
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) =>
            onProgress?.call(received, total > 0 ? total : f.sizeBytes),
      );
      final done = part.renameSync(target.path);
      await prune(keep: f.id);
      return done;
    } catch (_) {
      if (part.existsSync()) part.deleteSync();
      rethrow;
    }
  }

  /// Hand a downloaded file to the phone: a viewer first, the share sheet when
  /// nothing claims the type.
  Future<FileOpenOutcome> open(File file, FileRow f) async {
    try {
      if (await launcher.open(file.path, f.mimeType)) {
        return FileOpenOutcome.opened;
      }
    } catch (_) {
      /* fall through to the share sheet */
    }
    return await share(file, f)
        ? FileOpenOutcome.shared
        : FileOpenOutcome.failed;
  }

  Future<bool> share(File file, FileRow f) async {
    try {
      return await launcher.share(file.path, f.mimeType, f.filename);
    } catch (_) {
      return false;
    }
  }

  /// Drop the oldest cached files until the cache fits the cap. [keep] is never
  /// dropped: it is the file about to be opened.
  Future<void> prune({String? keep, int capBytes = kFileCacheCapBytes}) async {
    final dir = await _dir();
    if (!dir.existsSync()) return;
    final entries = <({Directory dir, int bytes, DateTime used})>[];
    for (final d in dir.listSync().whereType<Directory>()) {
      var bytes = 0;
      var used = DateTime.fromMillisecondsSinceEpoch(0);
      for (final file in d.listSync(recursive: true).whereType<File>()) {
        final stat = file.statSync();
        bytes += stat.size;
        if (stat.modified.isAfter(used)) used = stat.modified;
      }
      entries.add((dir: d, bytes: bytes, used: used));
    }
    var total = entries.fold<int>(0, (sum, e) => sum + e.bytes);
    entries.sort((a, b) => a.used.compareTo(b.used));
    for (final e in entries) {
      if (total <= capBytes) break;
      if (keep != null && e.dir.path.endsWith('/$keep')) continue;
      e.dir.deleteSync(recursive: true);
      total -= e.bytes;
    }
  }

  /// Remove every downloaded file. Part of the session wipe.
  Future<void> clearCache() async {
    final dir = await _dir();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// The name the viewer shows, made safe as a path segment. Falls back to the
/// title, then the id, and keeps the extension so the OS can pick a viewer.
String safeFilename(FileRow f) {
  var name = f.filename.trim().isNotEmpty ? f.filename.trim() : f.title.trim();
  name = name.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '_');
  name = name.replaceAll(RegExp(r'^\.+'), '');
  if (name.isEmpty) name = f.id;
  final ext = f.extension.replaceAll('.', '').trim();
  if (ext.isNotEmpty && !name.toLowerCase().endsWith('.${ext.toLowerCase()}')) {
    name = '$name.$ext';
  }
  return name.length > 120 ? name.substring(name.length - 120) : name;
}

@Riverpod(keepAlive: true)
FileOpenService fileOpenService(Ref ref) =>
    FileOpenService(ref.watch(dioProvider));
