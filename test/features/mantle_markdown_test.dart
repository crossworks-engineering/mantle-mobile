// MantleMarkdown renders GFM into themed widgets without throwing.

import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/features/chat/markdown/mantle_markdown.dart';
import 'package:mantle_companion/theme/mantle_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> _pump(WidgetTester tester, String markdown) async {
  await tester.pumpWidget(
    ShadApp(theme: MantleTheme.light(), home: MantleMarkdown(markdown)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a paragraph with inline emphasis', (tester) async {
    await _pump(tester, 'Hello **world** and `code`.');

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(
      find.textContaining('Hello', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a GFM table as a Table widget', (tester) async {
    await _pump(tester, '| A | B |\n|---|---|\n| 1 | 2 |');

    expect(find.byType(Table), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a callout with its variant icon and body', (tester) async {
    await _pump(tester, ':::warning\nwatch **out**\n:::');

    expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
    expect(find.textContaining('watch', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown callout variant falls back to info', (tester) async {
    await _pump(tester, ':::bogus\nhi\n:::');

    expect(find.byIcon(LucideIcons.info), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders aside and columns containers', (tester) async {
    await _pump(tester, ':::aside chart-3\nnote\n:::');
    expect(find.textContaining('note', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pump(tester, ':::columns\nleft\n+++\nright\n:::');
    expect(find.textContaining('left', findRichText: true), findsOneWidget);
    expect(find.textContaining('right', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders inline highlight and colour spans', (tester) async {
    await _pump(
      tester,
      'a ==marked== b and [tinted]{color=chart-2} c and [hl]{highlight=chart-4} d',
    );

    expect(find.textContaining('marked', findRichText: true), findsOneWidget);
    expect(find.textContaining('tinted', findRichText: true), findsOneWidget);
    expect(find.textContaining('hl', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an invalid colour token is left as plain text', (tester) async {
    await _pump(tester, 'keep [x]{foo=bar} literal');

    // No crash, and the braces survive as ordinary text (not consumed as a span).
    expect(find.textContaining('foo=bar', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a rich document without throwing', (tester) async {
    await _pump(tester, '''
# Heading

A paragraph with a [link](https://example.com) and ~~strike~~.

- bullet one
- bullet two

- [x] done
- [ ] todo

> a quote

```dart
void main() {}
```

---
''');

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
