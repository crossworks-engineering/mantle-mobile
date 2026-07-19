/// Models for Mantle Files. Mirrors `FolderRow` / `FileRow` in
/// `packages/files/src/ops.ts`. Folders are ltree branches under the `files`
/// root; files hang off a folder via `parentPath`.
library;

/// One folder (branch node). `path` is the ltree string, e.g. `files.work`.
class FolderRow {
  const FolderRow({
    required this.id,
    required this.path,
    required this.title,
    required this.slug,
    required this.description,
    required this.childFolderCount,
    required this.fileCount,
  });

  final String id;
  final String path;
  final String title;
  final String slug;
  final String description;
  final int childFolderCount;
  final int fileCount;

  static FolderRow fromJson(Map<String, dynamic> j) => FolderRow(
        id: j['id'] as String,
        path: (j['path'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        slug: (j['slug'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        childFolderCount: (j['childFolderCount'] as num?)?.toInt() ?? 0,
        fileCount: (j['fileCount'] as num?)?.toInt() ?? 0,
      );
}

/// One file node.
class FileRow {
  const FileRow({
    required this.id,
    required this.parentPath,
    required this.title,
    required this.filename,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
    required this.summary,
    required this.updatedAt,
  });

  final String id;
  final String parentPath;
  final String title;
  final String filename;
  final String extension;
  final String mimeType;
  final int sizeBytes;
  final String? summary;
  final DateTime? updatedAt;

  bool get isImage => mimeType.startsWith('image/');

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static FileRow fromJson(Map<String, dynamic> j) {
    final updated = j['updatedAt'] as String?;
    return FileRow(
      id: j['id'] as String,
      parentPath: (j['parentPath'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      filename: (j['filename'] as String?) ?? '',
      extension: (j['extension'] as String?) ?? '',
      mimeType: (j['mimeType'] as String?) ?? 'application/octet-stream',
      sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
      summary: j['summary'] as String?,
      updatedAt: updated == null ? null : DateTime.tryParse(updated),
    );
  }
}
