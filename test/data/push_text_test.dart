import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/push/push_text.dart';

void main() {
  group('pushNotificationText', () {
    test('passes a normal payload through', () {
      final t = pushNotificationText({'t': 'Morph', 'b': 'hello there'});
      expect(t.title, 'Morph');
      expect(t.body, 'hello there');
    });

    test('falls back when a field is missing', () {
      final t = pushNotificationText({});
      expect(t.title, pushDefaultTitle);
      expect(t.body, pushDefaultBody);
    });

    test('falls back when the body is blank, not only when it is missing', () {
      // A server that pushes on the reply's pending insert seals b: "".
      // Seen on the S20 Ultra against dev v0.232.191: "Morph" over nothing.
      expect(pushNotificationText({'t': 'Morph', 'b': ''}).body, pushDefaultBody);
      expect(pushNotificationText({'t': 'Morph', 'b': '  \n\t '}).body, pushDefaultBody);
      expect(pushNotificationText({'t': '', 'b': 'x'}).title, pushDefaultTitle);
    });

    test('ignores non-string fields', () {
      final t = pushNotificationText({'t': 42, 'b': null});
      expect(t.title, pushDefaultTitle);
      expect(t.body, pushDefaultBody);
    });

    test('collapses whitespace and cuts a long body with an ellipsis', () {
      expect(pushNotificationText({'b': 'a  b\n\nc'}).body, 'a b c');
      final long = List.filled(200, 'x').join();
      final body = pushNotificationText({'b': long}).body;
      expect(body.length, 140);
      expect(body.endsWith('…'), isTrue);
      expect(pushNotificationText({'b': long}, maxBody: 10).body, 'xxxxxxxxx…');
    });

    test('keeps a body exactly at the limit', () {
      final exact = List.filled(140, 'y').join();
      expect(pushNotificationText({'b': exact}).body, exact);
    });

    test('the cut counts graphemes, so an emoji is never cut in half', () {
      // An emoji with a skin tone is one grapheme, two scalars, four UTF-16
      // units. A cut on UTF-16 units left half of one before the ellipsis.
      const thumb = '\u{1F44D}\u{1F3FD}';
      final mixed = '${List.filled(138, 'x').join()}$thumb$thumb$thumb';
      expect(
        pushNotificationText({'b': mixed}).body,
        '${List.filled(138, 'x').join()}$thumb…',
      );
      final emoji = pushNotificationText({'b': List.filled(200, thumb).join()});
      expect(emoji.body.characters.length, 140);
      expect(emoji.body, '${List.filled(139, thumb).join()}…');
    });
  });

  group('headForPlain', () {
    test('a text within the limit is untouched', () {
      final s = List.filled(plainInputLimit, 'a').join();
      expect(headForPlain(s), same(s));
    });

    test('a long text keeps its first scalars, a surrogate pair whole', () {
      final s = '${List.filled(plainInputLimit - 1, 'a').join()}\u{1F389}tail';
      expect(headForPlain(s), '${List.filled(plainInputLimit - 1, 'a').join()}\u{1F389}');
    });

    test('unmatched brackets are cut before the rules run, so it is quick', () {
      // The link rules are quadratic on unmatched `[`: 50,000 of them took
      // over a minute before the input was cut.
      final hostile = List.filled(50000, '[').join();
      final watch = Stopwatch()..start();
      final out = plainFromMarkdown(hostile);
      watch.stop();
      expect(out.length, plainInputLimit);
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(pushNotificationText({'b': hostile}).body.characters.length, 140);
    });
  });

  // The same cases are run against the Swift twin for the iOS extension by
  // tool/check_push_text_swift.sh; change both together.
  group('plainFromMarkdown', () {
    String plain(String md) =>
        plainFromMarkdown(md).replaceAll(RegExp(r'\s+'), ' ').trim();

    test('a heading and a list, as the whole reply', () {
      expect(
        plain('## Plan for today\n\n- Call the supplier\n- [x] Send the quote\n1. Review'),
        'Plan for today Call the supplier Send the quote Review',
      );
    });

    test('bold, italics, strikethrough and inline code lose their marks', () {
      expect(
        plain('**Done.** I _moved_ the *two* files and ~~kept~~ dropped `tmp.txt`.'),
        'Done. I moved the two files and kept dropped tmp.txt.',
      );
      // Not emphasis: a snake_case name and a multiplication.
      expect(plain('set max_retry_count to 3 * 4'), 'set max_retry_count to 3 * 4');
    });

    test('a link is its text; an image is its alt text, or nothing', () {
      expect(
        plain('See [the release notes](https://example.com/notes) and ![chart](media:abc).'),
        'See the release notes and chart.',
      );
      expect(plain('Before ![](media:abc) after'), 'Before after');
    });

    test('a reference chip keeps its label', () {
      expect(
        plain('Filed under [Acme Corp](page:9f3c2d10) by [Thabo](mention:entity:77).'),
        'Filed under Acme Corp by Thabo.',
      );
      expect(plain('[Folder index](folder:here)'), 'Folder index');
    });

    test('a code fence keeps the code, not the fence', () {
      expect(
        plain('Run this:\n```bash\npnpm verify\n```\nthen push.'),
        'Run this: pnpm verify then push.',
      );
    });

    test('a table is its cells', () {
      expect(
        plain('| Item | Cost |\n| --- | ---: |\n| Paint | 120 |'),
        'Item Cost Paint 120',
      );
    });

    test('a block quote and a rule', () {
      expect(plain('> Quoted line\n\n---\n\nAfter'), 'Quoted line After');
    });

    test('math keeps its source; money is left alone', () {
      expect(plain(r'Area is $\pi r^2$ and $$E=mc^2$$.'), r'Area is \pi r^2 and E=mc^2 .');
      expect(plain(r'It costs $5 and $6.50 in total.'), r'It costs $5 and $6.50 in total.');
    });

    test('Mantle callouts, highlights and coloured spans', () {
      expect(
        plain(':::warning\nCheck the ==due date== and the [total]{color=chart-2}.\n:::'),
        'Check the due date and the total.',
      );
    });

    test('a teaser the brain already flattened to one line', () {
      // Whitespace collapsed and no markdown stripped: block marks sit
      // mid-line.
      expect(
        plain('Here is the plan. ## Next steps - **Call** the supplier - Send `quote.pdf`'),
        'Here is the plan. Next steps - Call the supplier - Send quote.pdf',
      );
      expect(
        plain('| Item | Cost | | --- | --- | | Paint | 120 |'),
        'Item Cost Paint 120',
      );
    });

    test('a teaser cut in the middle of a token', () {
      expect(plain('All set. See [the plan](page:9f3c2d'), 'All set. See the plan');
      expect(plain('All set, and **this part is impor'), 'All set, and this part is impor');
      expect(plain('Use `flutter build ap'), 'Use flutter build ap');
    });

    test('an escaped mark is the mark', () {
      expect(plain(r'2 \* 3 is not \*emphasis\*'), '2 * 3 is not *emphasis*');
    });

    test('text in other scripts, accents and emoji keep their words', () {
      expect(
        plain('**Größe** und _naïve_ café, 日本語 \u{1F389}'),
        'Größe und naïve café, 日本語 \u{1F389}',
      );
    });

    test('a letter in any script is a word character next to a mark', () {
      // As in ASCII (`max_retry_count`), an underscore or star inside a word
      // is not emphasis, whatever the script; Swift's \w is Unicode, Dart's
      // is not, so both sides spell the class out.
      expect(plain('_über_ and Zoë_x_ and ü*a* stay'), 'über and Zoë_x_ and ü*a* stay');
    });

    test('plain words pass through untouched', () {
      expect(plain('Lunch is at 12:30, table for 4 - see you there!'),
          'Lunch is at 12:30, table for 4 - see you there!');
    });
  });

  test('a push shows plain words, then is cut', () {
    final t = pushNotificationText({
      't': '**Saskia**',
      'b': '## Done\n\nI filed it under [Acme Corp](page:9f3c2d10) and sent `quote.pdf`.',
    });
    expect(t.title, 'Saskia');
    expect(t.body, 'Done I filed it under Acme Corp and sent quote.pdf.');

    // The cut counts plain characters, not the markdown that was removed.
    final long = pushNotificationText({'b': '**${List.filled(200, 'x').join()}**'});
    expect(long.body.length, 140);
    expect(long.body.startsWith('x'), isTrue);
  });
}
