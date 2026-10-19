import 'dart:io';

import 'package:book_app/book/model/book_content.dart';
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

  /// All books, recently opened first, then recently added.
  Stream<List<BookRow>> watchBooks() {
    final query = _db.select(_db.books)
      ..orderBy([
        (b) => OrderingTerm(
          expression: b.openedAt,
          mode: OrderingMode.desc,
          nulls: NullsOrder.last,
        ),
        (b) => OrderingTerm.desc(b.addedAt),
        (b) => OrderingTerm.desc(b.id),
      ]);
    return query.watch();
  }

  Future<BookRow?> findById(int id) =>
      (_db.select(_db.books)..where((b) => b.id.equals(id))).getSingleOrNull();

  /// The book imported from a file with this SHA-256, if any (duplicates).
  Future<BookRow?> findByHash(String sourceHash) => (_db.select(
    _db.books,
  )..where((b) => b.sourceHash.equals(sourceHash))).getSingleOrNull();

  /// Adds a parsed book: a row, then the source copy and the model. If the
  /// files can't be written, the row is removed again.
  Future<BookRow> addBook({
    required BookContent content,
    required File source,
    required String sourceName,
    required String sourceHash,
    required int parserVersion,
    required int wordCount,
  }) async {
    final meta = content.meta;
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
            addedAt: _now(),
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
    return row;
  }

  /// The stored model, or null when it is missing or was built by another
  /// parser version (reparse from [sourceFile], then [replaceContent]).
  Future<BookContent?> loadContent(BookRow book) =>
      _store.loadContent(book.id, book.parserVersion);

  File sourceFile(BookRow book) =>
      _store.sourceFile(book.id, book.sourceFormat);

  /// Stores a reparsed model and the position moved by its anchor.
  Future<void> replaceContent(
    int id, {
    required BookContent content,
    required int parserVersion,
    required int wordCount,
    required ReadingPosition position,
  }) async {
    await _store.saveContent(id, parserVersion, content);
    await (_db.update(_db.books)..where((b) => b.id.equals(id))).write(
      _positionCompanion(position).copyWith(
        parserVersion: Value(parserVersion),
        wordCount: Value(wordCount),
      ),
    );
  }

  Future<void> savePosition(int id, ReadingPosition position) => (_db.update(
    _db.books,
  )..where((b) => b.id.equals(id))).write(_positionCompanion(position));

  Future<void> markOpened(int id) =>
      (_db.update(_db.books)..where((b) => b.id.equals(id))).write(
        BooksCompanion(openedAt: Value(_now())),
      );

  /// Removes the row and all files of the book.
  Future<void> deleteBook(int id) async {
    await (_db.delete(_db.books)..where((b) => b.id.equals(id))).go();
    await _store.deleteBook(id);
  }

  static BooksCompanion _positionCompanion(ReadingPosition p) => BooksCompanion(
    positionWord: Value(p.wordIndex),
    positionSection: Value(p.anchor.sectionIndex),
    positionBlock: Value(p.anchor.blockIndex),
    positionChar: Value(p.anchor.charOffset),
  );
}
