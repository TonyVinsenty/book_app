import 'dart:io';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/book_cover.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:drift/drift.dart';

/// The library: book rows in the database plus their files on disk. Screens
/// reach it only through providers (ADR 0006).
final class BookRepository {
  BookRepository(this._db, this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final ContentStore _store;
  final DateTime Function() _now;

  /// All books, last added, opened or imported again first.
  Stream<List<BookRow>> watchBooks() {
    final query = _db.select(_db.books)
      ..orderBy([
        (b) => OrderingTerm.desc(b.touchedAt),
        (b) => OrderingTerm.desc(b.id),
      ]);
    return query.watch();
  }

  /// The book opened most recently, to reopen on start; null if none was.
  /// A queued or abandoned book was put aside, so it is skipped.
  Future<BookRow?> lastOpened() =>
      (_db.select(_db.books)
            ..where((b) => b.openedAt.isNotNull() & b.statusMark.isNull())
            ..orderBy([(b) => OrderingTerm.desc(b.openedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<BookRow?> findById(int id) =>
      (_db.select(_db.books)..where((b) => b.id.equals(id))).getSingleOrNull();

  /// The book imported from a file with this SHA-256, if any (duplicates).
  Future<BookRow?> findByHash(String sourceHash) => (_db.select(
    _db.books,
  )..where((b) => b.sourceHash.equals(sourceHash))).getSingleOrNull();

  /// Adds a parsed book: a row, then the source copy, the model and the
  /// cover. If the files can't be written, the row is removed again.
  Future<BookRow> addBook({
    required BookContent content,
    required File source,
    required String sourceName,
    required String sourceHash,
    required int parserVersion,
    required int wordCount,
    BookCover? cover,
  }) async {
    final meta = content.meta;
    final now = _now();
    final row = await _db
        .into(_db.books)
        .insertReturning(
          BooksCompanion.insert(
            title: meta.title,
            authors: meta.authors,
            series: Value(meta.series),
            seriesNumber: Value(meta.seriesNumber),
            lang: Value(meta.lang),
            annotation: Value(meta.annotation),
            sourceFormat: meta.sourceFormat,
            sourceName: sourceName,
            sourceSize: await source.length(),
            sourceHash: sourceHash,
            parserVersion: parserVersion,
            wordCount: wordCount,
            addedAt: now,
            touchedAt: now,
          ),
        );
    try {
      await _store.saveSource(row.id, meta.sourceFormat, source);
      await _store.saveContent(row.id, parserVersion, content);
    } catch (_) {
      await (_db.delete(_db.books)..where((b) => b.id.equals(row.id))).go();
      await _store.deleteBook(row.id);
      rethrow;
    }
    if (cover == null) return row;
    final coverFile = await _saveCover(row.id, cover);
    return await _write(row.id, BooksCompanion(coverFile: Value(coverFile))) ??
        row;
  }

  /// The cover is not worth a failed import or open: on a file error the
  /// book is just without it.
  Future<String?> _saveCover(int id, BookCover? cover) async {
    try {
      return await _store.saveCover(id, cover);
    } on FileSystemException {
      return null;
    }
  }

  /// The stored model, or null when it is missing or was built by another
  /// parser version (reparse from [sourceFile], then [replaceContent]).
  Future<BookContent?> loadContent(BookRow book) =>
      _store.loadContent(book.id, book.parserVersion);

  File sourceFile(BookRow book) =>
      _store.sourceFile(book.id, book.sourceFormat);

  /// The cover picture, or null when the book has none.
  File? coverFile(BookRow book) => switch (book.coverFile) {
    final name? => _store.coverFile(book.id, name),
    null => null,
  };

  /// Stores a reparsed model with its cover and the position moved by its
  /// anchor.
  Future<void> replaceContent(
    int id, {
    required BookContent content,
    required int parserVersion,
    required int wordCount,
    required ReadingPosition position,
    BookCover? cover,
  }) async {
    await _store.saveContent(id, parserVersion, content);
    final coverFile = await _saveCover(id, cover);
    await _write(
      id,
      _positionCompanion(position).copyWith(
        parserVersion: Value(parserVersion),
        wordCount: Value(wordCount),
        coverFile: Value(coverFile),
      ),
    );
  }

  /// Word count and position after a tokenizer change.
  Future<void> updateWords(
    int id, {
    required int wordCount,
    required ReadingPosition position,
  }) => (_db.update(_db.books)..where((b) => b.id.equals(id))).write(
    _positionCompanion(position).copyWith(wordCount: Value(wordCount)),
  );

  Future<void> savePosition(int id, ReadingPosition position) => (_db.update(
    _db.books,
  )..where((b) => b.id.equals(id))).write(_positionCompanion(position));

  Future<void> markOpened(int id) {
    final now = _now();
    return _write(
      id,
      BooksCompanion(openedAt: Value(now), touchedAt: Value(now)),
    );
  }

  /// Brings the book on top of the library (it was imported again); null
  /// when it is gone.
  Future<BookRow?> touch(int id) =>
      _write(id, BooksCompanion(touchedAt: Value(_now())));

  /// Marks the book read — at its end or by hand; an earlier mark stays.
  /// Takes off "queued" / "abandoned": a book has one status.
  Future<void> markFinished(int id) =>
      (_db.update(
        _db.books,
      )..where((b) => b.id.equals(id) & b.finishedAt.isNull())).write(
        BooksCompanion(
          finishedAt: Value(_now()),
          statusMark: const Value(null),
        ),
      );

  /// "Reading again": the read mark goes away by hand only, never by
  /// reading from the start.
  Future<void> markUnfinished(int id) =>
      _write(id, const BooksCompanion(finishedAt: Value(null)));

  /// Sets "queued" or "abandoned" (null — neither); takes off the read mark.
  Future<void> setStatusMark(int id, StatusMark? mark) => _write(
    id,
    BooksCompanion(statusMark: Value(mark), finishedAt: const Value(null)),
  );

  /// The book is read on: "queued" / "abandoned" go away. Writes nothing when
  /// there is no mark, so the reader may call it on every move.
  Future<void> clearStatusMark(int id) =>
      (_db.update(_db.books)
            ..where((b) => b.id.equals(id) & b.statusMark.isNotNull()))
          .write(const BooksCompanion(statusMark: Value(null)));

  /// Removes the row (and its places in collections) and all files of the
  /// book.
  Future<void> deleteBook(int id) async {
    await (_db.delete(_db.books)..where((b) => b.id.equals(id))).go();
    await _store.deleteBook(id);
  }

  /// Removes files of books that are not in the database (a crash while
  /// deleting); best effort, at app start.
  Future<void> removeLostFiles() async {
    final (ids, lastId) = await _db.transaction(
      () async => (
        {for (final r in await _db.select(_db.books).get()) r.id},
        await _db.lastBookId() ?? 0,
      ),
    );
    try {
      await _store.deleteOtherBooks(ids, lastId: lastId);
    } on FileSystemException {
      // Tried again on the next start.
    }
  }

  Future<BookRow?> _write(int id, BooksCompanion changes) async =>
      (await (_db.update(
        _db.books,
      )..where((b) => b.id.equals(id))).writeReturning(changes)).singleOrNull;

  static BooksCompanion _positionCompanion(ReadingPosition p) => BooksCompanion(
    positionWord: Value(p.wordIndex),
    positionSection: Value(p.anchor.sectionIndex),
    positionBlock: Value(p.anchor.blockIndex),
    positionChar: Value(p.anchor.charOffset),
  );
}
