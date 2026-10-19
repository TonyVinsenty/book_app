import 'dart:io';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/content_store.dart';
import 'package:flutter_test/flutter_test.dart';

const book = BookContent(
  meta: BookMeta(
    title: 'Повесть',
    authors: ['Автор'],
    sourceFormat: SourceFormat.fb2,
  ),
  toc: [TocEntry(title: 'Глава 1', level: 0, sectionIndex: 0)],
  sections: [
    Section(
      title: 'Глава 1',
      blocks: [
        HeadingBlock(text: 'Глава 1'),
        ParagraphBlock(
          text: 'Жили-были дед да баба.',
          spans: [Span(0, 9, SpanKind.emphasis)],
        ),
        SeparatorBlock(),
      ],
    ),
  ],
);

void main() {
  late Directory temp;
  late ContentStore store;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('content_store_');
    store = ContentStore(Directory('${temp.path}/books'));
  });

  tearDown(() => temp.deleteSync(recursive: true));

  List<String> filesOf(int bookId) => [
    for (final f in store.bookDir(bookId).listSync()) f.uri.pathSegments.last,
  ]..sort();

  test('saves and loads the model', () async {
    await store.saveContent(7, 1, book);

    final loaded = await store.loadContent(7, 1);
    expect(loaded!.toJson(), book.toJson());
    expect(filesOf(7), ['content.v1.json.gz']);
  });

  test('no model for another parser version', () async {
    await store.saveContent(7, 1, book);

    expect(await store.loadContent(7, 2), isNull);
    expect(await store.loadContent(8, 1), isNull);
  });

  test('a new parser version replaces the old model', () async {
    await store.saveContent(7, 1, book);
    await store.saveContent(7, 2, book);

    expect(filesOf(7), ['content.v2.json.gz']);
    expect(await store.loadContent(7, 1), isNull);
    expect(await store.loadContent(7, 2), isNotNull);
  });

  test('copies the source with the format extension', () async {
    final from = File('${temp.path}/Книга.fb2.zip')..writeAsBytesSync([1, 2]);

    final saved = await store.saveSource(3, SourceFormat.fb2zip, from);

    expect(saved.path, store.sourceFile(3, SourceFormat.fb2zip).path);
    expect(saved.readAsBytesSync(), [1, 2]);
    expect(filesOf(3), ['source.fb2.zip']);
  });

  test('a failed copy leaves no files behind', () async {
    final missing = File('${temp.path}/missing.txt');

    await expectLater(
      store.saveSource(3, SourceFormat.txt, missing),
      throwsA(isA<FileSystemException>()),
    );
    expect(filesOf(3), isEmpty);
  });

  test('deletes the book folder', () async {
    await store.saveContent(7, 1, book);
    await store.deleteBook(7);
    await store.deleteBook(7); // already gone: no error

    expect(store.bookDir(7).existsSync(), isFalse);
  });
}
