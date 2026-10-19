/// The import pipeline (ADR 0005): file → a ZIP box is unpacked → SHA-256
/// and duplicate check → format by content → parse in a background
/// isolate → library.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:book_app/book/encoding/text_decoder.dart';
import 'package:book_app/book/import/format_detector.dart';
import 'package:book_app/book/import/import_error.dart';
import 'package:book_app/book/import/zip_box.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/book_cover.dart';
import 'package:book_app/book/parsers/epub_parser.dart';
import 'package:book_app/book/parsers/fb2_parser.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:crypto/crypto.dart';

export 'package:book_app/book/import/import_error.dart';

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

final class ParsedBook {
  const ParsedBook(
    this.content,
    this.parserVersion,
    this.wordCount, {
    this.cover,
  });

  final BookContent content;
  final int parserVersion;
  final int wordCount;
  final BookCover? cover;
}

/// The parser version books of [format] are parsed with now; a model
/// stored by an older one is parsed again from the source (ADR 0002).
int parserVersionOf(SourceFormat format) => switch (format) {
  SourceFormat.txt => txtParserVersion,
  SourceFormat.fb2 || SourceFormat.fb2zip => fb2ParserVersion,
  SourceFormat.epub => epubParserVersion,
};

/// Parses a book of any supported format. Pure and synchronous, so it can
/// run in an isolate. Throws [ImportException].
ParsedBook parseBook(Uint8List bytes, {required String fileName}) {
  final title = titleFromFileName(fileName);
  final BookContent content;
  BookCover? cover;
  final int version;
  switch (detectFormat(bytes)) {
    case DetectedFormat.fb2:
      try {
        (content, cover) = parseFb2WithCover(bytes, title: title);
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
    case DetectedFormat.epub:
      try {
        (content, cover) = parseEpubWithCover(bytes, title: title);
      } on NotEpubException {
        throw const ImportException(ImportError.damaged);
      } on EpubDrmException {
        throw const ImportException(ImportError.drm);
      }
      version = epubParserVersion;
    // Boxes are unpacked before parsing; one inside a box is not opened.
    case DetectedFormat.zip:
      throw const ImportException(ImportError.unsupportedFormat);
  }
  final wordCount = tokenize(content).length;
  if (wordCount == 0) throw const ImportException(ImportError.damaged);
  return ParsedBook(content, version, wordCount, cover: cover);
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

  /// Never throws: failures come back as [ImportFailed]. A ZIP box is
  /// unpacked next to [file] and its first book is imported (the queue
  /// takes the rest, ADR 0005); the result names the book inside.
  Future<ImportResult> importFile(File file) async {
    var name = _baseName(file.path);
    Directory? unpackDir;
    try {
      var book = file;
      if (await _startsLikeZip(file)) {
        final dir = unpackDir = await file.parent.createTemp('unzip_');
        final unpacked = await _unpackInIsolate(file.path, dir.path);
        if (unpacked != null) {
          book = File(unpacked.first);
          name = _baseName(book.path);
        }
      }
      final path = book.path;
      final hash = await _hashInIsolate(path);
      final existing = await _books.findByHash(hash);
      // Deleted in the meantime → added again.
      final touched = existing == null ? null : await _books.touch(existing.id);
      if (touched != null) return ImportDuplicate(name, touched);
      final parsed = await _parseInIsolate(path, name);
      final row = await _books.addBook(
        content: parsed.content,
        source: book,
        sourceName: name,
        sourceHash: hash,
        parserVersion: parsed.parserVersion,
        wordCount: parsed.wordCount,
        cover: parsed.cover,
      );
      return ImportAdded(name, row);
    } on ImportException catch (e) {
      return ImportFailed(name, e.error);
    } on FileSystemException {
      return ImportFailed(name, ImportError.unreadable);
    } on Object {
      // A parser bug on a strange file must not crash the app.
      return ImportFailed(name, ImportError.damaged);
    } finally {
      if (unpackDir != null) await _deleteQuietly(unpackDir);
    }
  }
}

String _baseName(String path) => path.split(RegExp(r'[/\\]')).last;

Future<bool> _startsLikeZip(File file) async {
  final head = await file.openRead(0, 4).fold(<int>[], (a, b) => a..addAll(b));
  return startsLikeZip(head);
}

Future<void> _deleteQuietly(Directory dir) async {
  try {
    if (dir.existsSync()) await dir.delete(recursive: true);
  } on FileSystemException {
    // A leftover in the cache folder is harmless.
  }
}

// Top-level, so the isolate closures capture only the path.
Future<String> _hashInIsolate(String path) =>
    Isolate.run(() => sha256.convert(File(path).readAsBytesSync()).toString());

Future<List<String>?> _unpackInIsolate(String path, String outDir) =>
    Isolate.run(() => unpackBox(path, outDir));

Future<ParsedBook> _parseInIsolate(String path, String name) =>
    Isolate.run(() => parseBook(File(path).readAsBytesSync(), fileName: name));
