import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;
import 'generated_migrations/schema_v4.dart' as v4;
import 'generated_migrations/schema_v5.dart' as v5;

// Snapshots of every schema are in `drift_schemas/`; after a table change:
//   dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/
//   dart run drift_dev schema generate --data-classes --companions
//     drift_schemas/ test/data/generated_migrations/
// Seconds since 1970, as drift stores dates.
const _added = 1760000000;
const _opened = 1760000500;

v1.BooksCompanion _book(String title, {int? openedAt, int position = 42}) =>
    v1.BooksCompanion.insert(
      title: title,
      authors: '["Автор"]',
      sourceFormat: 'fb2',
      sourceName: '$title.fb2',
      sourceSize: 10,
      sourceHash: 'hash-$title',
      parserVersion: 1,
      wordCount: 100,
      positionWord: Value(position),
      addedAt: _added,
      openedAt: Value(openedAt),
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  for (final from in [1, 2, 3, 4]) {
    test('v$from → v5 gives the v5 schema', () async {
      final db = AppDatabase(await verifier.startAt(from));
      await verifier.migrateAndValidate(db, 5);
      await db.close();
    });
  }

  test('v1 → v5 does not give out ids of deleted books again', () async {
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    for (final title in ['А', 'Б', 'В']) {
      await old.into(old.books).insert(_book(title));
    }
    await (old.delete(old.books)..where((b) => b.id.isBiggerThanValue(1))).go();
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 5);
    final id = await db
        .into(db.books)
        .insert(
          BooksCompanion.insert(
            title: 'Новая',
            authors: const [],
            sourceFormat: SourceFormat.txt,
            sourceName: 'n.txt',
            sourceSize: 1,
            sourceHash: 'new',
            parserVersion: 1,
            wordCount: 1,
            addedAt: DateTime(2026),
            touchedAt: DateTime(2026),
          ),
        );
    await db.close();

    expect(id, 4);
  });

  test('v1 → v5 keeps the books; touched = opened, else added', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 5,
      createOld: v1.DatabaseAtV1.new,
      createNew: v5.DatabaseAtV5.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, old) => batch.insertAll(old.books, [
        _book('Открытая', openedAt: _opened),
        _book('Новая'),
      ]),
      validateItems: (db) async {
        final rows = await db.select(db.books).get();
        expect([for (final r in rows) r.title], ['Открытая', 'Новая']);
        expect([for (final r in rows) r.touchedAt], [_opened, _added]);
        for (final r in rows) {
          expect(r.coverFile, isNull);
          expect(r.finishedAt, isNull);
          expect(r.statusMark, isNull);
          expect(r.authors, '["Автор"]');
          expect(r.positionWord, 42);
        }
      },
    );
  });

  test('v2 → v5 keeps the books; read to 98% counts as read', () async {
    v2.BooksCompanion book(String title, int position, int words) =>
        v2.BooksCompanion.insert(
          title: title,
          authors: '["Автор"]',
          sourceFormat: 'epub',
          sourceName: '$title.epub',
          sourceSize: 10,
          sourceHash: 'hash-$title',
          parserVersion: 1,
          wordCount: words,
          positionWord: Value(position),
          addedAt: _added,
          openedAt: const Value(_opened),
          touchedAt: _opened,
          coverFile: const Value('cover.jpg'),
        );
    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 5,
      createOld: v2.DatabaseAtV2.new,
      createNew: v5.DatabaseAtV5.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, old) => batch.insertAll(old.books, [
        book('Почти', 97, 100),
        book('Дочитана', 98, 100),
        book('Пустая', 0, 0),
      ]),
      validateItems: (db) async {
        final rows = await db.select(db.books).get();
        expect(
          [for (final r in rows) r.title],
          ['Почти', 'Дочитана', 'Пустая'],
        );
        expect([for (final r in rows) r.finishedAt], [null, _opened, null]);
        expect([for (final r in rows) r.coverFile], everyElement('cover.jpg'));
        expect([for (final r in rows) r.statusMark], everyElement(isNull));
        expect(await db.select(db.collections).get(), isEmpty);
      },
    );
  });

  test('v3 → v5 keeps books, read marks and collections', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 5,
      createOld: v3.DatabaseAtV3.new,
      createNew: v5.DatabaseAtV5.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, old) {
        v3.BooksCompanion book(int id, String title, {int? finishedAt}) =>
            v3.BooksCompanion.insert(
              id: Value(id),
              title: title,
              authors: '["Автор"]',
              sourceFormat: 'epub',
              sourceName: '$title.epub',
              sourceSize: 10,
              sourceHash: 'hash-$title',
              parserVersion: 1,
              wordCount: 100,
              positionWord: const Value(42),
              addedAt: _added,
              openedAt: const Value(_opened),
              touchedAt: _opened,
              finishedAt: Value(finishedAt),
            );
        batch
          ..insertAll(old.books, [
            book(3, 'Читаю'),
            book(7, 'Прочитана', finishedAt: _opened),
          ])
          ..insert(
            old.collections,
            v3.CollectionsCompanion.insert(
              name: 'Фантастика',
              createdAt: _added,
            ),
          )
          ..insert(
            old.bookCollections,
            v3.BookCollectionsCompanion.insert(
              bookId: 7,
              collectionId: 1,
              addedAt: _added,
            ),
          );
      },
      validateItems: (db) async {
        final rows = await db.select(db.books).get();
        expect([for (final r in rows) r.id], [3, 7]);
        expect([for (final r in rows) r.finishedAt], [null, _opened]);
        expect([for (final r in rows) r.positionWord], [42, 42]);
        expect([for (final r in rows) r.statusMark], [null, null]);
        final links = await db.select(db.bookCollections).get();
        expect([for (final l in links) l.bookId], [7]);
      },
    );
  });

  test('v4 → v5 keeps books and status marks; no folders yet', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 4,
      newVersion: 5,
      createOld: v4.DatabaseAtV4.new,
      createNew: v5.DatabaseAtV5.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, old) {
        batch.insert(
          old.books,
          v4.BooksCompanion.insert(
            id: const Value(5),
            title: 'Отложена',
            authors: '["Автор"]',
            sourceFormat: 'txt',
            sourceName: 'Отложена.txt',
            sourceSize: 10,
            sourceHash: 'hash-5',
            parserVersion: 1,
            wordCount: 100,
            addedAt: _added,
            touchedAt: _opened,
            statusMark: const Value('queued'),
          ),
        );
      },
      validateItems: (db) async {
        final rows = await db.select(db.books).get();
        expect([for (final r in rows) r.statusMark], ['queued']);
        expect(await db.select(db.folders).get(), isEmpty);
        expect(await db.select(db.folderFiles).get(), isEmpty);
      },
    );
  });
}
