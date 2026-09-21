import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/chat/chat_api.dart' show fileBytesProvider;
import '../../../data/files/files_api.dart';
import '../../../data/nodes/nodes_api.dart';
import '../../../data/server/server_config.dart';
import '../../files/file_open_sheet.dart';
import '../../../widgets/bytes_image.dart';
import 'mantle_refs.dart';

/// Renders a `mantleRef` element (see [RefInlineSyntax]): an image for
/// `![…](media:|draw:)`, otherwise a chip named for what it points at, which
/// opens the target in-app when the phone has a screen for it and on the web
/// otherwise. Never a dead link, never raw round-trip syntax.
class RefBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final kind = element.attributes['kind'] ?? '';
    final id = element.attributes['id'] ?? '';
    final label = element.attributes['label'] ?? '';
    if (element.attributes['image'] == 'true') {
      return MantleImage(
        uri: Uri(scheme: kind, path: id),
        alt: label,
      );
    }
    return RefChip(
      kind: kind,
      id: id,
      label: label,
      ref: element.attributes['ref'],
    );
  }
}

/// The chip: an icon for the kind, the label, and a tap that goes somewhere.
///
/// - page → the page screen.
/// - mention:node → resolved by type through `/api/nodes/{id}`; a type the
///   phone has no screen for opens the web permalink.
/// - mention:entity → not tappable (no entity screen); reads as a name tag.
/// - media → the image screen when the name says picture, else the file open
///   sheet (download and hand to the phone's viewer). The chip holds only an
///   id and a name, so the row is fetched first; if that fails, the web
///   permalink.
/// - draw → the web permalink (drawings are edited on the web).
class RefChip extends ConsumerWidget {
  const RefChip({
    super.key,
    required this.kind,
    required this.id,
    required this.label,
    this.ref,
  });

  final String kind;
  final String id;
  final String label;
  final String? ref;

  bool get _navigable => !(kind == 'mention' && ref == 'entity');

  IconData get _icon => switch (kind) {
    'page' => LucideIcons.fileText,
    'media' =>
      looksLikeImage(label) ? LucideIcons.image : LucideIcons.paperclip,
    'draw' => LucideIcons.penTool,
    _ => ref == 'entity' ? LucideIcons.atSign : LucideIcons.link2,
  };

  String get _semantics => switch (kind) {
    'page' => 'Open page $label',
    'media' => 'Open file $label',
    'draw' => 'Open drawing $label on the web',
    _ => ref == 'entity' ? label : 'Open $label',
  };

  Future<void> _open(BuildContext context, WidgetRef widgetRef) async {
    switch (kind) {
      case 'page':
        _push(context, '/pages/$id');
      case 'media':
        if (looksLikeImage(label)) {
          _push(
            context,
            '/files/image/$id?name=${Uri.encodeQueryComponent(label)}',
          );
        } else {
          try {
            final row = await widgetRef.read(filesApiProvider).meta(id);
            if (context.mounted) await showFileOpenSheet(context, row);
          } catch (_) {
            await openNodeOnWeb(widgetRef, id);
          }
        }
      case 'draw':
        await openNodeOnWeb(widgetRef, id);
      default:
        if (ref == 'node') await openNode(context, widgetRef, id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final fg = _navigable ? scheme.primary : scheme.secondaryForeground;
    final chip = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.small.copyWith(
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    // The label IS the announcement: exclude the child text, or the node
    // reads as "Open X" plus "X" and a screen reader says the name twice.
    if (!_navigable) {
      return Semantics(
        container: true,
        label: _semantics,
        excludeSemantics: true,
        child: chip,
      );
    }
    return Semantics(
      button: true,
      label: _semantics,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context, widgetRef),
        child: chip,
      ),
    );
  }
}

/// An image in markdown. Three sources: `media:<fileId>` (and the older
/// `/api/files/files/<id>` form) fetch through the authed byte provider,
/// since an `Image.network` cannot send the bearer; `draw:<drawId>` fetches
/// the drawing's SVG snapshot; plain http(s) loads directly. A fetch that
/// fails shows a chip with the alt text, never an endless spinner.
class MantleImage extends ConsumerWidget {
  const MantleImage({super.key, required this.uri, this.alt});

