import 'dart:io';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/book_share.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

BookRow _book({
  String title = 'Шинель',
  List<String> authors = const ['Н. В. Гоголь'],
  SourceFormat format = SourceFormat.fb2,
}) => BookRow(
  id: 1,
  title: title,
  authors: authors,
  sourceFormat: format,
  sourceName: 'shinel.fb2',
  sourceSize: 4,
  sourceHash: '1',
  parserVersion: 1,
  wordCount: 10,
  positionWord: 0,
  positionSection: 0,
  positionBlock: 0,
  positionChar: 0,
  addedAt: DateTime(2026, 10, 22),
  touchedAt: DateTime(2026, 10, 22),
);

void main() {
  group('the shared file name', () {
    test('"Автор — Название" with the format extension', () {
      expect(shareNameOf(_book()), 'Н. В. Гоголь — Шинель.fb2');
      expect(
        shareNameOf(
          _book(
            authors: ['И. Ильф', 'Е. Петров'],
            title: 'Двенадцать стульев',
            format: SourceFormat.fb2zip,
          ),
        ),
        'И. Ильф, Е. Петров — Двенадцать стульев.fb2.zip',
      );
      expect(
        shareNameOf(_book(authors: [], format: SourceFormat.epub)),
        'Шинель.epub',
      );
    });

    test('characters file systems forbid go, long names are cut', () {
      expect(
        shareNameOf(_book(title: 'Что делать? / Роман: "часть 1"...')),
        'Н. В. Гоголь — Что делать Роман часть 1.fb2',
      );
      expect(shareNameOf(_book(authors: [], title: ' ?? ')), 'book.fb2');
      final long = shareNameOf(_book(authors: [], title: 'Я' * 300));
      expect(long, '${'Я' * 100}.fb2');
    });

    test('the type of each format', () {
      expect(shareMimeOf(SourceFormat.fb2), 'application/x-fictionbook+xml');
      expect(shareMimeOf(SourceFormat.fb2zip), 'application/zip');
      expect(shareMimeOf(SourceFormat.epub), 'application/epub+zip');
      expect(shareMimeOf(SourceFormat.txt), 'text/plain');
    });
  });

  test('a copy under the readable name goes to the share sheet; earlier '
      'copies are removed', () async {
    final temp = Directory.systemTemp.createTempSync('book_share_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = ContentStore(Directory('${temp.path}/books'));
    final book = _book();
    final source = store.sourceFile(book.id, book.sourceFormat)
      ..createSync(recursive: true)
      ..writeAsStringSync('<FictionBook/>');
    final dir = Directory('${temp.path}/share');
    final old = File('${dir.path}/old.fb2')..createSync(recursive: true);
    final calls = <(String, String)>[];
    final sharer = BookSharer(BookRepository(db, store), dir, (
      path,
      mime,
    ) async {
      calls.add((path, mime));
    });

    await sharer.share(book);

    expect(calls, hasLength(1));
    final (path, mime) = calls.single;
    expect(
      path,
      '${dir.path}${Platform.pathSeparator}Н. В. Гоголь — Шинель.fb2',
    );
    expect(mime, 'application/x-fictionbook+xml');
    expect(File(path).readAsStringSync(), '<FictionBook/>');
    expect(old.existsSync(), isFalse);
    expect(source.existsSync(), isTrue, reason: 'the book keeps its file');
  });
}
