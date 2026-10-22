import 'dart:convert';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

BookContent book(List<List<String>> sections) => BookContent(
  meta: const BookMeta(title: 't', sourceFormat: SourceFormat.txt),
  sections: [
    for (final s in sections)
      Section(blocks: [for (final p in s) ParagraphBlock(text: p)]),
  ],
);

void main() {
  group('reading position', () {
    final tokens = tokenize(
      book([
        ['Раз два три.', 'Четыре пять.'],
        ['Шесть семь.'],
      ]),
    );

    test('every word round-trips through its position', () {
      for (var i = 0; i < tokens.length; i++) {
        expect(tokens.resolve(tokens.positionOf(i)), i);
      }
    });

    test('anchor wins when the word index is stale', () {
      final p = tokens.positionOf(5); // «Шесть»
      final stale = ReadingPosition(wordIndex: 2, anchor: p.anchor);
      expect(tokens.resolve(stale), 5);
    });

    test('anchor survives an edited book (new parser)', () {
      final p = tokens.positionOf(4); // «пять.» in section 0, block 1
      final edited = tokenize(
        book([
          ['Раз, два, три и четыре.', 'Четыре пять.'],
          ['Шесть семь.'],
        ]),
      );
      expect(edited[edited.resolve(p)].text, 'пять.');
    });

    test('anchor points at the word, not at its glued dash', () {
      final v1 = tokenize(
        book([
          ['— Куда? — спросил он.'],
        ]),
      );
      final p = v1.positionOf(1); // «— спросил»
      expect(p.anchor.charOffset, '— Куда? — '.length);
      // Same text, but the dash now glued back: «— Куда? —», «спросил».
      final v2 = tokenize(
        book([
          ['— Куда?, — спросил он.'],
        ]),
      );
      expect(v2[v2.resolve(p)].text, contains('спросил'));
    });

    test('anchor inside or between words picks the next word', () {
      expect(
        tokens.indexAt(
          const TextAnchor(sectionIndex: 0, blockIndex: 0, charOffset: 5),
        ),
        1,
      );
      expect(
        tokens.indexAt(
          const TextAnchor(sectionIndex: 0, blockIndex: 0, charOffset: 3),
        ),
        1,
      );
      expect(
        tokens.indexAt(
          const TextAnchor(sectionIndex: 0, blockIndex: 7, charOffset: 0),
        ),
        5,
      );
      expect(
        tokens.indexAt(
          const TextAnchor(sectionIndex: 9, blockIndex: 0, charOffset: 0),
        ),
        tokens.length - 1,
      );
    });

    test('empty book', () {
      final empty = tokenize(book([]));
      expect(empty.isEmpty, isTrue);
      expect(empty.positionOf(10), ReadingPosition.start);
      expect(empty.resolve(ReadingPosition.start), 0);
    });
  });

  test('book content survives JSON', () {
    const content = BookContent(
      meta: BookMeta(
        title: 'Война и мир',
        authors: ['Лев Толстой'],
        series: 'Классика',
        seriesNumber: 1,
        lang: 'ru',
        coverAssetId: 'cover',
        sourceFormat: SourceFormat.fb2,
      ),
      toc: [TocEntry(title: 'Том 1', level: 0, sectionIndex: 0)],
      sections: [
        Section(
          title: 'Том 1',
          blocks: [
            HeadingBlock(text: 'Часть первая', level: 2),
            ParagraphBlock(
              text: 'Eh bien, mon prince.',
              style: ParagraphStyle.epigraph,
              spans: [
                Span(0, 7, SpanKind.emphasis),
                Span(8, 11, SpanKind.noteRef, noteId: 'n1'),
              ],
            ),
            SeparatorBlock(),
            ImageBlock(assetId: 'img1', width: 300, height: 200),
          ],
        ),
      ],
      notes: {
        'n1': Note(
          label: '1',
          blocks: [
            ParagraphBlock(
              text: 'См. 2',
              style: ParagraphStyle.note,
              spans: [Span(4, 5, SpanKind.noteRef, noteId: 'n2')],
            ),
          ],
        ),
        'n2': Note(blocks: [ParagraphBlock(text: 'Вложенная.')]),
      },
    );
    final json = jsonEncode(content.toJson());
    final decoded = BookContent.fromJson(
      jsonDecode(json) as Map<String, Object?>,
    );
    expect(jsonEncode(decoded.toJson()), json);
    expect(decoded.notes['n1']!.label, '1');
    expect(decoded.notes['n2']!.label, isNull);
  });

  test('a book without notes stores no notes key', () {
    const content = BookContent(
      meta: BookMeta(title: 't', sourceFormat: SourceFormat.txt),
      sections: [],
    );
    expect(content.toJson().containsKey('notes'), isFalse);
    expect(BookContent.fromJson(content.toJson()).notes, isEmpty);
  });
}
