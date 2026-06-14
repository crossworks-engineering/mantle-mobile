/// Media that rides on a chat message.
///
/// Mirrors Mantle's two shapes (see `ChatApi`): a persisted
/// `ConversationAttachment` on a history row, and the inbound `artifacts[]` an
/// image upload echoes back on a turn. A [ChatAttachment] lives in one of three
/// states, checked in this order by the renderer:
///
///  1. [localPath] set → just-picked on this device; rendered straight from
///     disk for an instant preview (the server strips image bytes on the turn
///     reply, so the client keeps showing what it already holds).
///  2. [nodeId] set → persisted on Mantle as a file node; image bytes are
///     fetched (authed) from `/api/files/files/{nodeId}?raw=1`. This is the
///     path taken when history reloads.
///  3. neither → a non-image file / voice note with no preview; shown as a
///     labeled chip (its content already lives in the message text).
enum AttachmentKind { image, file, voice, audio, video }

class ChatAttachment {
  const ChatAttachment({
    required this.kind,
    this.nodeId,
    this.localPath,
    this.caption,
    this.mime,
  });

  final AttachmentKind kind;
  final String? nodeId;
  final String? localPath;
  final String? caption;
  final String? mime;

  bool get isImage => kind == AttachmentKind.image;

  /// A persisted attachment from `GET /api/assistant/messages`
  /// (`ConversationAttachment`: `{kind, mime, caption, nodeId, fileId, url}`).
  /// Returns null for an unrecognised `kind`.
  static ChatAttachment? fromHistoryJson(Map<String, dynamic> j) {
    final kind = _kindFrom(j['kind'] as String?);
    if (kind == null) return null;
    return ChatAttachment(
      kind: kind,
      nodeId: j['nodeId'] as String?,
      caption: j['caption'] as String?,
      mime: j['mime'] as String?,
    );
  }

  static AttachmentKind? _kindFrom(String? s) {
    switch (s) {
      case 'image':
        return AttachmentKind.image;
      case 'voice':
        return AttachmentKind.voice;
      case 'audio':
        return AttachmentKind.audio;
      case 'video':
        return AttachmentKind.video;
      case 'document':
      case 'file':
        return AttachmentKind.file;
    }
    return null;
  }
}

/// A file the user picked locally and is about to send with a turn. Carried
/// through `ChatRepository.send` and posted as multipart (`image` for pictures,
/// `file` for documents) — matching `/api/assistant/turn`.
class OutgoingAttachment {
  const OutgoingAttachment({
    required this.path,
    required this.filename,
    required this.mime,
  });

  final String path;
  final String filename;
  final String mime;

  bool get isImage => mime.startsWith('image/');

  /// The optimistic view of this attachment, shown in the user's bubble the
  /// moment they hit send (renders from [path] on disk).
  ChatAttachment toChatAttachment() => ChatAttachment(
        kind: isImage ? AttachmentKind.image : AttachmentKind.file,
        localPath: path,
        caption: filename,
        mime: mime,
      );
}
