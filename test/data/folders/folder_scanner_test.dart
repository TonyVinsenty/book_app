import 'dart:io';

import 'package:book_app/data/collection_repository.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_repository.dart';
import 'package:book_app/data/folders/folder_scan.dart';
import 'package:book_app/data/folders/folder_scanner.dart';
import 'package:book_app/data/import_queue.dart';
import 'package:book_app/data/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_importer.dart';

/// A folder in memory: key → size; copies go to [copies].
final class _FakeSource implements FolderSource {
  _FakeSource(this.copies);

  final Directory copies;
  final files = <String, int>{};

  /// Keys still in iCloud.
  final waiting = <String>{};

  /// Keys whose copy comes back as a path with nothing there.
  final uncopyable = <String>{};
  bool lost = false;
  Error? failure;

  @override
  Future<List<FolderEntry>> list() async {
    if (lost) throw const FolderLostException();
    if (failure case final failure?) throw failure;
    return [
      for (final MapEntry(:key, :value) in files.entries)
        FolderEntry(
          key: key,
          size: value,
          modified: 0,
          waiting: waiting.contains(key),
        ),
    ];
  }

  @override
  Future<String> copy(String key) async {
    if (uncopyable.contains(key)) return '${copies.path}/missing';
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

  test('added books and duplicates go to the folder collection', () async {
    final sf = await CollectionRepository(db).create('Фантастика');
    await folders.setCollection(folder.id, sf.id);
    folder = await row();
    final names = ['a.fb2', 'dup.fb2', 'box.zip-1', 'box.zip-2', 'box.zip-3'];
    for (final name in names) {
      await db.into(db.books).insert(bookRow(name));
    }
    source.files.addAll({'a.fb2': 1, 'dup.fb2': 1, 'box.zip': 1, 'bad.fb2': 1});
    await scan();
    final linked = await db.select(db.bookCollections).get();
    expect(linked.map((l) => l.collectionId).toSet(), {sf.id});
    expect(
      linked.map((l) => l.bookId).toSet(),
      names.map((n) => bookRow(n).id).toSet(),
    );
  });

  test('no collection, or deleted ones, and deleted books: no links', () async {
    // Not in the database: as if deleted while the scan went on.
    source.files['a.fb2'] = 1;
    final sf = await CollectionRepository(db).create('Фантастика');
    await folders.setCollection(folder.id, sf.id);
    folder = await row();
    await scan();
    expect(await db.select(db.bookCollections).get(), isEmpty);

    // Deleted after the folder row was read.
    await db.into(db.books).insert(bookRow('b.fb2'));
    await CollectionRepository(db).delete(sf.id);
    source.files['b.fb2'] = 1;
    await scan();
    expect(await db.select(db.bookCollections).get(), isEmpty);
    expect((await row()).collectionId, isNull);
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

  test(
    'a renamed file is a quiet duplicate; a gone one is forgotten',
    () async {
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
    },
  );

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

  test('a scan asked for while one is on runs right after it', () async {
    importer.hold = true;
    source.files['a.fb2'] = 1;
    final first = scanner.scanAll([(folder, source)]);
    await Future<void>.delayed(Duration.zero);
    final other = await folders.addPicked(ref: 'r2', name: 'Новая');
    final otherSource = _FakeSource(temp)..files['b.fb2'] = 1;
    expect(
      await scanner.scanAll([(folder, source), (other, otherSource)]),
      isFalse,
    );
    await importer.release();
    await importer.release();
    expect(await first, isTrue);
    expect(importer.calls, ['a.fb2', 'b.fb2']);
    expect((await folders.knownFiles(other.id)).keys, ['b.fb2']);
  });

  test('a file that could not be copied is tried again next time', () async {
    source.files['a.fb2'] = 1;
    source.uncopyable.add('a.fb2');
    await scan();
    expect(await folders.knownFiles(folder.id), isEmpty);
    source.uncopyable.clear();
    await scan();
    expect((await folders.knownFiles(folder.id)).keys, ['a.fb2']);
  });

  test('a file still in iCloud is kept in mind, not taken', () async {
    source.files['a.fb2'] = 1;
    await scan();
    source.waiting.add('a.fb2');
    source.files['b.fb2'] = 1;
    source.waiting.add('b.fb2');
    await scan();
    // a.fb2 isn't forgotten, so a deleted book doesn't come back.
    expect((await folders.knownFiles(folder.id)).keys, ['a.fb2']);
    expect(importer.calls, ['a.fb2']);
  });

  test('a folder that fails does not stop the others', () async {
    final errors = <FlutterErrorDetails>[];
    final report = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = report);
    final broken = await folders.addPicked(ref: 'r2', name: 'Битая');
    final brokenSource = _FakeSource(temp)..failure = StateError('odd');
    source.files['a.fb2'] = 1;
    expect(
      await scanner.scanAll([(broken, brokenSource), (folder, source)]),
      isTrue,
    );
    expect(importer.calls, ['a.fb2']);
    expect(errors.single.exception, isA<StateError>());
  });

  test('a folder disconnected midway: the scan ends quietly', () async {
    final errors = <FlutterErrorDetails>[];
    final report = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = report);
    importer.hold = true;
    source.files.addAll({'a.fb2': 1, 'b.fb2': 1});
    final scan = scanner.scanAll([(folder, source)]);
    await Future<void>.delayed(Duration.zero);
    await folders.remove(folder.id);
    await importer.release();
    await importer.release();
    expect(await scan, isTrue);
    expect(scanner.busy, isFalse);
    expect(await folders.folders(), isEmpty);
  });
}
