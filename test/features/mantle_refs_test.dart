// The reference syntax and link classification, at the AST level: each
// round-trip form the server's export invents becomes a mantleRef element
// with the right attributes, anchors become plain words, and every other
// href is sorted into external / in-app / node / web / anchor.

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/features/chat/markdown/mantle_refs.dart';
import 'package:jackdaw/features/chat/markdown/mantle_syntax.dart';
import 'package:markdown/markdown.dart' as md;

List<md.Node> _parse(String src) => md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      blockSyntaxes: const [MantleFenceSyntax(), MathBlockSyntax()],
      inlineSyntaxes: [
        RefInlineSyntax(),
        HighlightInlineSyntax(),
        ColorSpanInlineSyntax(),
        MathInlineSyntax(),
      ],
    ).parse(src);

List<md.Element> _byTag(List<md.Node> nodes, String tag) {
  final found = <md.Element>[];
  void walk(md.Node n) {
    if (n is md.Element) {
      if (n.tag == tag) found.add(n);
      n.children?.forEach(walk);
    }
  }

  nodes.forEach(walk);
  return found;
}

md.Element _ref(String src) => _byTag(_parse(src), kRefTag).single;

void main() {
  group('RefInlineSyntax', () {
    test('[Title](page:<id>) is a page ref', () {
      final e = _ref('[The client repos](page:64b3255b-927f-46eb-a4f2-0e04d8515a2d)');
      expect(e.attributes['kind'], 'page');
      expect(e.attributes['id'], '64b3255b-927f-46eb-a4f2-0e04d8515a2d');
      expect(e.attributes['label'], 'The client repos');
      expect(e.attributes.containsKey('image'), isFalse);
    });

    test('mention:node and mention:entity keep the ref kind', () {
      final node = _ref('see [Jackdaw Colours](mention:node:916d094a)');
      expect(node.attributes['kind'], 'mention');
      expect(node.attributes['ref'], 'node');
      expect(node.attributes['id'], '916d094a');

      final entity = _ref('by [Jason Schoeman](mention:entity:1aa6287a)');
      expect(entity.attributes['ref'], 'entity');
      expect(entity.attributes['label'], 'Jason Schoeman');
    });

    test('[name](media:<id>) is a file ref; ![alt](media:<id>) an image', () {
      final file = _ref('[jackdaw-brand.md](media:8cc116ef)');
      expect(file.attributes['kind'], 'media');
      expect(file.attributes.containsKey('image'), isFalse);

      final image = _ref('![Pinnacle brain pyramid](media:87e0f992)');
      expect(image.attributes['kind'], 'media');
      expect(image.attributes['image'], 'true');
      expect(image.attributes['label'], 'Pinnacle brain pyramid');
      // The leading `!` is consumed, not left behind as stray text.
      final texts = _parse('![alt](media:87e0f992)').whereType<md.Element>();
      expect(texts.first.textContent.contains('!'), isFalse);
    });

    test('![alt](draw:<id>) is a drawing image', () {
      final e = _ref('![A drawing](draw:5483e1d6)');
      expect(e.attributes['kind'], 'draw');
      expect(e.attributes['image'], 'true');
    });

    test('escaped brackets in the label are unescaped', () {
      final e = _ref(r'[a \[bracketed\] title](page:abc)');
      expect(e.attributes['label'], 'a [bracketed] title');
    });

    test('[text](#anchor) becomes plain text, no link, no ref', () {
      final nodes = _parse('go [back to top](#golden-page) now');
      expect(_byTag(nodes, kRefTag), isEmpty);
      expect(_byTag(nodes, 'a'), isEmpty);
      expect(nodes.first.textContent, 'go back to top now');
    });

    test('ordinary links are untouched', () {
      final nodes = _parse('a [themed link](https://example.com) and '
          '[a page](/pages/abc)');
      expect(_byTag(nodes, kRefTag), isEmpty);
      final links = _byTag(nodes, 'a');
      expect(links.map((l) => l.attributes['href']),
          ['https://example.com', '/pages/abc']);
    });

    test('a colour span still wins over a ref-shaped label', () {
      final nodes = _parse('[tinted]{color=chart-2}');
      expect(_byTag(nodes, kSpanTag), hasLength(1));
      expect(_byTag(nodes, kRefTag), isEmpty);
    });
  });

  group('MantleLink.parse', () {
    test('external schemes go to the OS', () {
      expect(MantleLink.parse('https://example.com'), isA<ExternalLink>());
      expect(MantleLink.parse('mailto:a@b.c'), isA<ExternalLink>());
      expect(MantleLink.parse('ftp://x'), isA<UnknownLink>());
    });

    test('/pages and /notes route in-app', () {
      expect((MantleLink.parse('/pages/abc') as InAppLink).route, '/pages/abc');
      expect((MantleLink.parse('/notes/abc') as InAppLink).route, '/notes/abc');
    });

    test('/n/<id> is a node permalink to resolve', () {
      expect((MantleLink.parse('/n/abc') as NodeLink).id, 'abc');
    });

    test('other brain paths open on the web, query kept', () {
      expect((MantleLink.parse('/tables') as WebLink).path, '/tables');
      expect((MantleLink.parse('/notes?selected=x') as WebLink).path,
          '/notes?selected=x');
    });

    test('anchors, protocol-relative and junk are inert', () {
      expect(MantleLink.parse('#top'), isA<AnchorLink>());
      expect(MantleLink.parse('//evil.example'), isA<UnknownLink>());
      expect(MantleLink.parse(''), isA<UnknownLink>());
      expect(MantleLink.parse(null), isA<UnknownLink>());
    });
  });

  group('routeForNode', () {
    test('maps the phone surfaces and nothing else', () {
      expect(routeForNode('page', 'x'), '/pages/x');
      expect(routeForNode('note', 'x'), '/notes/x');
      expect(routeForNode('task', 'x'), '/tasks');
      expect(routeForNode('event', 'x'), '/events');
      expect(routeForNode('journal', 'x'), '/journal');
      expect(routeForNode('table', 'x'), isNull);
      expect(routeForNode('file', 'x'), isNull);
    });
  });

  test('looksLikeImage goes by extension', () {
    expect(looksLikeImage('photo.PNG'), isTrue);
    expect(looksLikeImage('jackdaw-brand.md'), isFalse);
    expect(looksLikeImage('noext'), isFalse);
  });
}
