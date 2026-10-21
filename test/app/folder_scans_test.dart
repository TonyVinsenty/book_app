import 'dart:io';

import 'package:book_app/app/folder_scans.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_repository.dart';
import 'package:book_app/data/folders/folder_scan.dart';
import 'package:book_app/data/folders/folder_scanner.dart';
import 'package:book_app/data/import_queue.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_importer.dart';

void main() {
  testWidgets('scans after the first frame and on every return', (
    tester,
  ) async {
    var scans = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanFoldersProvider.overrideWithValue(() async {
            scans++;
            return true;
          }),
        ],
        child: const FolderScans(child: SizedBox()),
      ),
    );
    await tester.pump();
    expect(scans, 1);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(scans, 2);
  });

  group('scanFoldersProvider', () {
    late Directory temp;
    late AppDatabase db;
    late FakeImporter importer;

    /// `<ref>/<key>` of each file copied from a picked folder.
    late List<String> copied;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('scans_');
      db = AppDatabase(NativeDatabase.memory());
      importer = FakeImporter();
      copied = [];
    });
    tearDown(() async {
      await db.close();
      temp.deleteSync(recursive: true);
    });

    ProviderContainer container({Directory? own, ListFolder? list}) {
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bookImporterProvider.overrideWithValue(importer),
          ownFolderProvider.overrideWithValue(own),
          folderCopiesProvider.overrideWithValue(
            Directory('${temp.path}/copies'),
          ),
          listFolderProvider.overrideWithValue(list),
          copyFolderFilesProvider.overrideWithValue((ref, keys) async {
            copied.addAll([for (final key in keys) '$ref/$key']);
            return [
              for (final key in keys)
                (File('${temp.path}/$key')..writeAsStringSync('x')).path,
            ];
          }),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('takes books from the own folder', () async {
      final own = Directory('${temp.path}/own')..createSync();
      File('${own.path}/Книга.fb2').writeAsStringSync('x');
      final c = container(own: own);

      expect(await c.read(scanFoldersProvider)(), isTrue);
      expect(importer.calls, ['Книга.fb2']);
      final folders = await db.select(db.folders).get();
      expect([for (final f in folders) f.kind], [FolderKind.own]);
      expect(File('${own.path}/Книга.fb2').existsSync(), isTrue);

      await c.read(scanFoldersProvider)();
      expect(importer.calls, hasLength(1));
    });

    test('no own folder: nothing made, nothing taken', () async {
      final c = container();
      expect(await c.read(scanFoldersProvider)(), isTrue);
      expect(await db.select(db.folders).get(), isEmpty);
    });

    test('takes books from picked folders by their own names', () async {
      final asked = <String>[];
      final c = container(
        list: (ref) async {
          asked.add(ref);
          return (
            files: [
              const FolderEntry(
                key: 'doc7',
                name: 'Книга.fb2',
                size: 1,
                modified: 0,
              ),
            ],
            ref: 'renewed',
          );
        },
      );
      final repo = c.read(folderRepositoryProvider);
      final picked = await repo.addPicked(ref: 'tree', name: 'Книги');
      final queueNames = <String>[];
      c.listen(importQueueProvider, (_, state) {
        if (state.current case final name?) queueNames.add(name);
      });

      expect(await c.read(scanFoldersProvider)(), isTrue);
      expect(asked, ['tree']);
      expect(importer.calls, ['doc7']);
      // The queue shows the file's name before the copy is made.
      expect(queueNames.first, 'Книга.fb2');
      // A renewed handle is kept; the copy used it.
      expect((await repo.folders()).single.ref, 'renewed');
      expect(copied, ['renewed/doc7']);
      expect((await repo.knownFiles(picked.id)).keys, ['doc7']);
    });

    test('a picked folder with no access is marked, then given back', () async {
      var lost = true;
      final c = container(
        list: (ref) async {
          if (lost) throw const FolderLostException();
          return (files: const <FolderEntry>[], ref: null);
        },
      );
      final repo = c.read(folderRepositoryProvider);
      await repo.addPicked(ref: 'tree', name: 'Книги');

      await c.read(scanFoldersProvider)();
      expect((await repo.folders()).single.lost, isTrue);
      lost = false;
      await c.read(scanFoldersProvider)();
      expect((await repo.folders()).single.lost, isFalse);
    });

    test('picked folders wait where the platform cannot list them', () async {
      final c = container();
      await c
          .read(folderRepositoryProvider)
          .addPicked(ref: 'tree', name: 'Книги');
      expect(await c.read(scanFoldersProvider)(), isTrue);
      expect(importer.calls, isEmpty);
      expect((await db.select(db.folders).get()).single.scannedAt, isNull);
    });
  });
}
