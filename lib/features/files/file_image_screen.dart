import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/chat/chat_api.dart' show fileBytesProvider;
import '../../widgets/mantle_header.dart';

/// Full-screen authed image preview: bytes via the existing
/// `fileBytesProvider` (`GET /api/files/files/{id}?raw=1` with the Bearer
/// header), pinch-to-zoom via [InteractiveViewer].
class FileImageScreen extends ConsumerWidget {
  const FileImageScreen({super.key, required this.fileId, this.name});

  final String fileId;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.primaryForeground;
    final async = ref.watch(fileBytesProvider(fileId));

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: MantleHeaderTitle(name ?? 'Image', wordmark: false),
            trailing: [
              ShadButton.ghost(
                onPressed: () => context.pop(),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: fg),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: async.when(
                loading: () => Center(
                  child: Text('Loading…', style: theme.textTheme.muted),
                ),
                error: (e, _) => Center(
                  child: Text("Couldn't load the image.",
                      style: theme.textTheme.muted),
                ),
                data: (bytes) => bytes == null
                    ? Center(
                        child: Text("Couldn't load the image.",
                            style: theme.textTheme.muted),
                      )
                    : InteractiveViewer(
                        maxScale: 6,
                        child: Center(
                          child: Image.memory(bytes, fit: BoxFit.contain),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