  final Uri uri;
  final String? alt;

  String? get _fileId {
    if (uri.scheme == 'media') return uri.path;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 4 &&
        segments[0] == 'api' &&
        segments[1] == 'files' &&
        segments[2] == 'files') {
      return segments[3];
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final fileId = _fileId;
    if (fileId != null) {
      final bytes = ref.watch(fileBytesProvider(fileId));
      final data = bytes.value;
      if (data == null) return _chip(theme, loading: bytes.isLoading);
      return _frame(
        Semantics(
          button: true,
          label: 'Open image ${alt ?? ''}'.trim(),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _push(
              context,
              '/files/image/$fileId?name=${Uri.encodeQueryComponent(alt ?? 'Image')}',
            ),
            child: BytesImage(data, onError: (_) => _chip(theme)),
          ),
        ),
      );
    }
    if (uri.scheme == 'draw') {
      final svg = ref.watch(drawSvgProvider(uri.path));
      final data = svg.value;
      if (data == null) {
        return _chip(theme, loading: svg.isLoading, icon: LucideIcons.penTool);
      }
      return _frame(SvgPicture.string(data, fit: BoxFit.contain));
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return _frame(
        Image.network(
          uri.toString(),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _chip(theme),
        ),
      );
    }
    return _chip(theme);
  }

  Widget _frame(Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(width: double.infinity, child: child),
  );

  Widget _chip(
    ShadThemeData theme, {
    bool loading = false,
    IconData icon = LucideIcons.image,
  }) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.mutedForeground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              loading
                  ? 'Loading image…'
                  : (alt?.isNotEmpty == true ? alt! : 'Image'),
              style: theme.textTheme.muted,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a tapped markdown href the way the phone can: external links to the
/// OS, `/pages/<id>` and `/notes/<id>` in-app, `/n/<id>` resolved by type,
/// any other brain path on the web, anchors nowhere.
Future<void> openMarkdownLink(
  BuildContext context,
  WidgetRef ref,
  String? href,
) async {
  switch (MantleLink.parse(href)) {
    case ExternalLink(:final uri):
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    case InAppLink(:final route):
      _push(context, route);
    case NodeLink(:final id):
      await openNode(context, ref, id);
    case WebLink(:final path):
      await openPathOnWeb(ref, path);
    case AnchorLink():
    case UnknownLink():
      break;
  }
}

/// Route a node by its type: in-app when the phone has the screen, else the
/// web's `/n/<id>` permalink (which is also where an unresolvable id goes).
Future<void> openNode(BuildContext context, WidgetRef ref, String id) async {
  String? route;
  try {
    final node = await ref.read(nodesApiProvider).resolve(id);
    route = routeForNode(node.type, node.id);
  } catch (_) {
    route = null;
  }
  if (route != null) {
    if (context.mounted) _push(context, route);
    return;
  }
  await openNodeOnWeb(ref, id);
}

Future<void> openNodeOnWeb(WidgetRef ref, String id) =>
    openPathOnWeb(ref, '/n/$id');

/// Open a brain path in the browser, against the configured server.
Future<void> openPathOnWeb(WidgetRef ref, String path) async {
  final base = ref.read(serverConfigProvider).value;
  if (base == null || base.isEmpty) return;
  final uri = Uri.tryParse('$base$path');
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Push through go_router when there is one (the app); no-op otherwise (a
/// test host), so a chip never throws for want of a router.
void _push(BuildContext context, String route) {
  final router = GoRouter.maybeOf(context);
  if (router != null) router.push(route);
}
