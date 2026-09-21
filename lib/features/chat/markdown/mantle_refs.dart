// Mantle's REFERENCE links — the round-trip syntaxes the server's markdown
// export invents for editor-only nodes, so a chip survives a markdown edit
// instead of flattening to its label (mantle `doc-to-markdown.ts`):
//
//   [Title](page:<pageId>)                  child page
//   [label](mention:node:<id>)              node mention (note/task/page/…)
//   [label](mention:entity:<id>)            entity mention (person/org/…)
//   [filename](media:<fileId>)              file embed
//   ![alt](media:<fileId>)                  uploaded image
//   ![alt](draw:<drawId>)                   embedded drawing (SVG snapshot)
//
// Left to the stock link syntax they render as dead links (`page:` is not a
// scheme the phone can launch). This syntax runs BEFORE the stock one and
// lifts them into `mantleRef` elements the renderer draws as chips or
// images. Plus [MantleLink], the classification `_openLink` uses for every
// other href: external, in-app route, node permalink, web-only path, anchor.
//
// Parser-only, no Flutter deps (like mantle_syntax.dart); rendering lives in
// ref_widgets.dart.

import 'package:markdown/markdown.dart' as md;

/// Element tag for a reference chip/image; the renderer registers a builder.
const String kRefTag = 'mantleRef';

/// `[label](scheme:…)` with an optional leading `!`. The label may contain
/// escaped brackets (`\[`) — the export escapes them — but no raw `]`.
/// Anchors (`[text](#…)`) are matched too, and emitted as PLAIN TEXT: a page
/// has no in-app anchors, so the words must not look tappable.
class RefInlineSyntax extends md.InlineSyntax {
  RefInlineSyntax()
      : super(
          r'(!?)\[((?:\\.|[^\]\\])*)\]\((?:(page|media|draw):([^)\s]+)|mention:(node|entity):([^)\s]+)|(#[^)\s]*))\)',
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final label = _unescape(match[2] ?? '');
    if (match[7] != null) {
      // Anchor: the words, nothing else. Consumed, so the parser moves on.
      parser.addNode(md.Text(label));
      return true;
    }
    final element = md.Element.empty(kRefTag)..attributes['label'] = label;
    if (match[3] != null) {
      element.attributes['kind'] = match[3]!; // page | media | draw
      element.attributes['id'] = match[4]!;
    } else {
      element.attributes['kind'] = 'mention';
      element.attributes['ref'] = match[5]!; // node | entity
      element.attributes['id'] = match[6]!;
    }
    if (match[1] == '!') element.attributes['image'] = 'true';
    parser.addNode(element);
    return true;
  }

  static String _unescape(String s) => s.replaceAllMapped(
        RegExp(r'\\(.)'),
        (m) => m[1]!,
      );
}

/// What a tapped href means on the phone.
sealed class MantleLink {
  const MantleLink();

  /// http / https / mailto — hand to the OS.
  static MantleLink parse(String? href) {
    if (href == null || href.trim().isEmpty) return const UnknownLink();
    final s = href.trim();
    if (s.startsWith('#')) return const AnchorLink();
    final uri = Uri.tryParse(s);
    if (uri == null) return const UnknownLink();
    if (uri.hasScheme) {
      const external = {'http', 'https', 'mailto'};
      return external.contains(uri.scheme)
          ? ExternalLink(uri)
          : const UnknownLink();
    }
    if (!s.startsWith('/') || s.startsWith('//')) return const UnknownLink();
    final segments = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    if (segments.length == 2) {
      final id = segments[1];
      switch (segments[0]) {
        case 'pages':
          return InAppLink('/pages/$id');
        case 'notes':
          return InAppLink('/notes/$id');
        case 'n':
          return NodeLink(id);
      }
    }
    // Any other path on the brain: the web has a surface for it, the phone
    // does not (tables, formulas, secrets, …).
    return WebLink(uri.path + (uri.hasQuery ? '?${uri.query}' : ''));
  }
}

class ExternalLink extends MantleLink {
  const ExternalLink(this.uri);
  final Uri uri;
}

/// A route this app owns.
class InAppLink extends MantleLink {
  const InAppLink(this.route);
  final String route;
}

/// `/n/<id>` — type-blind; resolve the node's type, then route.
class NodeLink extends MantleLink {
  const NodeLink(this.id);
  final String id;
}

/// A brain path with no phone surface — opens on the web.
class WebLink extends MantleLink {
  const WebLink(this.path);
  final String path;
}

/// `#…` — no-op on the phone.
class AnchorLink extends MantleLink {
  const AnchorLink();
}

class UnknownLink extends MantleLink {
  const UnknownLink();
}

/// The in-app route for a node of [type], or null when the phone has no
/// screen for it (the caller opens the web's `/n/<id>` instead). Mirrors the
/// web's `surfaceFor` in `client/web/app/(app)/n/[id]/page.tsx`, reduced to
/// the surfaces the phone has; task/event/journal open their list (no
/// per-row route yet).
String? routeForNode(String type, String id) {
  switch (type) {
    case 'page':
      return '/pages/$id';
    case 'note':
      return '/notes/$id';
    case 'task':
      return '/tasks';
    case 'event':
      return '/events';
    case 'journal':
      return '/journal';
    default:
      return null;
  }
}

/// Whether a file's name says it is a picture the image screen can show.
bool looksLikeImage(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return const {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic', 'svg'}
      .contains(ext);
}
