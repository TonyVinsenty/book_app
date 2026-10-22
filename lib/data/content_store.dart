import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/book_cover.dart';
import 'package:book_app/book/model/book_image.dart';

/// Files of the books on disk (ADR 0002): `<root>/<bookId>/` holds
/// `source.<ext>` (a copy of the imported file, for reparsing),
/// `content.v<N>.json.gz` (the parsed model, N = parser version),
/// `cover.<ext>` (the cover picture as it was in the book), `img/` (the
/// pictures of the text, ADR 0008) and `pages/` (saved page splits, ADR 0003
/// addendum 2 п. 7). `incoming/` holds pictures of books being imported.
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

  Directory imagesDir(int bookId) =>
      Directory(_join(bookDir(bookId).path, 'img'));

  /// An empty folder for the pictures of a reparse of the book; they become
  /// its pictures with [replaceImages].
  Future<Directory> newImagesDir(int bookId) async {
    final dir = Directory('${imagesDir(bookId).path}.new');
    // Left by a crash or a failed parse.
    if (dir.existsSync()) await dir.delete(recursive: true);
    return dir;
  }

  /// An empty folder for the pictures of a book being imported, before it
  /// has an id; it becomes the book's with [replaceImages].
  Future<Directory> newIncomingImagesDir() async {
    final incoming = Directory(_join(root.path, 'incoming'));
    await incoming.create(recursive: true);
    final dir = await incoming.createTemp('img_');
    // Pictures are written only when the book has some.
    await dir.delete();
    return dir;
  }

  /// Makes [from] (written by a [FileImageSink], or never created when the
  /// book has no pictures) the pictures of the book, in place of the old
  /// ones. Done before the model is saved: a crash in between leaves the
  /// old model, which is parsed again anyway.
  Future<void> replaceImages(int bookId, Directory from) async {
    await bookDir(bookId).create(recursive: true);
    final target = imagesDir(bookId);
    final old = Directory('${target.path}.old');
    if (old.existsSync()) await old.delete(recursive: true);
    if (target.existsSync()) await target.rename(old.path);
    if (from.existsSync()) await from.rename(target.path);
    if (old.existsSync()) await old.delete(recursive: true);
  }

  Future<void> deleteBook(int bookId) async {
    final dir = bookDir(bookId);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Removes book folders with ids up to [lastId] that are not in [bookIds]
  /// — left by a crash between the two steps of deleting a book. Newer ids
  /// may be books being added right now.
  Future<void> deleteOtherBooks(Set<int> bookIds, {required int lastId}) async {
    if (!root.existsSync()) return;
    await _deleteOldIncoming();
    await for (final entity in root.list()) {
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      final id = int.tryParse(name);
      if (entity is Directory &&
          id != null &&
          id <= lastId &&
          !bookIds.contains(id)) {
        await entity.delete(recursive: true);
      }
    }
  }

  /// Pictures of imports cut short by a crash; recent ones may belong to an
  /// import running right now.
  Future<void> _deleteOldIncoming() async {
    final incoming = Directory(_join(root.path, 'incoming'));
    if (!incoming.existsSync()) return;
    final before = DateTime.now().subtract(const Duration(hours: 1));
    await for (final entity in incoming.list()) {
      if (entity.statSync().modified.isBefore(before)) {
        await entity.delete(recursive: true);
      }
    }
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

/// Writes the pictures of a book being parsed into [dir], created with the
/// first one. Synchronous: runs in the parsing isolate.
final class FileImageSink implements ImageSink {
  FileImageSink(this.dir);

  final Directory dir;

  @override
  void add(String assetId, Uint8List bytes) {
    dir.createSync(recursive: true);
    File('${dir.path}${Platform.pathSeparator}$assetId')
        .writeAsBytesSync(bytes);
  }
}

/// File extension of a stored source.
String sourceExtension(SourceFormat format) => switch (format) {
  SourceFormat.txt => 'txt',
  SourceFormat.fb2 => 'fb2',
  SourceFormat.fb2zip => 'fb2.zip',
  SourceFormat.epub => 'epub',
};
