// A page's ProseMirror document as markdown (what a member reads, the
// markdown export being an Admin user's route).

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' show markdownToHtml;
import 'package:jackdaw/data/pages/prosemirror_markdown.dart';

Map<String, dynamic> _t(String text, [List<String> marks = const []]) => {
      'type': 'text',
      'text': text,
      if (marks.isNotEmpty) 'marks': [for (final m in marks) {'type': m}],
    };

Map<String, dynamic> _p(List<Map<String, dynamic>> content) =>
    {'type': 'paragraph', 'content': content};

void main() {
  test('headings, paragraphs and marks', () {
    final md = proseMirrorToMarkdown({
      'type': 'doc',
      'content': [
        {
          'type': 'heading',
          'attrs': {'level': 2},
          'content': [_t('Plan')],
        },
        _p([
          _t('Ship '),
          _t('now', ['bold']),
          _t(', '),
          _t('carefully', ['italic']),
          _t(' with '),
          _t('flutter test', ['code']),
          _t(' and '),
          {
            'type': 'text',
            'text': 'the docs',
            'marks': [
              {
                'type': 'link',
                'attrs': {'href': 'https://example.com'},
              },
            ],
          },
        ]),
      ],
    });
    expect(
      md,
      '## Plan\n\nShip **now**, *carefully* with `flutter test` and '
      '[the docs](<https://example.com>)',
    );
  });

  test('lists, tasks, quotes, code and rules', () {
    final md = proseMirrorToMarkdown({
      'type': 'doc',
      'content': [
        {
          'type': 'bulletList',
          'content': [
            {'type': 'listItem', 'content': [_p([_t('one')])]},
            {'type': 'listItem', 'content': [_p([_t('two')])]},
          ],
        },
        {
          'type': 'orderedList',
          'attrs': {'start': 3},
          'content': [
            {'type': 'listItem', 'content': [_p([_t('three')])]},
          ],
        },
        {
          'type': 'taskList',
          'content': [
            {
              'type': 'taskItem',
              'attrs': {'checked': true},
              'content': [_p([_t('done')])],
            },
          ],
        },
        {'type': 'blockquote', 'content': [_p([_t('quoted')])]},
        {
          'type': 'codeBlock',
          'attrs': {'language': 'dart'},
          'content': [_t('void main() {}')],
        },
        {'type': 'horizontalRule'},
      ],
    });
    expect(md, contains('- one\n- two'));
    expect(md, contains('3. three'));
    expect(md, contains('- [x] done'));
    expect(md, contains('> quoted'));
    expect(md, contains('```dart\nvoid main() {}\n```'));
    expect(md, contains('---'));
  });

  test('a node the phone does not know keeps its words', () {
    final md = proseMirrorToMarkdown({
      'type': 'doc',
      'content': [
        _p([
          _t('Ask '),
          {
            'type': 'mention',
            'attrs': {'label': 'Mia'},
          },
        ]),
        {
          'type': 'callout',
          'content': [_p([_t('inside a callout')])],
        },
      ],
    });
    expect(md, contains('Ask Mia'));
    expect(md, contains('inside a callout'));
  });

  test('no document, no words', () {
    expect(proseMirrorToMarkdown(null), '');
    expect(proseMirrorToMarkdown({'type': 'doc'}), '');
  });

  test('markdown typed as text stays text: no picture, no link', () {
    final md = proseMirrorToMarkdown({
      'type': 'doc',
      'content': [
        _p([_t('![x](https://tracker.example/p.png) and [y](https://a.example)')]),
        _p([_t('# not a heading, > not a quote, *a*, _b_, ~~c~~, `d`, \\')]),
        _p([_t('[bold](https://a.example)', ['bold'])]),
      ],
    });
    expect(
      md,
      r'\!\[x\]\(https://tracker.example/p.png\) and '
      r'\[y\]\(https://a.example\)'
      '\n\n'
      r'\# not a heading, \> not a quote, \*a\*, \_b\_, \~\~c\~\~, \`d\`, \\'
      '\n\n'
      r'**\[bold\]\(https://a.example\)**',
    );
    // The renderer reads it back as the words typed.
    final html = markdownToHtml(md);
    expect(html, isNot(contains('<img')));
    expect(html, isNot(contains('<a ')));
    expect(html, contains('![x](https://tracker.example/p.png)'));
  });
  group('nothing typed can break out of its mark or block', () {
    Map<String, dynamic> link(String text, String href) => {
          'type': 'text',
          'text': text,
          'marks': [
            {
              'type': 'link',
              'attrs': {'href': href},
            },
          ],
        };

    test('inline code with a backtick, then a picture, stays code and words',
        () {
      final md = proseMirrorToMarkdown({
        'type': 'doc',
        'content': [
          _p([_t('`![x](https://host/p.png)', ['code'])]),
          _p([_t('`', ['code']), _t('![x](https://host/p.png)')]),
          _p([_t('a``b', ['code']), _t(' then '), _t('c', ['code'])]),
        ],
      });
      final html = markdownToHtml(md);
      expect(html, isNot(contains('<img')));
      expect(html, contains('<code>`![x](https://host/p.png)</code>'));
      expect(html, contains('<code>`</code>![x](https://host/p.png)'));
      expect(html, contains('<code>a``b</code> then <code>c</code>'));
    });

    test('a fence line inside a code block does not end it', () {
      final md = proseMirrorToMarkdown({
        'type': 'doc',
        'content': [
          {
            'type': 'codeBlock',
            'attrs': {'language': 'md'},
            'content': [
              _t('before\n```\n![x](https://host/p.png)\n````\nafter'),
            ],
          },
          _p([_t('next')]),
        ],
      });
      final html = markdownToHtml(md);
      expect(html, isNot(contains('<img')));
      expect(
        html,
        contains('```\n![x](https://host/p.png)\n````\nafter\n</code></pre>'),
      );
      expect(html, contains('<p>next</p>'));
    });

    test('a language cannot carry markdown into the fence', () {
      final md = proseMirrorToMarkdown({
        'type': 'doc',
        'content': [
          {
            'type': 'codeBlock',
            'attrs': {'language': 'js ```\n![x](https://host/p.png)'},
            'content': [_t('x')],
          },
        ],
      });
      expect(markdownToHtml(md), isNot(contains('<img')));
    });

    test('a ) or a space in an address stays part of it', () {
      final md = proseMirrorToMarkdown({
        'type': 'doc',
        'content': [
          _p([
            link('docs', 'https://a.example/x) ![y](https://host/p.png'),
            _t(' and '),
            link('more', 'https://a.example/<b> c\\'),
          ]),
        ],
      });
      final html = markdownToHtml(md);
      expect(html, isNot(contains('<img')));
      expect(
        html,
        contains('href="https://a.example/x)%20!%5By%5D(https://host/p.png"'),
      );
      expect(html, contains('href="https://a.example/%3Cb%3E%20c%5C"'));
      expect(html, contains('>docs</a>'));
    });

    test('only the web and mail are linked; anything else is its words', () {
      final md = proseMirrorToMarkdown({
        'type': 'doc',
        'content': [
          _p([
            link('one', 'javascript:alert(1)'),
            _t(' '),
            link('two', ' JavaScript:alert(1)'),
            _t(' '),
            link('three', 'file:///etc/hosts'),
            _t(' '),
            link('four', '/pages/x'),
            _t(' '),
            link('mail', 'mailto:mia@example.invalid'),
            _t(' '),
            link('web', 'HTTPS://a.example'),
          ]),
        ],
      });
      final html = markdownToHtml(md);
      expect(html, isNot(contains('javascript')));
      expect(html, isNot(contains('JavaScript')));
      expect(html, isNot(contains('file:')));
      expect(html, isNot(contains('/pages/x')));
      expect(html, contains('one two three four'));
      expect(html, contains('href="mailto:mia@example.invalid"'));
      expect(html, contains('href="HTTPS://a.example"'));
      expect('<a '.allMatches(html), hasLength(2));
    });

    test("a picture's description is words, never markdown", () {
      final md = proseMirrorToMarkdown({
        'type': 'doc',
        'content': [
          {
            'type': 'image',
            'attrs': {
              'src': 'https://a.example/p.png',
              'alt': 'x](https://host/q.png) ![y',
            },
          },
        ],
      });
      final html = markdownToHtml(md);
      expect('<img'.allMatches(html), hasLength(1));
      expect(html, contains('src="https://a.example/p.png"'));
      expect(html, isNot(contains('host/q.png"')));
    });
  });
}
