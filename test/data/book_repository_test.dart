import 'dart:io';
import 'dart:typed_data';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/book_cover.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

BookContent bookTitled(String title) => BookContent(
  meta: BookMeta(
    title: title,
    authors: const ['Первый', 'Второй'],
    series: 'Серия',
    seriesNumber: 2,
    lang: 'ru',
    sourceFormat: SourceFormat.txt,
  ),
  sections: const [
    Section(
      blocks: [
        ParagraphBlock(text: 'Раз два три.'),
        ParagraphBlock(text: 'Четыре пять.'),
      ],
    ),
  ],
);

void main() {
  late Directory temp;
  late AppDatabase db;
  late ContentStore store;
  late BookRepository repo;
  var clock = DateTime(2026, 10, 19, 12);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('book_repo_');
    db = AppDatabase(NativeDatabase.memory());
    store = ContentStore(Directory('${temp.path}/books'));
    clock = DateTime(2026, 10, 19, 12);
    repo = BookRepository(db, store, now: () => clock);
  });

  tearDown(() async {
    await db.close();
    temp.deleteSync(recursive: true);
  });

  Future<BookRow> add(String title, {String? hash, BookCover? cover}) {
    final content = bookTitled(title);
    final source = File('${temp.path}/$title.txt')
      ..writeAsStringSync('Раз два три.\n\nЧетыре пять.');
    return repo.addBook(
      content: content,
      source: source,
      sourceName: '$title.txt',
      sourceHash: hash ?? 'hash-$title',
      parserVersion: 1,
      wordCount: tokenize(content).length,
      cover: cover,
    );
  }

  final png = BookCover(Uint8List.fromList(List.filled(16, 7)), 'png');
  final jpg = BookCover(Uint8List.fromList(List.filled(16, 9)), 'jpg');

  test('adds a book: row with metadata, source and model on disk', () async {
    final row = await add('Книга');

    expect(row.title, 'Книга');
    expect(row.authors, ['Первый', 'Второй']);
    expect(row.series, 'Серия');
    expect(row.seriesNumber, 2);
    expect(row.sourceFormat, SourceFormat.txt);
    expect(row.sourceSize, File('${temp.path}/Книга.txt').lengthSync());
    expect(row.wordCount, 5);
    expect(row.addedAt, clock);
    expect(row.touchedAt, clock);
    expect(row.openedAt, isNull);
    expect(row.coverFile, isNull);
    expect(repo.coverFile(row), isNull);
    expect(row.position, ReadingPosition.start);
    expect(row.progress, 0);

    expect(repo.sourceFile(row).existsSync(), isTrue);
    final content = await repo.loadContent(row);
    expect(content!.toJson(), bookTitled('Книга').toJson());
  });

  test('finds books by id and source hash', () async {
    final row = await add('Книга', hash: 'abc');

    expect((await repo.findById(row.id))!.title, 'Книга');
    expect((await repo.findByHash('abc'))!.id, row.id);
    expect(await repo.findByHash('other'), isNull);
    expect(await repo.findById(row.id + 1), isNull);
  });

  test('the same source hash cannot be added twice', () async {
    await add('Книга', hash: 'abc');

    await expectLater(add('Копия', hash: 'abc'), throwsA(anything));
    expect(await repo.watchBooks().first, hasLength(1));
  });

  test('a failed file write removes the new row', () async {
    // A directory in place of the source copy makes the file write fail.
    final content = bookTitled('Книга');
    final source = File('${temp.path}/ok.txt')..writeAsStringSync('x');
    Directory('${store.bookDir(1).path}/source.txt')
        .createSync(recursive: true);

    await expectLater(
      repo.addBook(
        content: content,
        source: source,
        sourceName: 'ok.txt',
        sourceHash: 'h',
        parserVersion: 1,
        wordCount: 5,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await repo.watchBooks().first, isEmpty);
    expect(store.bookDir(1).existsSync(), isFalse);
  });

  test('saves the position; progress follows it', () async {
    final row = await add('Книга');
    const position = ReadingPosition(
      wordIndex: 3,
      anchor: TextAnchor(sectionIndex: 0, blockIndex: 1, charOffset: 0),
    );

    await repo.savePosition(row.id, position);

    final saved = (await repo.findById(row.id))!;
    expect(saved.position, position);
    expect(saved.progress, closeTo(0.6, 1e-9));
  });

  test('lists the last added, opened or imported again first', () async {
    final a = await add('А');
    clock = clock.add(const Duration(minutes: 1));
    final b = await add('Б');
    clock = clock.add(const Duration(minutes: 1));
    final c = await add('В');

    List<int> ids(List<BookRow> rows) => [for (final r in rows) r.id];
    expect(ids(await repo.watchBooks().first), [c.id, b.id, a.id]);

    clock = clock.add(const Duration(minutes: 1));
    await repo.markOpened(a.id);
    clock = clock.add(const Duration(minutes: 1));
    await repo.markOpened(b.id);

    expect(ids(await repo.watchBooks().first), [b.id, a.id, c.id]);
    expect((await repo.findById(b.id))!.openedAt, clock);

    clock = clock.add(const Duration(minutes: 1));
    final touched = (await repo.touch(c.id))!;

    expect(touched.touchedAt, clock);
    expect(touched.openedAt, isNull, reason: 'imported again, not opened');
    expect(ids(await repo.watchBooks().first), [c.id, b.id, a.id]);
    expect((await repo.lastOpened())!.id, b.id);
  });

  test('adds a book with its cover file', () async {
    final row = await add('Книга', cover: png);

    expect(row.coverFile, 'cover.png');
    expect(repo.coverFile(row)!.readAsBytesSync(), png.bytes);
    expect((await repo.findById(row.id))!.coverFile, 'cover.png');
  });

  test('a cover that cannot be written leaves the book without it', () async {
    // A directory in place of the temporary file makes the write fail.
    Directory('${store.bookDir(1).path}/cover.png.tmp')
        .createSync(recursive: true);

    final row = await add('Книга', cover: png);

    expect(row.id, 1);
    expect(row.coverFile, isNull);
    expect(await repo.loadContent(row), isNotNull);
  });

  test('replaceContent stores, changes and removes the cover', () async {
    final row = await add('Книга', cover: png);
    Future<BookRow> replace(BookCover? cover) async {
      await repo.replaceContent(
        row.id,
        content: bookTitled('Книга'),
        parserVersion: 2,
        wordCount: 5,
        position: ReadingPosition.start,
        cover: cover,
      );
      return (await repo.findById(row.id))!;
    }

    final changed = await replace(jpg);
    expect(changed.coverFile, 'cover.jpg');
    expect(repo.coverFile(changed)!.readAsBytesSync(), jpg.bytes);
    expect(
      store.coverFile(row.id, 'cover.png').existsSync(),
      isFalse,
      reason: 'the old cover is removed',
    );

    final removed = await replace(null);
    expect(removed.coverFile, isNull);
    expect(store.coverFile(row.id, 'cover.jpg').existsSync(), isFalse);
  });

  test('the last opened book; none before any was opened', () async {
    final a = await add('А');
    final b = await add('Б');
    expect(await repo.lastOpened(), isNull, reason: 'added is not opened');

    clock = clock.add(const Duration(minutes: 1));
    await repo.markOpened(b.id);
    clock = clock.add(const Duration(minutes: 1));
    await repo.markOpened(a.id);

    expect((await repo.lastOpened())!.id, a.id);
  });

  test('the list stream updates on changes', () async {
    final updates = repo.watchBooks().map((rows) => rows.length);
    final expectation = expectLater(updates, emitsInOrder([0, 1, 0]));

    final row = await add('Книга');
    await repo.deleteBook(row.id);
    await expectation;
  });

  test('replaceContent stores the reparsed model and moved position', () async {
    final row = await add('Книга');
    final reparsed = bookTitled('Книга, вторая редакция');
    const moved = ReadingPosition(
      wordIndex: 4,
      anchor: TextAnchor(sectionIndex: 0, blockIndex: 1, charOffset: 7),
    );

    expect(
      await store.loadContent(row.id, 2),
      isNull,
      reason: 'new parser version: reparse needed',
    );
    await repo.replaceContent(
      row.id,
      content: reparsed,
      parserVersion: 2,
      wordCount: 6,
      position: moved,
    );

    final saved = (await repo.findById(row.id))!;
    expect(saved.parserVersion, 2);
    expect(saved.wordCount, 6);
    expect(saved.position, moved);
    expect((await repo.loadContent(saved))!.meta.title, reparsed.meta.title);
  });

  test('deletes the row and the files', () async {
    final row = await add('Книга');
    final keep = await add('Другая');

    await repo.deleteBook(row.id);

    expect(await repo.findById(row.id), isNull);
    expect(store.bookDir(row.id).existsSync(), isFalse);
    expect(store.bookDir(keep.id).existsSync(), isTrue);
  });

  test('ids of deleted books are not reused', () async {
    final first = await add('Книга');
    await repo.deleteBook(first.id);

    final second = await add('Новая');
    expect(second.id, greaterThan(first.id));
  });
}
