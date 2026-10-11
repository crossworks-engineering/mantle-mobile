// Who reads a folder or an item, on its tree row: the workspace chips (two,
// then "+N"), "Public" for a live link; an older brain's level badge only
// when no workspaces are sent. And the picture routes a chat reply names.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/tree/tree_models.dart';
import 'package:jackdaw/features/chat/markdown/ref_widgets.dart';
import 'package:jackdaw/features/tree/tree_rows.dart';

import '../helpers/pump_screen.dart';

Map<String, dynamic> _item({
  List<Map<String, String>> workspaces = const [],
  bool hasLink = false,
  String? level,
}) =>
    {
      'id': 'n1',
      'title': 'Quarterly plan',
      'icon': null,
      'color': null,
      'subtype': null,
      'state': null,
      'updatedAt': '2026-10-11T08:00:00.000Z',
      'workspaces': workspaces,
      'hasLink': hasLink,
      'level': ?level,
    };

void main() {
  test('the tree reads the workspaces and the link of folders and items', () {
    final item = TreeItem.fromJson(_item(
      workspaces: [
        {'id': 'w1', 'name': 'Team'},
        {'id': 'w2', 'name': 'Sales'},
      ],
      hasLink: true,
    ));
    expect(item.workspaces.map((w) => w.name), ['Team', 'Sales']);
    expect(item.hasLink, isTrue);

    final folder = TreeFolder.fromJson({
      'id': 'f1',
      'path': 'pages.f1',
      'name': 'Plans',
      'depth': 1,
      'system': false,
      'folderCount': 0,
      'itemCount': 2,
      'workspaces': [
        {'id': 'w1', 'name': 'Team'},
        {'name': 'no id, dropped'},
      ],
    });
    expect(folder.workspaces.single.id, 'w1');
    expect(folder.hasLink, isFalse);

    // An older brain sends neither.
    final old = TreeItem.fromJson({'id': 'n2', 'title': 'Old'});
    expect(old.workspaces, isEmpty);
    expect(old.hasLink, isFalse);
  });

  Future<void> pumpRow(WidgetTester tester, Map<String, dynamic> json) =>
      pumpScreen(
        tester,
        Column(children: [
          TreeItemTile(
            kind: TreeKind.pages,
            item: TreeItem.fromJson(json),
            onTap: () {},
          ),
        ]),
        container: ProviderContainer(),
      );

  testWidgets('two chips, then a count, then Public', (tester) async {
    await pumpRow(
      tester,
      _item(
        workspaces: [
          {'id': 'w1', 'name': 'Team'},
          {'id': 'w2', 'name': 'Sales'},
          {'id': 'w3', 'name': 'Support'},
        ],
        hasLink: true,
      ),
    );
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Support'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Open Quarterly plan, read by Team, Sales, Support, public link',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an older brain\'s level badge shows only without workspaces',
      (tester) async {
    await pumpRow(tester, _item(level: 'team'));
    expect(find.byType(TreeBadge), findsOneWidget);
  });

  testWidgets('chips take the place of the level badge', (tester) async {
    await pumpRow(
      tester,
      _item(workspaces: [
        {'id': 'w1', 'name': 'Team'},
      ], level: 'team'),
    );
    expect(find.byType(TreeBadge), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);
  });

  group('picture routes in a chat reply', () {
    test('files: media:, the owner route and the member route all load from '
        'the owner route', () {
      expect(imageFileId(Uri.parse('media:f1')), 'f1');
      expect(imageFileId(Uri.parse('/api/files/files/f2?raw=1')), 'f2');
      expect(imageFileId(Uri.parse('/api/member/files/f3')), 'f3');
      expect(
          imageFileId(Uri.parse('https://brain.test/api/member/files/f4')),
          'f4');
      expect(imageFileId(Uri.parse('/api/draws/d1/svg')), isNull);
      expect(imageFileId(Uri.parse('https://example.com/cat.png')), isNull);
      expect(imageFileId(Uri.parse('draw:d1')), isNull);
    });

    test('drawings: draw:, the owner SVG route and the member one', () {
      expect(imageDrawId(Uri.parse('draw:d1')), 'd1');
      expect(imageDrawId(Uri.parse('/api/draws/d2/svg')), 'd2');
      expect(imageDrawId(Uri.parse('/api/draws/d3/svg?raw=1')), 'd3');
      expect(imageDrawId(Uri.parse('/api/member/draws/d4/svg')), 'd4');
      expect(imageDrawId(Uri.parse('/api/member/files/f1')), isNull);
      expect(imageDrawId(Uri.parse('media:f1')), isNull);
    });
  });
}
