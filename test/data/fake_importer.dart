import 'dart:async';
import 'dart:io';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/db/app_database.dart';

BookRow bookRow(String title) => BookRow(
  id: title.hashCode,
  title: title,
  authors: const [],
  sourceFormat: SourceFormat.txt,
  sourceName: title,
  sourceSize: 1,
  sourceHash: title,
  parserVersion: 1,
  wordCount: 1,
  positionWord: 0,
  positionSection: 0,
  positionBlock: 0,
  positionChar: 0,
  addedAt: DateTime(2026),
  touchedAt: DateTime(2026),
);

/// Imports by file name: `dup*` is a duplicate, `bad*` fails, `box*`
/// holds three books; each file waits for [release] when [hold] is on.
class FakeImporter implements BookImporter {
  final calls = <String>[];
  bool hold = false;
  Completer<void>? _gate;

  /// Waits for the next file to start, then lets it finish.
  Future<void> release() async {
    while (_gate == null) {
      await Future<void>.delayed(Duration.zero);
    }
    final gate = _gate!;
    _gate = null;
    gate.complete();
  }

  @override
  Future<List<ImportResult>> importFile(File file, {OnBook? onBook}) async {
    final name = file.path.split(RegExp(r'[/\\]')).last;
    calls.add(name);
    if (hold) await (_gate = Completer<void>()).future;
    final names = name.startsWith('box')
        ? ['$name-1', '$name-2', '$name-3']
        : [name];
    return [
      for (final book in names)
        () {
          onBook?.call(book, names.length);
          if (book.startsWith('dup')) {
            return ImportDuplicate(book, bookRow(book));
          }
          if (book.startsWith('bad')) {
            return ImportFailed(book, ImportError.damaged);
          }
          return ImportAdded(book, bookRow(book));
        }(),
    ];
  }
}
