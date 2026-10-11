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
      out.write('$indent```${lang is String ? lang : ''}\n');
      for (final line in code.split('\n')) {
        out.write('$indent$line\n');
      }
      out.write('$indent```\n\n');
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

String _marked(Map node) {
  var text = node['text'] is String ? node['text'] as String : '';
  if (text.isEmpty) return '';
  final marks = node['marks'];
  if (marks is! List) return text;
  final types = {
    for (final m in marks)
      if (m is Map && m['type'] is String) m['type'] as String: m,
  };
  if (types.containsKey('code')) return '`$text`';
  if (types.containsKey('bold')) text = '**$text**';
  if (types.containsKey('italic')) text = '*$text*';
  if (types.containsKey('strike')) text = '~~$text~~';
  final link = types['link'];
  if (link is Map) {
    final href = _attrs(link)['href'];
    if (href is String && href.isNotEmpty) text = '[$text]($href)';
  }
  return text;
}

String _image(Map node) {
  final a = _attrs(node);
  final src = a['src'];
  if (src is! String || src.isEmpty) return '';
  final alt = a['alt'] is String ? a['alt'] as String : '';
  return '![$alt]($src)';
}

/// The words a leaf node without text carries (a mention's label, a chip's
/// title).
String _label(Map node) {
  final a = _attrs(node);
  for (final key in ['label', 'title', 'name', 'text']) {
    final v = a[key];
    if (v is String && v.isNotEmpty) return v;
  }
  return '';
}
