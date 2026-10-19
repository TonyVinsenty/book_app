import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;

// Snapshots of every schema are in `drift_schemas/`; after a table change:
//   dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/
//   dart run drift_dev schema generate --data-classes --companions
//     drift_schemas/ test/data/generated_migrations/
// Seconds since 1970, as drift stores dates.
const _added = 1760000000;
const _opened = 1760000500;

v1.BooksCompanion _book(String title, {int? openedAt}) =>
    v1.BooksCompanion.insert(
      title: title,
      authors: '["Автор"]',
      sourceFormat: 'fb2',
      sourceName: '$title.fb2',
      sourceSize: 10,
      sourceHash: 'hash-$title',
      parserVersion: 1,
      wordCount: 100,
      positionWord: const Value(42),
      addedAt: _added,
      openedAt: Value(openedAt),
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 → v2 gives the v2 schema', () async {
    final db = AppDatabase(await verifier.startAt(1));
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('v1 → v2 does not give out ids of deleted books again', () async {
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    for (final title in ['А', 'Б', 'В']) {
      await old.into(old.books).insert(_book(title));
    }
    await (old.delete(old.books)..where((b) => b.id.isBiggerThanValue(1))).go();
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
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

  test('v1 → v2 keeps the books; touched = opened, else added', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
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
          expect(r.authors, '["Автор"]');
          expect(r.positionWord, 42);
        }
      },
    );
  });
}
