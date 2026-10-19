/// ZIP archives (ADR 0005, addendum 1): a ZIP with `META-INF/container.xml`
/// is an EPUB; any other ZIP is a box of books that are unpacked and
/// imported one by one.
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:book_app/book/import/import_error.dart';

/// A book file inside a box bigger than this (unpacked) is skipped.
const maxBoxedBookSize = 100 * 1024 * 1024;

/// A book that would take the total (unpacked) past this is left in the box.
const maxBoxedTotalSize = 300 * 1024 * 1024;

const _boxedExtensions = ['.fb2', '.epub', '.txt'];

bool startsLikeZip(List<int> b) =>
    b.length >= 4 && b[0] == 0x50 && b[1] == 0x4B && b[2] == 3 && b[3] == 4;

bool isEpubArchive(Archive archive) =>
    archive.findFile('META-INF/container.xml') != null;

/// The book entries of a box, in archive order; nested archives and macOS
/// resource forks (`__MACOSX/`, `._name`) are not books.
List<ArchiveFile> boxedBooks(Archive archive) {
  final books = <ArchiveFile>[];
  var total = 0;
  for (final entry in archive) {
    if (!entry.isFile) continue;
    final path = entry.name.replaceAll(r'\', '/');
    final name = path.split('/').last;
    final lower = name.toLowerCase();
    if (path.startsWith('__MACOSX/') || name.startsWith('._')) continue;
    if (!_boxedExtensions.any(lower.endsWith)) continue;
    if (entry.size > maxBoxedBookSize) continue;
    if (total + entry.size > maxBoxedTotalSize) continue;
    total += entry.size;
    books.add(entry);
  }
  return books;
}

/// Unpacks the books of the ZIP box at [path] into [outDir] (created here),
/// each into its own folder as `<n>/<name>`; returns their paths in archive
/// order. Null when the file is not a box: not a ZIP, or an EPUB.
///
/// Synchronous, for an isolate. Throws [ImportException]: damaged archive,
/// or no books inside.
List<String>? unpackBox(String path, String outDir) {
  final file = File(path);
  final head = file.openSync();
  try {
    if (!startsLikeZip(head.readSync(4))) return null;
  } finally {
    head.closeSync();
  }
  final input = InputFileStream(path);
  try {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } on Object {
      throw const ImportException(ImportError.damaged);
    }
    // A cut file has an entry header but no directory, which the decoder
    // reads as an empty archive.
    if (archive.isEmpty) throw const ImportException(ImportError.damaged);
    if (isEpubArchive(archive)) return null;
    final books = boxedBooks(archive);
    if (books.isEmpty) {
      throw const ImportException(ImportError.unsupportedFormat);
    }
    final paths = <String>[];
    for (final (i, entry) in books.indexed) {
      final name = entry.name.replaceAll(r'\', '/').split('/').last;
      final dir = Directory('$outDir/$i')..createSync(recursive: true);
      final target = '${dir.path}/$name';
      final out = OutputFileStream(target);
      try {
        // The decoder stops at the size the archive declares, which
        // [boxedBooks] has checked against the limits.
        entry.writeContent(out);
      } on Object {
        throw const ImportException(ImportError.damaged);
      } finally {
        out.closeSync();
      }
      paths.add(target);
    }
    return paths;
  } finally {
    input.closeSync();
  }
}
