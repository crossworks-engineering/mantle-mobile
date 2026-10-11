import 'dart:math' show max;

/// A page's ProseMirror document as markdown, for the phone's renderer.
///
/// The brain's markdown export (`/api/export/:id`) is an Admin user's route:
/// a member reads a page as its ProseMirror `doc` (`GET /api/pages/:id`) and
/// may not export it. This turns that document into the markdown the page
/// view already renders, covering the common blocks and marks: headings,
/// paragraphs, lists (task lists too), quotes, code, rules, images, links,
/// bold, italic, strike and inline code. Anything else keeps its text, so a
/// node the phone does not know never hides words.
String proseMirrorToMarkdown(Object? doc) {
  if (doc is! Map) return '';
  final out = StringBuffer();
  _blocks(_content(doc), out, indent: '');
  return out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

List<Map> _content(Map node) {
  final c = node['content'];
  if (c is! List) return const [];
  return [
    for (final n in c)
      if (n is Map) n,
  ];
}

Map _attrs(Map node) {
  final a = node['attrs'];
  return a is Map ? a : const {};
}

void _blocks(List<Map> nodes, StringBuffer out, {required String indent}) {
  for (final node in nodes) {
    _block(node, out, indent: indent);
  }
}

void _block(Map node, StringBuffer out, {required String indent}) {
  final type = node['type'];
  switch (type) {
    case 'paragraph':
      out.write('$indent${_inline(_content(node))}\n\n');
    case 'heading':
      final raw = _attrs(node)['level'];
      final level = (raw is num ? raw.toInt() : 1).clamp(1, 6);
      out.write('$indent${'#' * level} ${_inline(_content(node))}\n\n');
    case 'bulletList':
      _list(node, out, indent: indent, ordered: false);
    case 'orderedList':
      _list(node, out, indent: indent, ordered: true);
    case 'taskList':
      _list(node, out, indent: indent, ordered: false, tasks: true);
    case 'blockquote':
      final inner = StringBuffer();
      _blocks(_content(node), inner, indent: '');
      for (final line in inner.toString().trimRight().split('\n')) {
        out.write('$indent> $line\n');
      }
      out.write('\n');
    case 'codeBlock':
      final lang = _attrs(node)['language'];
      final code = _plain(_content(node));
      // A fence longer than any run of backticks in the code: no line of it
      // can close the block and carry on as markdown.
      final fence = '`' * max(3, _longestBacktickRun(code) + 1);
      final info = lang is String ? lang.replaceAll(_notInfo, '') : '';
      out.write('$indent$fence$info\n');
      for (final line in code.split('\n')) {
        out.write('$indent$line\n');
      }
      out.write('$indent$fence\n\n');
    case 'horizontalRule':
      out.write('$indent---\n\n');
    case 'image':
      out.write('$indent${_image(node)}\n\n');
    default:
      // A block the phone does not know: its blocks, else its words.
      final children = _content(node);
      if (children.any((c) => c['type'] != 'text' && c['type'] != 'hardBreak')) {
        _blocks(children, out, indent: indent);
      } else {
        final text = children.isEmpty ? _label(node) : _inline(children);
        if (text.trim().isNotEmpty) out.write('$indent$text\n\n');
      }
  }
}

void _list(
  Map node,
  StringBuffer out, {
  required String indent,
  required bool ordered,
  bool tasks = false,
}) {
  final start = _attrs(node)['start'];
  var n = start is num ? start.toInt() : 1;
  for (final item in _content(node)) {
    final checked = _attrs(item)['checked'] == true;
    final marker = ordered
        ? '${n++}. '
        : tasks
            ? '- [${checked ? 'x' : ' '}] '
            : '- ';
    final inner = StringBuffer();
    _blocks(_content(item), inner, indent: '');
    final lines = inner.toString().trimRight().split('\n');
    final pad = ' ' * marker.length;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i == 0) {
        out.write('$indent$marker$line\n');
      } else if (line.isEmpty) {
        continue; // keep the list tight
      } else {
        out.write('$indent$pad$line\n');
      }
    }
  }
  out.write('\n');
}

String _inline(List<Map> nodes) {
  final out = StringBuffer();
  for (final node in nodes) {
    switch (node['type']) {
      case 'text':
        out.write(_marked(node));
      case 'hardBreak':
        out.write('  \n');
      case 'image':
        out.write(_image(node));
      default:
        final children = _content(node);
        out.write(children.isEmpty ? _label(node) : _inline(children));
    }
  }
  return out.toString();
}

String _plain(List<Map> nodes) => [
      for (final n in nodes)
        n['type'] == 'text'
            ? (n['text'] is String ? n['text'] as String : '')
            : n['type'] == 'hardBreak'
                ? '\n'
                : _plain(_content(n)),
    ].join();

