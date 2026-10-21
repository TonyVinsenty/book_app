import 'dart:io';

import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_repository.dart';
import 'package:book_app/data/folders/folder_scan.dart';
import 'package:flutter_test/flutter_test.dart';

FolderEntry _e(String key, {int size = 10, int modified = 1000}) =>
    FolderEntry(key: key, size: size, modified: modified);

Map<String, FolderFileRow> _known(List<FolderEntry> entries) => {
  for (final e in entries)
    e.key: FolderFileRow(
      folderId: 1,
      key: e.key,
      size: e.size,
      modified: e.modified,
      seenAt: DateTime(2026),
    ),
};

List<String> _keys(List<FolderEntry> entries) => [
  for (final e in entries) e.key,
];

void main() {
  group('planScan', () {
    final cases =
        <(String, List<FolderEntry>, List<FolderEntry>, List<String>)>[
          ('nothing known: all new', [_e('b'), _e('a')], [], ['a', 'b']),
          ('the same files: nothing', [_e('a')], [_e('a')], []),
          ('size changed', [_e('a', size: 11)], [_e('a')], ['a']),
          ('time changed', [_e('a', modified: 2)], [_e('a')], ['a']),
          (
            'time unknown now: size only',
            [_e('a', modified: 0)],
            [_e('a')],
            [],
          ),
          (
            'time unknown before: size only',
            [_e('a', modified: 5)],
            [_e('a', modified: 0)],
            [],
          ),
          ('renamed: the new name is new', [_e('b')], [_e('a')], ['b']),
        ];
    for (final (name, entries, known, toImport) in cases) {
      test(name, () {
        expect(_keys(planScan(entries, _known(known)).toImport), toImport);
      });
    }

    test('gone files are forgotten', () {
      final plan = planScan([_e('a')], _known([_e('a'), _e('b'), _e('c')]));
      expect(plan.forgotten, ['b', 'c']);
    });

    test('too large files are remembered, not taken', () {
      final plan = planScan(
        [_e('big', size: 101), _e('small', size: 100)],
        const {},
        maxSize: 100,
      );
      expect(_keys(plan.toImport), ['small']);
      expect(_keys(plan.tooLarge), ['big']);
    });

    test('over the limit: the first files by name, the rest wait', () {
      final plan = planScan(
        [_e('d'), _e('c'), _e('b'), _e('a')],
        _known([_e('d')]),
        maxFiles: 2,
      );
      expect(_keys(plan.toImport), ['a', 'b']);
      expect(plan.tooBig, isTrue);
      // A file past the limit is not gone.
      expect(plan.forgotten, isEmpty);
      expect(planScan([_e('a')], const {}, maxFiles: 1).tooBig, isFalse);
    });

    test('1000 known files compare in under 100 ms', () {
      final entries = [for (var i = 0; i < 1000; i++) _e('dir/book $i.fb2')];
      final known = _known(entries);
      final watch = Stopwatch()..start();
      final plan = planScan(entries, known);
      watch.stop();
      expect(plan.toImport, isEmpty);
      expect(watch.elapsedMilliseconds, lessThan(100));
    });
  });

  test('isBookFileName', () {
    for (final name in ['a.fb2', 'A.EPUB', 'b.txt', 'c.fb2.zip', 'd.zip']) {
      expect(isBookFileName(name), isTrue, reason: name);
    }
    for (final name in ['a.pdf', 'fb2', '.txt', 'cover.jpg']) {
      expect(isBookFileName(name), isFalse, reason: name);
    }
  });

  group('LocalFolderSource', () {
    late Directory temp;
    late Directory root;
    late LocalFolderSource source;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('folder_');
      root = Directory('${temp.path}/root')..createSync();
      source = LocalFolderSource(root, copies: Directory('${temp.path}/c'));
    });
    tearDown(() => temp.deleteSync(recursive: true));

    void put(String key, [String text = 'книга']) => File('${root.path}/$key')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    test('lists books in subfolders, skips the rest', () async {
      put('Книга.fb2');
      put('Серия/Том 1.epub');
      put('notes.pdf');
      put('.hidden.txt');
      put('.Trash/old.fb2');
      put('Inbox/open-in.fb2');
      put('Серия/Inbox/kept.txt');
      final keys = [for (final e in await source.list()) e.key]..sort();
      expect(keys, ['Книга.fb2', 'Серия/Inbox/kept.txt', 'Серия/Том 1.epub']);
      final entry = (await source.list()).firstWhere(
        (e) => e.key == 'Книга.fb2',
      );
      expect(entry.size, 'книга'.length * 2);
      expect(entry.modified, greaterThan(0));
    });

    test('goes 8 levels deep', () async {
      put('${List.filled(8, 'd').join('/')}/in.txt');
      put('${List.filled(9, 'd').join('/')}/out.txt');
      expect(
        [for (final e in await source.list()) e.key.split('/').last],
        ['in.txt'],
      );
    });

    test('a missing folder is empty', () async {
      root.deleteSync(recursive: true);
      expect(await source.list(), isEmpty);
    });

    test('copies keep the file name', () async {
      put('Серия/Том 1.epub', 'текст');
      final path = await source.copy('Серия/Том 1.epub');
      expect(path, endsWith('Том 1.epub'));
      expect(File(path).readAsStringSync(), 'текст');
      expect(File('${root.path}/Серия/Том 1.epub').existsSync(), isTrue);
    });
  });
}
