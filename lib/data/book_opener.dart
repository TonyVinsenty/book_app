import 'dart:io';
import 'dart:isolate';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/relocate.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';

/// A book ready for reading: its words and the word to open at.
final class OpenedBook {
  const OpenedBook(this.book, this.tokens, this.wordIndex);

  final BookRow book;
  final BookTokens tokens;
  final int wordIndex;
}

/// Loads a book for the reader: the stored model, or a fresh parse of the
/// source file when the parser changed. Words are rebuilt on every open; a
/// position saved by another tokenizer moves by its anchor; after a reparse
/// it moves by the words around it (`relocateWord`).
final class BookOpener {
  BookOpener(this._books);

  final BookRepository _books;

  /// Throws [StateError] when the book is gone and [ImportException] when
  /// the source can no longer be parsed.
  Future<OpenedBook> open(int id) async {
    final book = await _books.findById(id);
    if (book == null) throw StateError('No book $id');
    final stored = book.parserVersion < parserVersionOf(book.sourceFormat)
        ? null
        : await _books.loadContent(book);
    if (stored != null) {
      final tokens = await _tokenizeInIsolate(stored);
      final word = tokens.resolve(book.position);
      if (tokens.length == book.wordCount && word == book.positionWord) {
        return OpenedBook(book, tokens, word);
      }
      // The tokenizer changed: keep the progress shown in the library right.
      await _books.updateWords(
        id,
        wordCount: tokens.length,
        position: tokens.positionOf(word),
      );
      return OpenedBook((await _books.findById(id))!, tokens, word);
    }

    final images = await _books.newImagesDir(id);
    final (parsed, tokens, moved) = await _parseInIsolate(
      _books.sourceFile(book).path,
      book.sourceName,
      images.path,
      await _oldContent(book),
      book.position,
    );
    // Without the old model: note labels and pictures shift blocks and
    // offsets but add no words (ADR 0008), so the same number of words
    // means the same words.
    final word =
        moved ??
        (tokens.length == book.wordCount
            ? tokens.positionOf(book.positionWord).wordIndex
            : tokens.resolve(book.position));
    await _books.replaceContent(
      id,
      content: parsed.content,
      parserVersion: parsed.parserVersion,
      wordCount: parsed.wordCount,
      position: tokens.positionOf(word),
      cover: parsed.cover,
      images: images,
    );
    return OpenedBook((await _books.findById(id))!, tokens, word);
  }

  /// The model of the previous parse, if it is still readable.
  Future<BookContent?> _oldContent(BookRow book) async {
    try {
      return await _books.loadContent(book);
    } on Object {
      return null;
    }
  }
}

// Top-level, so the isolate closures capture only their arguments.
/// Also the word where reading goes on, found in [old] by [position].
Future<(ParsedBook, BookTokens, int?)> _parseInIsolate(
  String path,
  String name,
  String images,
  BookContent? old,
  ReadingPosition position,
) => Isolate.run(() {
  final parsed = parseBook(
    File(path).readAsBytesSync(),
    fileName: name,
    images: FileImageSink(Directory(images)),
  );
  final tokens = tokenize(parsed.content);
  if (old == null) return (parsed, tokens, null);
  final before = tokenize(old);
  return (parsed, tokens, relocateWord(before, before.resolve(position), tokens));
});

Future<BookTokens> _tokenizeInIsolate(BookContent content) =>
    Isolate.run(() => tokenize(content));
