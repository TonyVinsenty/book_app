import 'dart:io';
import 'dart:isolate';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_repository.dart';
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
/// position saved by another tokenizer or parser moves by its anchor.
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

    final (parsed, tokens) = await _parseInIsolate(
      _books.sourceFile(book).path,
      book.sourceName,
    );
    final word = tokens.resolve(book.position);
    await _books.replaceContent(
      id,
      content: parsed.content,
      parserVersion: parsed.parserVersion,
      wordCount: parsed.wordCount,
      position: tokens.positionOf(word),
    );
    return OpenedBook((await _books.findById(id))!, tokens, word);
  }
}

// Top-level, so the isolate closures capture only their arguments.
Future<(ParsedBook, BookTokens)> _parseInIsolate(String path, String name) =>
    Isolate.run(() {
      final parsed = parseBook(File(path).readAsBytesSync(), fileName: name);
      return (parsed, tokenize(parsed.content));
    });

Future<BookTokens> _tokenizeInIsolate(BookContent content) =>
    Isolate.run(() => tokenize(content));
