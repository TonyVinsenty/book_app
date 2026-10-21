import 'dart:io';

import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_repository.dart';
import 'package:book_app/data/folders/folder_scan.dart';
import 'package:book_app/data/folders/folder_scanner.dart';
import 'package:book_app/data/import_queue.dart';
import 'package:book_app/data/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_importer.dart';

/// A folder in memory: key → size; copies go to [copies].
final class _FakeSource implements FolderSource {
  _FakeSource(this.copies);

  final Directory copies;
  final files = <String, int>{};
  bool lost = false;

  @override
  Future<List<FolderEntry>> list() async {
    if (lost) throw const FolderLostException();
    return [
      for (final MapEntry(:key, :value) in files.entries)
        FolderEntry(key: key, size: value, modified: 0),
    ];
  }

  @override
  Future<String> copy(String key) async {
    final file = File('${copies.path}/${key.split('/').last}')
      ..writeAsStringSync('x');
    return file.path;
  }
}

void main() {
  late Directory temp;
  late AppDatabase db;
  late FolderRepository folders;
  late FakeImporter importer;
  late ProviderContainer container;
  late FolderScanner scanner;
  late _FakeSource source;
  late FolderRow folder;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('scanner_');
    db = AppDatabase(NativeDatabase.memory());
    folders = FolderRepository(db);
    importer = FakeImporter();
    container = ProviderContainer(
      overrides: [bookImporterProvider.overrideWithValue(importer)],
    );
    scanner = FolderScanner(
      folders,
      container.read(importQueueProvider.notifier),
    );
    source = _FakeSource(temp);
    folder = await folders.addPicked(ref: 'r', name: 'Книги');
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    temp.deleteSync(recursive: true);
  });

  Future<void> scan() => scanner.scanAll([(folder, source)]);
  Future<FolderRow> row() async => (await folders.folders()).single;

  test('new books come in quietly and are remembered', () async {
    source.files.addAll({'a.fb2': 1, 'sub/dup.epub': 2, 'box.zip': 3});
    await scan();
    expect(importer.calls, ['a.fb2', 'box.zip', 'dup.epub']);
    expect(importer.touches, [false, false, false]);
    expect((await folders.knownFiles(folder.id)).keys.toSet(), {
      'a.fb2',
      'sub/dup.epub',
      'box.zip',
    });
    expect((await row()).scannedAt, isNotNull);
    // The queue deleted every copy.
    expect(temp.listSync(), isEmpty);
  });

  test('a rescan takes only new and changed files', () async {
    source.files.addAll({'a.fb2': 1, 'bad.fb2': 2});
    await scan();
    importer.calls.clear();

    // A deleted book doesn't come back; a broken file is told once.
    await scan();
    expect(importer.calls, isEmpty);

    source.files['a.fb2'] = 5;
    source.files['b.txt'] = 1;
    await scan();
    expect(importer.calls, ['a.fb2', 'b.txt']);
  });

  test('a renamed file is a quiet duplicate; a gone one is forgotten', () async {
    source.files['dup.fb2'] = 1;
    await scan();
    source.files
      ..remove('dup.fb2')
      ..['dup renamed.fb2'] = 1;
    importer.calls.clear();
    await scan();
    expect(importer.calls, ['dup renamed.fb2']);
    expect(importer.touches.last, isFalse);
    expect((await folders.knownFiles(folder.id)).keys, ['dup renamed.fb2']);
  });

  test('each file is remembered as soon as it is done', () async {
    importer.hold = true;
    source.files.addAll({'a.fb2': 1, 'b.fb2': 1});
    final scanning = scan();
    await importer.release();
    while ((await folders.knownFiles(folder.id)).isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    // An app closed now would take only b.fb2 next time.
    expect((await folders.knownFiles(folder.id)).keys, ['a.fb2']);
    await importer.release();
    await scanning;
    expect((await folders.knownFiles(folder.id)).length, 2);
  });

  test('no access: marked lost, nothing forgotten', () async {
    source.files['a.fb2'] = 1;
    await scan();
    source.lost = true;
    await scan();
    expect((await row()).lost, isTrue);
    expect((await folders.knownFiles(folder.id)).keys, ['a.fb2']);

    source.lost = false;
    await scan();
    expect((await row()).lost, isFalse);
  });

  test('one scan at a time', () async {
    importer.hold = true;
    source.files['a.fb2'] = 1;
    final first = scanner.scanAll([(folder, source)]);
    await Future<void>.delayed(Duration.zero);
    expect(scanner.busy, isTrue);
    expect(await scanner.scanAll([(folder, source)]), isFalse);
    await importer.release();
    expect(await first, isTrue);
    expect(scanner.busy, isFalse);
    expect(importer.calls, ['a.fb2']);
  });
}
