import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/chat/chat_api.dart' show fileBytesProvider;
import '../../widgets/mantle_header.dart';

/// Full-screen image preview with pinch-to-zoom ([InteractiveViewer]). A
/// server file comes by [fileId] through the existing `fileBytesProvider`
/// (`GET /api/files/files/{id}?raw=1` with the Bearer header); a picture just
/// sent from this device, not yet known by node id, comes by [localPath].
class FileImageScreen extends ConsumerWidget {
  const FileImageScreen.file({super.key, required this.fileId, this.name})
      : localPath = null;

  const FileImageScreen.local({super.key, required this.localPath, this.name})
      : fileId = null;

  final String? fileId;
  final String? localPath;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: MantleHeaderTitle(name ?? 'Image', wordmark: false),
            trailing: [
              HeaderAction(
                icon: LucideIcons.arrowLeft,
                label: 'Back',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: localPath != null
                  ? _viewer(Image.file(File(localPath!), fit: BoxFit.contain))
                  : _fromServer(ref, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fromServer(WidgetRef ref, ShadThemeData theme) {
    final id = fileId!;
    final async = ref.watch(fileBytesProvider(id));
    // The provider is kept alive and remembers a failed fetch as null, so a
    // Retry must invalidate it rather than just rebuild.
    Widget failed() => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Couldn't load the image.", style: theme.textTheme.muted),
              const SizedBox(height: 12),
              ShadButton.outline(
                onPressed: () => ref.invalidate(fileBytesProvider(id)),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
    return async.when(
      loading: () => Center(
        child: Text('Loading…', style: theme.textTheme.muted),
      ),
      error: (_, _) => failed(),
      data: (bytes) => bytes == null
          ? failed()
          : _viewer(Image.memory(bytes, fit: BoxFit.contain)),
    );
  }

  Widget _viewer(Widget image) {
    return InteractiveViewer(maxScale: 6, child: Center(child: image));
  }
}