/// The characters that would make literal text into markdown: an image or a
/// link (`![`, `[`, `](`), an autolink or inline HTML (`<`), emphasis, a
/// heading, a quote, code, strike.
final _markdownSyntax = RegExp(r'[\\*_\[\]()!#<>~`]');

/// [text] as it was typed: every character markdown would read as syntax is
/// escaped, so `![x](https://…)` typed in a paragraph stays those words and
/// never turns into a picture fetched from a host, or a link.
String _escaped(String text) =>
    text.replaceAllMapped(_markdownSyntax, (m) => '\\${m[0]}');

String _marked(Map node) {
  final raw = node['text'] is String ? node['text'] as String : '';
  if (raw.isEmpty) return '';
  final marks = node['marks'];
  final types = {
    if (marks is List)
      for (final m in marks)
        if (m is Map && m['type'] is String) m['type'] as String: m,
  };
  if (types.containsKey('code')) return _codeSpan(raw);
  var text = _escaped(raw);
  if (types.containsKey('bold')) text = '**$text**';
  if (types.containsKey('italic')) text = '*$text*';
  if (types.containsKey('strike')) text = '~~$text~~';
  final link = types['link'];
  if (link is Map) {
    final href = _attrs(link)['href'];
    final target = href is String ? _linkTarget(href) : null;
    // A link anywhere but the web or mail keeps its words, and goes nowhere.
    if (target != null) text = '[$text]($target)';
  }
  return text;
}

String _image(Map node) {
  final a = _attrs(node);
  final src = a['src'];
  if (src is! String || src.trim().isEmpty) return '';
  final alt = a['alt'] is String ? a['alt'] as String : '';
  return '![${_escaped(alt)}](${_destination(src.trim())})';
}

/// The schemes a link may lead to.
const _linkSchemes = {'http', 'https', 'mailto'};

final _scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*):');

/// [href] as a link destination, or null when it leads anywhere but the web,
/// mail or a path on the page's own brain (a script, a file, an app's own
/// scheme, another host without a scheme). A path on the brain (`/pages/<id>`
/// and the like) opens as the markdown renderer opens it anywhere else: in
/// the app when the phone has the screen, else on the brain's web.
String? _linkTarget(String href) {
  final trimmed = href.trim();
  if (_brainPath.hasMatch(trimmed)) return _destination(trimmed);
  final scheme = _scheme.firstMatch(trimmed)?.group(1)?.toLowerCase();
  if (scheme == null || !_linkSchemes.contains(scheme)) return null;
  return _destination(trimmed);
}

/// A path on the brain: one slash, never two (`//host` is another host) nor
/// a slash and a backslash (which some readers take for two).
final _brainPath = RegExp(r'^/(?![/\\])');

/// The characters that could end a `<...>` destination early, or break it
/// across lines.
final _notInDestination = RegExp(r'[<>\\ \r\n]');

/// [url] as a `<...>` destination: a `)`, a space or a quote inside it stays
/// part of the address, and whatever could end the brackets early is
/// percent-encoded.
String _destination(String url) => '<${url.replaceAllMapped(
      _notInDestination,
      (m) => '%${m[0]!.codeUnitAt(0).toRadixString(16).toUpperCase().padLeft(2, '0')}',
    )}>';

/// [raw] as inline code, fenced by more backticks than any run inside it, so
/// the code cannot close early and leave the rest to be read as markdown.
/// Padded with a space each side (which the reader drops) when it begins or
/// ends with a backtick, or with a space at both ends.
String _codeSpan(String raw) {
  final code = raw.replaceAll(RegExp(r'[\r\n]'), ' ');
  final fence = '`' * (_longestBacktickRun(code) + 1);
  final pad = code.startsWith('`') ||
      code.endsWith('`') ||
      (code.startsWith(' ') && code.endsWith(' ') && code.trim().isNotEmpty);
  return pad ? '$fence $code $fence' : '$fence$code$fence';
}

/// The longest run of backticks in [text].
int _longestBacktickRun(String text) {
  var longest = 0;
  var run = 0;
  for (final unit in text.codeUnits) {
    if (unit == 0x60) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 0;
    }
  }
  return longest;
}

/// What may not stand in a code block's language: a backtick or a space
/// would end the fence's info string, so it keeps only a name's characters.
final _notInfo = RegExp(r'[^A-Za-z0-9_+.#\-]');

/// The words a leaf node without text carries (a mention's label, a chip's
/// title).
String _label(Map node) {
  final a = _attrs(node);
  for (final key in ['label', 'title', 'name', 'text']) {
    final v = a[key];
    if (v is String && v.isNotEmpty) return _escaped(v);
  }
  return '';
}
