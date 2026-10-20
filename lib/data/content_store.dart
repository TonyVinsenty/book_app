import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/book_cover.dart';

/// Files of the books on disk (ADR 0002): `<root>/<bookId>/` holds
/// `source.<ext>` (a copy of the imported file, for reparsing),
/// `content.v<N>.json.gz` (the parsed model, N = parser version),
/// `cover.<ext>` (the cover picture as it was in the book) and `pages/`
/// (saved page splits, ADR 0003 addendum 2 п. 7).
final class ContentStore {
  ContentStore(this.root);

  /// `books/` inside the app support directory.
  final Directory root;

  Directory bookDir(int bookId) => Directory(_join(root.path, '$bookId'));

  File sourceFile(int bookId, SourceFormat format) =>
      File(_join(bookDir(bookId).path, 'source.${sourceExtension(format)}'));

  File contentFile(int bookId, int parserVersion) =>
      File(_join(bookDir(bookId).path, 'content.v$parserVersion.json.gz'));

  /// Copies the imported file into the book folder.
  Future<File> saveSource(int bookId, SourceFormat format, File from) async {
    await bookDir(bookId).create(recursive: true);
    return _replace(sourceFile(bookId, format), (tmp) => from.copy(tmp.path));
  }

  Directory pagesDir(int bookId) =>
      Directory(_join(bookDir(bookId).path, 'pages'));

  File coverFile(int bookId, String name) =>
      File(_join(bookDir(bookId).path, name));

  /// Writes the cover (or removes it when [cover] is null) and returns its
  /// file name; covers with another extension are removed.
  Future<String?> saveCover(int bookId, BookCover? cover) async {
    final dir = bookDir(bookId);
    await dir.create(recursive: true);
    final name = cover == null ? null : 'cover.${cover.extension}';
    if (cover != null) {
      await _replace(
        coverFile(bookId, name!),
        (tmp) => tmp.writeAsBytes(cover.bytes, flush: true),
      );
    }
    await for (final entity in dir.list()) {
      final file = entity.uri.pathSegments.last;
      if (entity is File && file.startsWith('cover.') && file != name) {
        await entity.delete();
      }
    }
    return name;
  }

  /// Writes the model (encoding in a background isolate) and removes models
  /// of other parser versions.
  Future<void> saveContent(
    int bookId,
    int parserVersion,
    BookContent content,
  ) async {
    final dir = bookDir(bookId);
    await dir.create(recursive: true);
    final target = contentFile(bookId, parserVersion);
    await _replace(target, (tmp) async {
      final bytes = await Isolate.run(
        () => gzip.encode(utf8.encode(jsonEncode(content.toJson()))),
      );
      return tmp.writeAsBytes(bytes, flush: true);
    });
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File &&
          name.startsWith('content.v') &&
          entity.path != target.path) {
        await entity.delete();
      }
    }
  }

  /// The stored model, or null when there is none for [parserVersion] (the
  /// book must be reparsed from its source). Decoded in a background isolate.
  Future<BookContent?> loadContent(int bookId, int parserVersion) async {
    final file = contentFile(bookId, parserVersion);
    if (!file.existsSync()) return null;
    final path = file.path;
    return Isolate.run(() {
      final json = jsonDecode(
        utf8.decode(gzip.decode(File(path).readAsBytesSync())),
      );
      return BookContent.fromJson(json as Map<String, Object?>);
    });
  }

  Future<void> deleteBook(int bookId) async {
    final dir = bookDir(bookId);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Writes through a temporary file and renames it, so a crash never leaves
  /// a half-written file under the real name.
  static Future<File> _replace(
    File target,
    Future<File> Function(File tmp) write,
  ) async {
    final tmp = File('${target.path}.tmp');
    try {
      await write(tmp);
      return await tmp.rename(target.path);
    } catch (_) {
      if (tmp.existsSync()) await tmp.delete();
      rethrow;
    }
  }

  static String _join(String dir, String name) =>
      '$dir${Platform.pathSeparator}$name';
}

/// File extension of a stored source.
String sourceExtension(SourceFormat format) => switch (format) {
  SourceFormat.txt => 'txt',
  SourceFormat.fb2 => 'fb2',
  SourceFormat.fb2zip => 'fb2.zip',
  SourceFormat.epub => 'epub',
};
