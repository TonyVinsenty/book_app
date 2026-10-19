/// The import pipeline (ADR 0005): file → SHA-256 and duplicate check →
/// format by content → parse in a background isolate → library.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:book_app/book/encoding/text_decoder.dart';
import 'package:book_app/book/import/format_detector.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/parsers/fb2_parser.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:crypto/crypto.dart';

/// Why a file was not added; screens turn it into a message.
enum ImportError {
  /// EPUB, ZIP, PDF, pictures… — not readable (yet).
  unsupportedFormat,

  /// Looks like a book but can't be parsed.
  damaged,

  /// The file could not be read or stored.
  unreadable,
}

sealed class ImportResult {
  const ImportResult(this.fileName);

  final String fileName;
}

final class ImportAdded extends ImportResult {
  const ImportAdded(super.fileName, this.book);

  final BookRow book;
}

/// The same file (by SHA-256) is already in the library.
final class ImportDuplicate extends ImportResult {
  const ImportDuplicate(super.fileName, this.book);

  final BookRow book;
}

final class ImportFailed extends ImportResult {
  const ImportFailed(super.fileName, this.error);

  final ImportError error;
}

final class ImportException implements Exception {
  const ImportException(this.error);

  final ImportError error;

  @override
  String toString() => 'ImportException(${error.name})';
}

final class ParsedBook {
  const ParsedBook(this.content, this.parserVersion, this.wordCount);

  final BookContent content;
  final int parserVersion;
  final int wordCount;
}

/// Parses a book of any supported format. Pure and synchronous, so it can
/// run in an isolate. Throws [ImportException].
ParsedBook parseBook(Uint8List bytes, {required String fileName}) {
  final title = titleFromFileName(fileName);
  final BookContent content;
  final int version;
  switch (detectFormat(bytes)) {
    case DetectedFormat.fb2:
      try {
        content = parseFb2(bytes, title: title);
      } on NotFb2Exception {
        throw const ImportException(ImportError.damaged);
      } on NotTextException {
        throw const ImportException(ImportError.damaged);
      }
      version = fb2ParserVersion;
    case DetectedFormat.txt:
      try {
        content = parseTxt(bytes, title: title);
      } on NotTextException {
        throw const ImportException(ImportError.unsupportedFormat);
      }
      version = txtParserVersion;
    case DetectedFormat.fb2zip || DetectedFormat.epub || DetectedFormat.zip:
      throw const ImportException(ImportError.unsupportedFormat);
  }
  final wordCount = tokenize(content).length;
  if (wordCount == 0) throw const ImportException(ImportError.damaged);
  return ParsedBook(content, version, wordCount);
}

const _bookExtensions = ['.fb2.zip', '.fb2', '.txt', '.epub', '.zip'];

/// The title for books without one: the file name without its extension.
String titleFromFileName(String fileName) {
  final lower = fileName.toLowerCase();
  for (final ext in _bookExtensions) {
    if (lower.endsWith(ext) && lower.length > ext.length) {
      return fileName.substring(0, fileName.length - ext.length).trim();
    }
  }
  return fileName.trim();
}

/// Adds book files to the library.
final class BookImporter {
  BookImporter(this._books);

  final BookRepository _books;

  /// Never throws: failures come back as [ImportFailed].
  Future<ImportResult> importFile(File file) async {
    final path = file.path;
    final name = path.split(RegExp(r'[/\\]')).last;
    try {
      final hash = await _hashInIsolate(path);
      final existing = await _books.findByHash(hash);
      if (existing != null) return ImportDuplicate(name, existing);
      final parsed = await _parseInIsolate(path, name);
      final row = await _books.addBook(
        content: parsed.content,
        source: file,
        sourceName: name,
        sourceHash: hash,
        parserVersion: parsed.parserVersion,
        wordCount: parsed.wordCount,
      );
      return ImportAdded(name, row);
    } on ImportException catch (e) {
      return ImportFailed(name, e.error);
    } on FileSystemException {
      return ImportFailed(name, ImportError.unreadable);
    } on Object {
      // A parser bug on a strange file must not crash the app.
      return ImportFailed(name, ImportError.damaged);
    }
  }
}

// Top-level, so the isolate closures capture only the path.
Future<String> _hashInIsolate(String path) =>
    Isolate.run(() => sha256.convert(File(path).readAsBytesSync()).toString());

Future<ParsedBook> _parseInIsolate(String path, String name) =>
    Isolate.run(() => parseBook(File(path).readAsBytesSync(), fileName: name));
