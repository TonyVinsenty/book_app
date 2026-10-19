import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/parsers/epub_parser.dart';
import 'package:book_app/book/parsers/fb2_parser.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// An FB2 whose cover is a PNG-looking picture of [mark] bytes.
String fb2WithCover(int mark) {
  final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, mark, mark];
  return '<?xml version="1.0" encoding="utf-8"?>'
      '<FictionBook xmlns:l="http://www.w3.org/1999/xlink">'
      '<description><title-info><book-title>С обложкой</book-title>'
      '<coverpage><image l:href="#c.png"/></coverpage>'
      '</title-info></description>'
      '<body><section><p>Раз два три.</p></section></body>'
      '<binary id="c.png" content-type="image/png">${base64.encode(png)}'
      '</binary></FictionBook>';
}

void main() {
  late Directory temp;
  late AppDatabase db;
  late BookRepository repo;
  late BookImporter importer;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('import_');
    db = AppDatabase(NativeDatabase.memory());
    repo = BookRepository(db, ContentStore(Directory('${temp.path}/books')));
    importer = BookImporter(repo);
  });
  tearDown(() async {
    await db.close();
    temp.deleteSync(recursive: true);
  });

  File copyFixture(String path) {
    final name = path.split('/').last;
    final dir = Directory('${temp.path}/in')..createSync(recursive: true);
    return File(path).copySync('${dir.path}/$name');
  }

  File write(String name, List<int> bytes) =>
      File('${temp.path}/$name')..writeAsBytesSync(bytes);

  test('adds an FB2 book with its metadata, hash and files', () async {
    final file = copyFixture('test/fixtures/fb2/utf8_nested.fb2');
    final result = await importer.importFile(file);

    final book = (result as ImportAdded).book;
    expect(result.fileName, 'utf8_nested.fb2');
    expect(book.sourceFormat, SourceFormat.fb2);
    expect(book.parserVersion, fb2ParserVersion);
    expect(book.sourceName, 'utf8_nested.fb2');
    expect(book.sourceHash, sha256.convert(file.readAsBytesSync()).toString());
    expect(book.wordCount, greaterThan(0));
    expect(repo.sourceFile(book).readAsBytesSync(), file.readAsBytesSync());
    expect(await repo.loadContent(book), isNotNull);
  });

  test('adds a TXT book titled by its file name', () async {
    final file = copyFixture('test/fixtures/txt/cp1251_librus.txt');
    final book = ((await importer.importFile(file)) as ImportAdded).book;

    expect(book.title, 'cp1251_librus');
    expect(book.sourceFormat, SourceFormat.txt);
    expect(book.parserVersion, txtParserVersion);
  });

  test('adds an EPUB book; the source is stored as is', () async {
    final file = copyFixture('test/fixtures/epub/epub3_ru.epub');
    final book = ((await importer.importFile(file)) as ImportAdded).book;

    expect(book.title, 'Утро над рекой');
    expect(book.sourceFormat, SourceFormat.epub);
    expect(book.parserVersion, epubParserVersion);
    expect(repo.sourceFile(book).path, endsWith('.epub'));
    expect(repo.sourceFile(book).readAsBytesSync(), file.readAsBytesSync());
  });

  test('the same file twice is a duplicate, also under another name', () async {
    final first = copyFixture('test/fixtures/txt/utf8_lines.txt');
    final added = (await importer.importFile(first)) as ImportAdded;
    final again = first.copySync('${temp.path}/renamed.txt');

    final result = await importer.importFile(again);

    expect((result as ImportDuplicate).book.id, added.book.id);
    expect(result.fileName, 'renamed.txt');
    expect(await db.select(db.books).get(), hasLength(1));
  });

  test('failures come back as results, nothing is stored', () async {
    final cases = <String, (File, ImportError)>{
      'epub without opf': (
        write(
          'a.epub',
          ZipEncoder().encodeBytes(
            Archive()
              ..addFile(ArchiveFile.string('META-INF/container.xml', '')),
          ),
        ),
        ImportError.damaged,
      ),
      'drm epub': (copyFixture('test/fixtures/epub/drm.epub'), ImportError.drm),
      'zip without books': (
        copyFixture('test/fixtures/zip/only_picture.zip'),
        ImportError.unsupportedFormat,
      ),
      'broken zip': (
        copyFixture('test/fixtures/zip/broken.fb2.zip'),
        ImportError.damaged,
      ),
      'binary': (
        write('a.png', [for (var i = 0; i < 2000; i++) i * 7 % 256]),
        ImportError.unsupportedFormat,
      ),
      'fb2 without text': (
        write('a.fb2', utf8.encode('<?xml version="1.0"?><FictionBook><bo')),
        ImportError.damaged,
      ),
      'empty text': (
        write('a.txt', utf8.encode(' \n\n ')),
        ImportError.damaged,
      ),
      'missing file': (File('${temp.path}/nope.txt'), ImportError.unreadable),
    };
    for (final MapEntry(key: name, value: (file, error)) in cases.entries) {
      final result = await importer.importFile(file);
      expect((result as ImportFailed).error, error, reason: name);
    }
    expect(await db.select(db.books).get(), isEmpty);
  });

  test('a ZIP box is unpacked and its FB2 stored unpacked', () async {
    const fb2 = 'test/fixtures/fb2/utf8_nested.fb2';
    final fb2Bytes = File(fb2).readAsBytesSync();
    for (final zip in ['plain.fb2.zip', 'folder_first.zip']) {
      final file = copyFixture('test/fixtures/zip/$zip');
      final result = await importer.importFile(file);

      final book = (result as ImportAdded).book;
      expect(result.fileName, 'utf8_nested.fb2', reason: zip);
      expect(book.sourceFormat, SourceFormat.fb2);
      expect(book.sourceName, 'utf8_nested.fb2');
      expect(book.sourceHash, sha256.convert(fb2Bytes).toString());
      expect(repo.sourceFile(book).readAsBytesSync(), fb2Bytes);
      expect(file.parent.listSync().whereType<Directory>(), isEmpty);
      await repo.deleteBook(book.id);
    }
  });

  test(
    'the book in a box need not be first; macOS forks are skipped',
    () async {
      final file = copyFixture('test/fixtures/zip/fb2_not_first.zip');
      final result = await importer.importFile(file);

      expect((result as ImportAdded).fileName, 'utf8_nested.fb2');
    },
  );

  test('the cover is stored with the book', () async {
    final file = write('c.fb2', utf8.encode(fb2WithCover(5)));
    final book = ((await importer.importFile(file)) as ImportAdded).book;

    expect(book.coverFile, 'cover.png');
    expect(repo.coverFile(book)!.readAsBytesSync().last, 5);
  });

  test('a duplicate comes on top of the list', () async {
    var clock = DateTime(2026, 10, 19, 12);
    final repo = BookRepository(
      db,
      ContentStore(Directory('${temp.path}/books')),
      now: () => clock,
    );
    final importer = BookImporter(repo);
    final first = write('a.txt', utf8.encode('Первая книга.'));
    final a = ((await importer.importFile(first)) as ImportAdded).book;
    clock = clock.add(const Duration(minutes: 1));
    final b = ((await importer.importFile(
      write('b.txt', utf8.encode('Вторая книга.')),
    )) as ImportAdded).book;
    expect([for (final r in await repo.watchBooks().first) r.id], [b.id, a.id]);

    clock = clock.add(const Duration(minutes: 1));
    final again = await importer.importFile(first);

    expect((again as ImportDuplicate).book.touchedAt, clock);
    expect([for (final r in await repo.watchBooks().first) r.id], [a.id, b.id]);
  });

  test('FB2 and FB2.ZIP of one book are a duplicate', () async {
    final fb2 = copyFixture('test/fixtures/fb2/utf8_nested.fb2');
    final added = (await importer.importFile(fb2)) as ImportAdded;

    final zip = copyFixture('test/fixtures/zip/plain.fb2.zip');
    final result = await importer.importFile(zip);

    expect((result as ImportDuplicate).book.id, added.book.id);
    expect(await db.select(db.books).get(), hasLength(1));
  });

  test('titleFromFileName drops book extensions only', () {
    expect(titleFromFileName('Война и мир.fb2.zip'), 'Война и мир');
    expect(titleFromFileName('book.TXT'), 'book');
    expect(titleFromFileName('v1.2 notes'), 'v1.2 notes');
    expect(titleFromFileName('.txt'), '.txt');
  });
}
