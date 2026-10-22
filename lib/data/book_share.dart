import 'dart:io';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/platform/share_channel.dart';

/// "Поделиться" (11а.6): the book's own file under a readable name,
/// "Автор — Название.fb2", copied into a folder of its own in [_dir] and
/// handed to the share sheet.
final class BookSharer {
  BookSharer(this._books, this._dir, this._share);

  final BookRepository _books;
  final Directory _dir;
  final ShareFile _share;

  Future<void> share(BookRow book) async {
    final now = DateTime.now();
    await _removeOld(now);
    // A folder per share: an app may still be reading an earlier copy.
    final sep = Platform.pathSeparator;
    final dir = await Directory(
      '${_dir.path}$sep${now.microsecondsSinceEpoch}-${_count++}',
    ).create(recursive: true);
    final copy = await _books
        .sourceFile(book)
        .copy('${dir.path}$sep${shareNameOf(book)}');
    await _share(copy.path, shareMimeOf(book.sourceFormat));
  }

  /// Copies of shares older than a day: the apps they went to have them.
  Future<void> _removeOld(DateTime now) async {
    if (!_dir.existsSync()) return;
    await for (final entry in _dir.list()) {
      try {
        if (now.difference(entry.statSync().modified) > _keep) {
          await entry.delete(recursive: true);
        }
      } on FileSystemException {
        // Gone already or in use: next time.
      }
    }
  }

  static const _keep = Duration(days: 1);
  var _count = 0;
}

/// "Автор — Название.fb2" (just the title without authors), with the
/// characters file systems forbid taken out.
String shareNameOf(BookRow book) {
  String clean(String s) => s
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final authors = clean(book.authors.join(', '));
  final title = clean(book.title);
  var name = [
    if (authors.isNotEmpty) authors,
    if (title.isNotEmpty) title,
  ].join(' — ');
  // Long names are cut (file systems allow 255 bytes, Cyrillic takes two);
  // no dots at the ends: a hidden file, or one before the extension.
  final runes = name.runes.toList();
  if (runes.length > 100) name = String.fromCharCodes(runes.take(100));
  name = name.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  if (name.isEmpty) name = 'book';
  return '$name.${sourceExtension(book.sourceFormat)}';
}

String shareMimeOf(SourceFormat format) => switch (format) {
  SourceFormat.txt => 'text/plain',
  SourceFormat.fb2 => 'application/x-fictionbook+xml',
  SourceFormat.fb2zip => 'application/zip',
  SourceFormat.epub => 'application/epub+zip',
};
