import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/chat/chat_api.dart';
import '../../data/chat/chat_attachment.dart';
import 'audio_bubble.dart';
import '../../widgets/bytes_image.dart';

/// Renders one [ChatAttachment] beneath a message bubble. Images show inline
/// (from disk when just-sent, else fetched authed by `nodeId`) and open full
/// screen on tap; everything else — documents, voice notes — shows as a
/// labeled chip with its file type.
class AttachmentView extends StatelessWidget {
  const AttachmentView({
    super.key,
    required this.attachment,
    required this.theme,
    required this.onUserBubble,
  });

  final ChatAttachment attachment;
  final ShadThemeData theme;

  /// True when this sits in the user's (primary-coloured) bubble — drives the
  /// chip's contrast colours.
  final bool onUserBubble;

  static const double _maxImageHeight = 260;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      final name = Uri.encodeComponent(attachment.caption ?? 'Image');
      if (attachment.localPath != null) {
        final path = attachment.localPath!;
        return _openOnTap(
          context,
          '/files/local-image?path=${Uri.encodeComponent(path)}&name=$name',
          _frame(
            Image.file(
              File(path),
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) => _chip(),
            ),
          ),
        );
      }
      if (attachment.nodeId != null) {
        // The fallback chip is tappable too: the full-screen view carries the
        // Retry for a fetch that failed and was cached as such.
        return _openOnTap(
          context,
          '/files/image/${attachment.nodeId}?name=$name',
          _NetworkImageAttachment(
            nodeId: attachment.nodeId!,
            frame: _frame,
            fallback: _chip,
          ),
        );
      }
    }
    // A voice reply / audio attachment with bytes on disk plays inline;
    // without a playable source it falls through to a chip.
    final isAudio =
        attachment.kind == AttachmentKind.audio ||
        attachment.kind == AttachmentKind.voice;
    if (isAudio && attachment.localPath != null) {
      return AudioBubble(
        path: attachment.localPath!,
        theme: theme,
        caption: attachment.caption,
      );
    }
    return _chip();
  }

  /// Tap opens the full-screen viewer at [route]; long-press still reaches the
  /// bubble's own menu (this detector claims taps only).
  Widget _openOnTap(BuildContext context, String route, Widget child) {
    return Semantics(
      button: true,
      label: 'Open image',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(route),
        child: child,
      ),
    );
  }

  /// Rounded, clipped, height-capped container shared by all inline images.
  Widget _frame(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxImageHeight),
        child: child,
      ),
    );
  }

  /// A labeled chip for files / voice notes (and the fallback when an image
  /// can't be shown). Filename on top, file type below.
  Widget _chip() {
    final scheme = theme.colorScheme;
    final fg = onUserBubble ? scheme.primaryForeground : scheme.foreground;
    final muted = fg.withValues(alpha: 0.7);
    final tile = onUserBubble
        ? scheme.primaryForeground.withValues(alpha: 0.15)
        : scheme.background;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 22, color: fg),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(color: fg),
                ),
                Text(
                  _typeLabel,
                  style: theme.textTheme.muted.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData get _icon {
    switch (attachment.kind) {
      case AttachmentKind.voice:
      case AttachmentKind.audio:
        return LucideIcons.mic;
      case AttachmentKind.video:
        return LucideIcons.video;
      case AttachmentKind.image:
        return LucideIcons.image;
      case AttachmentKind.file:
        return LucideIcons.fileText;
    }
  }

  String get _title {
    final caption = attachment.caption;
    if (caption != null && caption.isNotEmpty) return caption;
    switch (attachment.kind) {
      case AttachmentKind.voice:
        return 'Voice note';
      case AttachmentKind.audio:
        return 'Audio';
      case AttachmentKind.video:
        return 'Video';
      case AttachmentKind.image:
        return 'Image';
      case AttachmentKind.file:
        return 'File';
    }
  }

  /// File type, derived from the caption's extension, falling back to the MIME
  /// subtype (e.g. `report.pdf` → "PDF", `application/pdf` → "PDF").
  String get _typeLabel {
    final caption = attachment.caption ?? '';
    final dot = caption.lastIndexOf('.');
    if (dot != -1 && dot < caption.length - 1) {
      return caption.substring(dot + 1).toUpperCase();
    }
    final mime = attachment.mime ?? '';
    if (mime.contains('/')) return mime.split('/').last.toUpperCase();
    return attachment.kind.name.toUpperCase();
  }
}

/// Inline image fetched (authed) by file node id — the path taken when history
/// reloads. Shows a muted placeholder while loading and the [fallback] chip if
/// the fetch fails.
class _NetworkImageAttachment extends ConsumerWidget {
  const _NetworkImageAttachment({
    required this.nodeId,
    required this.frame,
    required this.fallback,
  });

  final String nodeId;
  final Widget Function(Widget child) frame;
  final Widget Function() fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(fileBytesProvider(nodeId));
    return bytes.when(
      loading: () => frame(
        const SizedBox(
          height: 140,
          width: double.infinity,
          child: Center(child: SizedBox.shrink()),
        ),
      ),
      error: (_, _) => fallback(),
      data: (data) {
        if (data == null) return fallback();
        return frame(
          SizedBox(
            width: double.infinity,
            child: BytesImage(
              data,
              fit: BoxFit.cover,
              onError: (_) => fallback(),
            ),
          ),
        );
      },
    );
  }
}
