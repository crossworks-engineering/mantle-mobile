// A page's ProseMirror document as markdown (what a member reads, the
// markdown export being an Admin user's route).

import 'package:flutter_test/flutter_test.dart';
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
      '[the docs](https://example.com)',
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
}
