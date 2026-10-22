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
import 'package:book_app/book/model/book_image.dart';
import 'package:book_app/book/parsers/epub_parser.dart';
import 'package:book_app/book/parsers/fb2_parser.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
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
/// run in an isolate; pictures of the text go to [images]. Throws
/// [ImportException].
ParsedBook parseBook(
  Uint8List bytes, {
  required String fileName,
  ImageSink? images,
}) {
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

/// Called before each book of a file is imported: its name, and how many
/// books the file holds (more than one only in a ZIP box).
typedef OnBook = void Function(String name, int count);

/// Adds book files to the library. Not final: queue tests fake it.
class BookImporter {
  BookImporter(this._books);

  final BookRepository _books;

  /// Imports the book in [file], or every book of a ZIP box, which is
  /// unpacked next to [file] and removed afterwards (ADR 0005). Never
  /// throws: failures come back as [ImportFailed]; a box that can't be
  /// unpacked is one failure under its own name. With [touch] off a
  /// duplicate stays where it is in the library (books from folders).
  Future<List<ImportResult>> importFile(
    File file, {
    OnBook? onBook,
    bool touch = true,
  }) async {
    Directory? unpackDir;
    try {
      var books = [file];
      try {
        if (await _startsLikeZip(file)) {
          final dir = unpackDir = await file.parent.createTemp('unzip_');
          final unpacked = await _unpackInIsolate(file.path, dir.path);
          if (unpacked != null) books = [for (final p in unpacked) File(p)];
        }
      } on Object catch (e) {
        return [_failure(fileNameOf(file.path), e)];
      }
      final results = <ImportResult>[];
      for (final book in books) {
        final name = fileNameOf(book.path);
        onBook?.call(name, books.length);
        results.add(await _importBook(book, name, touch: touch));
      }
      return results;
    } finally {
      if (unpackDir != null) await _deleteQuietly(unpackDir);
    }
  }

  Future<ImportResult> _importBook(
    File book,
    String name, {
    required bool touch,
  }) async {
    Directory? images;
    try {
      final hash = await _hashInIsolate(book.path);
      final existing = await _books.findByHash(hash);
      if (existing != null && !touch) return ImportDuplicate(name, existing);
      // Deleted in the meantime → added again.
      final touched = existing == null ? null : await _books.touch(existing.id);
      if (touched != null) return ImportDuplicate(name, touched);
      images = await _books.newIncomingImagesDir();
      final parsed = await _parseInIsolate(book.path, name, images.path);
      final row = await _books.addBook(
        content: parsed.content,
        source: book,
        sourceName: name,
        sourceHash: hash,
        parserVersion: parsed.parserVersion,
        wordCount: parsed.wordCount,
        cover: parsed.cover,
        images: images,
      );
      return ImportAdded(name, row);
    } on Object catch (e) {
      return _failure(name, e);
    } finally {
      // Moved into the book when it was added.
      if (images != null) await _deleteQuietly(images);
    }
  }
}

ImportFailed _failure(String name, Object error) =>
    ImportFailed(name, switch (error) {
      ImportException(:final error) => error,
      FileSystemException() => ImportError.unreadable,
      // A parser bug on a strange file must not crash the app.
      _ => ImportError.damaged,
    });

/// The last part of a path, with either kind of slash.
String fileNameOf(String path) => path.split(_slashes).last;

final _slashes = RegExp(r'[/\\]');

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

Future<ParsedBook> _parseInIsolate(String path, String name, String images) =>
    Isolate.run(
      () => parseBook(
        File(path).readAsBytesSync(),
        fileName: name,
        images: FileImageSink(Directory(images)),
      ),
    );
