import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/collection_repository.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CollectionRepository repo;
  var clock = DateTime(2026, 10, 20, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime(2026, 10, 20, 12);
    repo = CollectionRepository(db, now: () => clock);
  });

  tearDown(() => db.close());

  Future<int> book(String title) => db
      .into(db.books)
      .insert(
        BooksCompanion.insert(
          title: title,
          authors: const [],
          sourceFormat: SourceFormat.txt,
          sourceName: '$title.txt',
          sourceSize: 1,
          sourceHash: 'hash-$title',
          parserVersion: 1,
          wordCount: 1,
          addedAt: clock,
          touchedAt: clock,
        ),
      );

  Future<List<String>> names() async => [
    for (final c in await repo.watchCollections().first) c.name,
  ];

  Future<Set<(int, int)>> links() async => {
    for (final l in await repo.watchLinks().first) (l.collectionId, l.bookId),
  };

  Matcher nameError(CollectionNameError error) => throwsA(
    isA<CollectionNameException>().having((e) => e.error, 'error', error),
  );

  test('creates collections with trimmed names, oldest first', () async {
    final first = await repo.create('  Классика ');
    await repo.create('Сказки');

    expect(first.name, 'Классика');
    expect(first.createdAt, clock);
    expect(await names(), ['Классика', 'Сказки']);
  });

  test('a name must not be empty or taken in any case', () async {
    await repo.create('Классика');

    await expectLater(repo.create('   '), nameError(CollectionNameError.empty));
    await expectLater(
      repo.create(' КЛАССИКА'),
      nameError(CollectionNameError.taken),
    );
    expect(await names(), ['Классика']);
  });

  test('renames; its own name in other case is fine', () async {
    final a = await repo.create('Классика');
    await repo.create('Сказки');

    await repo.rename(a.id, 'КЛАССИКА');
    expect(await names(), ['КЛАССИКА', 'Сказки']);

    await expectLater(
      repo.rename(a.id, 'сказки'),
      nameError(CollectionNameError.taken),
    );
    await expectLater(
      repo.rename(a.id, ''),
      nameError(CollectionNameError.empty),
    );
    expect(await names(), ['КЛАССИКА', 'Сказки']);
  });

  test('adds and removes books; adding twice keeps one link', () async {
    final c = await repo.create('Классика');
    final a = await book('А');
    final b = await book('Б');

    await repo.addBook(c.id, a);
    await repo.addBook(c.id, a);
    await repo.addBook(c.id, b);
    expect(await links(), {(c.id, a), (c.id, b)});

    await repo.removeBook(c.id, a);
    expect(await links(), {(c.id, b)});
  });

  test('setBooks leaves exactly the checked books', () async {
    final c = await repo.create('Классика');
    final other = await repo.create('Сказки');
    final a = await book('А');
    final b = await book('Б');
    final v = await book('В');
    await repo.addBook(c.id, a);
    await repo.addBook(other.id, a);

    clock = clock.add(const Duration(hours: 1));
    await repo.setBooks(c.id, {b, v});
    expect(await links(), {(c.id, b), (c.id, v), (other.id, a)});

    await repo.setBooks(c.id, {v});
    expect(await links(), {(c.id, v), (other.id, a)});
  });

  test('a book that stays keeps the time it was added', () async {
    final c = await repo.create('Классика');
    final a = await book('А');
    await repo.addBook(c.id, a);
    final added = clock;

    clock = clock.add(const Duration(days: 1));
    await repo.setBooks(c.id, {a});

    final link = (await repo.watchLinks().first).single;
    expect(link.addedAt, added);
  });

  test('deleting a collection keeps the books', () async {
    final c = await repo.create('Классика');
    final a = await book('А');
    await repo.addBook(c.id, a);

    await repo.delete(c.id);

    expect(await names(), isEmpty);
    expect(await links(), isEmpty);
    expect(await db.select(db.books).get(), hasLength(1));
  });

  test('deleting a book takes it out of its collections', () async {
    final c = await repo.create('Классика');
    final a = await book('А');
    final b = await book('Б');
    await repo.addBook(c.id, a);
    await repo.addBook(c.id, b);

    await (db.delete(db.books)..where((r) => r.id.equals(a))).go();

    expect(await links(), {(c.id, b)});
  });

  test('ids of deleted collections are not reused', () async {
    await repo.create('А');
    final b = await repo.create('Б');
    await repo.delete(b.id);

    final v = await repo.create('В');

    expect(v.id, b.id + 1);
  });
}
