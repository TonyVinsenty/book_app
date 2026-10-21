import 'dart:io';

import 'package:book_app/app/folder_scans.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_scanner.dart';
import 'package:book_app/data/providers.dart';
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

    setUp(() {
      temp = Directory.systemTemp.createTempSync('scans_');
      db = AppDatabase(NativeDatabase.memory());
      importer = FakeImporter();
    });
    tearDown(() async {
      await db.close();
      temp.deleteSync(recursive: true);
    });

    ProviderContainer container({Directory? own}) {
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bookImporterProvider.overrideWithValue(importer),
          ownFolderProvider.overrideWithValue(own),
          folderCopiesProvider.overrideWithValue(
            Directory('${temp.path}/copies'),
          ),
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
  });
}
