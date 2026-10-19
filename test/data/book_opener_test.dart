import 'dart:io';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_opener.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stored model whose text differs from the source file.
const _stored = BookContent(
  meta: BookMeta(title: 'Книга', sourceFormat: SourceFormat.txt),
  sections: [
    Section(blocks: [ParagraphBlock(text: 'Старый разбор.')]),
  ],
);

void main() {
  late Directory temp;
  late AppDatabase db;
  late BookRepository repo;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('book_opener_');
    db = AppDatabase(NativeDatabase.memory());
    repo = BookRepository(db, ContentStore(Directory('${temp.path}/books')));
  });

  tearDown(() async {
    await db.close();
    temp.deleteSync(recursive: true);
  });

  Future<int> add({required int parserVersion}) async {
    final source = File('${temp.path}/Книга.txt')
      ..writeAsStringSync('Новый разбор файла.');
    final row = await repo.addBook(
      content: _stored,
      source: source,
      sourceName: 'Книга.txt',
      sourceHash: 'hash',
      parserVersion: parserVersion,
      wordCount: tokenize(_stored).length,
    );
    return row.id;
  }

  String firstText(OpenedBook book) =>
      (book.tokens.content.sections.first.blocks.first as TextBlock).text;

  test('the stored model is used while the parser is the same', () async {
    final id = await add(parserVersion: txtParserVersion);

    final opened = await BookOpener(repo).open(id);

    expect(firstText(opened), 'Старый разбор.');
  });

  test('a model from an older parser is parsed again and stored', () async {
    final id = await add(parserVersion: txtParserVersion - 1);

    final opened = await BookOpener(repo).open(id);

    expect(firstText(opened), 'Новый разбор файла.');
    final row = (await repo.findById(id))!;
    expect(row.parserVersion, parserVersionOf(SourceFormat.txt));
    expect(row.wordCount, 3);
    expect(firstText(await BookOpener(repo).open(id)), 'Новый разбор файла.');
  });

  test('a position from an older tokenizer moves by its anchor', () async {
    const text = 'Вот полуавтоматы-получеловеки идут домой.';
    const content = BookContent(
      meta: BookMeta(title: 'Книга', sourceFormat: SourceFormat.txt),
      sections: [
        Section(blocks: [ParagraphBlock(text: text)]),
      ],
    );
    final source = File('${temp.path}/Книга.txt')..writeAsStringSync(text);
    final row = await repo.addBook(
      content: content,
      source: source,
      sourceName: 'Книга.txt',
      sourceHash: 'hash',
      parserVersion: txtParserVersion,
      wordCount: 4, // counted by tokenizer 1: the long word was one
    );
    // «идут» was word 2 for tokenizer 1.
    await repo.savePosition(
      row.id,
      ReadingPosition(
        wordIndex: 2,
        anchor: TextAnchor(
          sectionIndex: 0,
          blockIndex: 0,
          charOffset: text.indexOf('идут'),
        ),
      ),
    );

    final opened = await BookOpener(repo).open(row.id);

    expect(opened.tokens.textOf(opened.wordIndex), 'идут');
    expect(opened.wordIndex, 3);
    final stored = (await repo.findById(row.id))!;
    expect(stored.wordCount, 5);
    expect(stored.positionWord, 3);
  });
}
