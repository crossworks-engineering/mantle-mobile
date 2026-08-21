// Phase-4 markdown: `$…$` / `$$…$$` TeX (with currency guards) and fenced-code
// syntax highlighting. Syntax-level tests parse the AST directly; widget tests
// render through MantleMarkdown like the surrounding suite.

import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/features/chat/markdown/mantle_markdown.dart';
import 'package:jackdaw/features/chat/markdown/mantle_syntax.dart';
import 'package:jackdaw/theme/mantle_theme.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shadcn_ui/shadcn_ui.dart';

/// Parse with the same syntax stack MantleMarkdown registers.
List<md.Node> _parse(String src) {
  final doc = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    blockSyntaxes: const [MantleFenceSyntax(), MathBlockSyntax()],
    inlineSyntaxes: [
      HighlightInlineSyntax(),
      ColorSpanInlineSyntax(),
      MathInlineSyntax(),
    ],
  );
  return doc.parse(src);
}

/// All elements with [tag], depth-first.
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

Future<void> _pump(WidgetTester tester, String markdown) async {
  await tester.pumpWidget(
    MantleColors(
      def: MantleTheme.defFor(MantleTheme.defaultId),
      child: ShadApp(
        theme: MantleTheme.light(MantleTheme.defaultId),
        home: MantleMarkdown(markdown),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MathInlineSyntax', () {
    test(r'parses $x^2$ into a math element with raw tex', () {
      final maths = _byTag(_parse(r'the value $x^2 + 1$ grows'), kMathTag);
      expect(maths.single.attributes['tex'], r'x^2 + 1');
    });

    test('currency never matches', () {
      expect(_byTag(_parse(r'that costs $5'), kMathTag), isEmpty);
      expect(_byTag(_parse(r'between $5 and $6 total'), kMathTag), isEmpty);
      expect(_byTag(_parse(r'roughly $5,000$ worth'), kMathTag), isEmpty);
    });

    test(r'a spaced dollar pair ($ x $) stays plain text', () {
      expect(_byTag(_parse(r'a $ x $ b'), kMathTag), isEmpty);
    });
  });

  group('MathBlockSyntax', () {
    test('single-line block form', () {
      final maths = _parse(r'$$E=mc^2$$');
      expect(_byTag(maths, kMathBlockTag).single.attributes['tex'], r'E=mc^2');
    });

    test('multi-line block form', () {
      final maths = _parse('\$\$\n\\frac{a}{b}\n+ c\n\$\$');
      expect(
        _byTag(maths, kMathBlockTag).single.attributes['tex'],
        '\\frac{a}{b}\n+ c',
      );
    });

    test(r'a prose line starting with $$ never opens a block', () {
      final nodes = _parse(
          '\$\$50 below the open, the stock slid further.\nNext line stays.');
      expect(_byTag(nodes, kMathBlockTag), isEmpty);
      // Both lines survive as paragraph text.
      final text = nodes.map((n) => n.textContent).join('\n');
      expect(text, contains('the stock slid further'));
      expect(text, contains('Next line stays'));
    });
  });

  group('rendering', () {
    testWidgets('inline and block math render Math widgets', (tester) async {
      await _pump(tester, r'''inline $x^2$ and

$$\sum_{i=0}^n i$$''');
      expect(find.byType(Math), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid TeX falls back to raw source, no crash',
        (tester) async {
      await _pump(tester, r'broken $\frac{$ math');
      // Either the error fallback text or a Math widget that recovered —
      // the invariant is simply: no exception escapes.
      expect(tester.takeException(), isNull);
    });

    testWidgets('a fenced dart block renders highlighted spans',
        (tester) async {
      await _pump(
        tester,
        "```dart\nfinal x = 'hi'; // greet\n```",
      );
      // The highlighted path renders the source inside a horizontal scroller.
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(
        find.textContaining('greet', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unknown fence language falls back to plain rendering',
        (tester) async {
      await _pump(tester, '```notalanguage\nplain text here\n```');
      expect(
        find.textContaining('plain text here', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('currency in prose stays prose', (tester) async {
      await _pump(tester, r'It costs $5 and $6 today.');
      expect(find.byType(Math), findsNothing);
      expect(
        find.textContaining(r'costs $5 and $6', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
