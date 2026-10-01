// The tree's wire shapes against REAL responses (test/fixtures/tree/, taken
// from a brain at v0.232.369). If mantle's tree.ts changes shape, the fixture
// is re-taken and this is where it shows.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/pages/pages_models.dart';
import 'package:jackdaw/data/tree/tree_models.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/tree/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('the root: folders with icon, colour and share, then items', () {
    final page = TreeFolderPage.fromJson(fixture('tree_pages_root'));

    expect(page.kind, TreeKind.pages);
    expect(page.folder, isNull);
    expect(page.crumbs, isEmpty);
    expect(page.sort, TreeSort.updated);
    expect(page.nextCursor, isNull);
    expect(page.folders.map((f) => f.name), ['Archive', 'Clients', 'Engineering']);

    final archive = page.folders[0];
    expect(archive.icon, isNull);
    expect(archive.color, isNull);
    expect(archive.itemCount, 60);
    expect(archive.sharedWith, isNull);

    final clients = page.folders[1];
    expect(clients.icon, 'lucide:briefcase');
    expect(clients.color, 'blue');
    expect(clients.share, 'client');
    expect(clients.path, 'pages.clients');
    expect(clients.folderCount, 1);
    expect(clients.depth, 1);

    final engineering = page.folders[2];
    expect(engineering.icon, '🚀');
    expect(engineering.color, 'violet');
    expect(engineering.sharedWith, 'team');

    expect(page.items.map((i) => i.title),
        ['Quarterly goals', 'Welcome to the brain']);
    expect(page.items[1].icon, '👋');
    expect(page.items[0].level, 'admin');
    expect(page.items[0].state, isNull);
    expect(page.items[0].updatedAt, DateTime.utc(2026, 10, 1, 8, 38, 7, 745));
  });

  test('a folder three levels down carries its crumbs, top-down', () {
    final page = TreeFolderPage.fromJson(fixture('tree_pages_folder_depth3'));

    expect(page.folder!.name, 'Contracts');
    expect(page.folder!.depth, 3);
    expect(page.crumbs.map((c) => c.name), ['Clients', 'Acme Corp']);
    // It takes the share of the folder above it.
    expect(page.folder!.share, isNull);
    expect(page.folder!.sharedWith, 'client');
  });

  test('paging: 50 items and a cursor, then the rest with no folders', () {
    final first = TreeFolderPage.fromJson(fixture('tree_pages_archive_p1'));
    final second = TreeFolderPage.fromJson(fixture('tree_pages_archive_p2'));

    expect(first.items, hasLength(50));
    expect(first.nextCursor, isNotNull);
    expect(second.items, hasLength(10));
    expect(second.nextCursor, isNull);
    // A cursor page never repeats the subfolders.
    expect(second.folders, isEmpty);
    final ids = {...first.items.map((i) => i.id), ...second.items.map((i) => i.id)};
    expect(ids, hasLength(60));
  });

  test('a search hit says where it lives', () {
    final found = TreeSearchResult.fromJson(fixture('tree_pages_search'));

    expect(found.folders.single.name, 'Engineering');
    expect(found.folders.single.crumbs, isEmpty);
    expect(found.items, hasLength(2));
    expect(found.items.first.crumbs.single.name, 'Engineering');
    expect(found.items.first.level, 'team');
    expect(found.items.first.inherited, 'team');
  });

  test('Recent lists items with their crumbs', () {
    final recent = TreeMarkList.fromJson(fixture('tree_pages_marks_recent'));

    expect(recent.items.first.title, 'Acme folder index');
    expect(recent.items.first.crumbs.map((c) => c.name), ['Clients', 'Acme Corp']);
  });

  test('files carry their extension in the status slot', () {
    final page = TreeFolderPage.fromJson(fixture('tree_files_folder'));

    expect(page.folder!.path, startsWith('files.'));
    expect(page.items.map((i) => i.subtype), containsAll(['png', 'svg']));
  });

  test('notes: the root, a shared folder, and the tags', () {
    final root = TreeFolderPage.fromJson(fixture('tree_notes_root'));
    final shared =
        TreeFolderPage.fromJson(fixture('tree_notes_folder_shared_team'));
    final tags = TreeTag.listFrom(fixture('tree_notes_tags'));

    expect(root.kind, TreeKind.notes);
    expect(root.folders.map((f) => f.name), containsAll(['Meetings', 'Ideas']));
    expect(shared.folder!.share, 'team');
    expect(shared.items.every((i) => i.level == 'team'), isTrue);
    expect(tags.first.tag, 'meeting');
    expect(tags.first.count, 5);
  });

  test('a visibility refusal: what changes, and what a confirm must name', () {
    final refusal =
        TreeVisibilityRefusal.tryParse(fixture('tree_move_visibility_409'))!;

    expect(refusal.total, 1);
    expect(refusal.seen, 1);
    expect(refusal.to, 'team');
    expect(refusal.changes.single.title, 'Loose thought');
    expect(refusal.changes.single.from, 'admin');

    // An upload's refusal names a file that has no id yet.
    final upload =
        TreeVisibilityRefusal.tryParse(fixture('files_upload_409_visibility'))!;
    expect(upload.changes.single.id, '');
    expect(upload.to, 'team');

    // Any other 404/409 body is not one.
    expect(TreeVisibilityRefusal.tryParse(fixture('tree_folder_404')), isNull);
    expect(TreeVisibilityRefusal.tryParse('nope'), isNull);
  });

  test('a client tree row parses without the staff fields', () {
    // ClientTreeFolder / ClientTreeItem: no level, share, system or state.
    final page = TreeFolderPage.fromJson({
      'kind': 'pages',
      'folder': null,
      'crumbs': <Object>[],
      'folders': [
        {
          'id': 'f1',
          'path': 'pages.shared',
          'name': 'Shared',
          'icon': null,
          'color': 'teal',
          'depth': 1,
          'parentId': null,
          'folderCount': 0,
          'itemCount': 2,
        },
      ],
      'items': [
        {
          'id': 'i1',
          'title': 'Welcome',
          'icon': null,
          'color': null,
          'subtype': null,
          'updatedAt': '2026-10-01T08:00:00.000Z',
        },
      ],
      'sort': 'name',
      'nextCursor': null,
    });

    expect(page.folders.single.sharedWith, isNull);
    expect(page.folders.single.system, isFalse);
    expect(page.items.single.level, isNull);
    expect(page.items.single.state, isNull);
  });

  test('an unknown tint or kind is dropped, not thrown', () {
    final folder = TreeFolder.fromJson({'id': 'f', 'name': 'X', 'color': 'mauve'});
    expect(folder.color, isNull);
    expect(TreeKind.tryParse('holograms'), isNull);
    expect(TreeSort.tryParse('vibes'), isNull);
  });

  test('the page detail says which folder the page sits in', () {
    final detail = fixture('page_detail')['page'] as Map<String, dynamic>;
    final row = PageRow.fromJson(detail);

    expect(row.folderKnown, isTrue);
    expect(row.folderId, '26190ec8-d7cf-4959-911d-133cc1b2abab');

    // A brain older than pages in folders sends no folderId: not known,
    // which is not the same as the top level.
    final old = PageRow.fromJson(Map.of(detail)..remove('folderId'));
    expect(old.folderKnown, isFalse);
    final top = PageRow.fromJson({...detail, 'folderId': null});
    expect(top.folderKnown, isTrue);
    expect(top.folderId, isNull);
  });
}
