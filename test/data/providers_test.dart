import 'dart:io';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/db/open_app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('providers_'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('booksProvider lists books added through the repository', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        contentStoreProvider.overrideWithValue(
          ContentStore(Directory('${temp.path}/books')),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final sub = container.listen(booksProvider, (_, _) {});
    addTearDown(sub.close);

    expect(await container.read(booksProvider.future), isEmpty);

    final source = File('${temp.path}/a.txt')..writeAsStringSync('Слово.');
    await container
        .read(bookRepositoryProvider)
        .addBook(
          content: const BookContent(
            meta: BookMeta(title: 'Книга', sourceFormat: SourceFormat.txt),
            sections: [
              Section(blocks: [ParagraphBlock(text: 'Слово.')]),
            ],
          ),
          source: source,
          sourceName: 'a.txt',
          sourceHash: 'h',
          parserVersion: 1,
          wordCount: 1,
        );

    await pumpEventQueue();
    expect(container.read(booksProvider).value!.single.title, 'Книга');
  });

  test('the database file survives reopening', () async {
    final first = await openAppDatabaseIn(temp);
    await first
        .into(first.appSettings)
        .insert(AppSettingsCompanion.insert(key: 'k', value: 'v'));
    await first.close();

    final second = await openAppDatabaseIn(temp);
    addTearDown(second.close);
    final rows = await second.select(second.appSettings).get();
    expect(rows.single.value, 'v');
  });

  test('opening fails clearly when the directory is missing', () {
    expect(
      openAppDatabaseIn(Directory('${temp.path}/nope')),
      throwsA(isA<FileSystemException>()),
    );
  });
}
