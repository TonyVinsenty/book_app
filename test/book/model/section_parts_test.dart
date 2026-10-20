import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:book_app/book/model/section_parts.dart';
import 'package:book_app/book/model/table_of_contents.dart';
import 'package:book_app/book/tokenizer/token.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A paragraph of about 1000 characters; [n] tells them apart.
  ParagraphBlock paragraph(int n) =>
      ParagraphBlock(text: List.filled(100, 'слово$n').join(' '));

  final huge = Section(
    title: 'Огромная',
    blocks: [
      const HeadingBlock(text: 'Огромная'),
      for (var i = 0; i < 300; i++) ...[
        paragraph(i),
        if (i == 120) const HeadingBlock(text: 'Подзаголовок'),
      ],
    ],
  );
  final book = BookContent(
    meta: const BookMeta(title: 'Книга', sourceFormat: SourceFormat.fb2),
    sections: [
      Section(blocks: [paragraph(1)]),
      huge,
      Section(blocks: [paragraph(2)]),
    ],
  );

  test('short chapters stay as they are', () {
    final short = BookContent(meta: book.meta, sections: [book.sections[0]]);
    expect(splitLongSections(short), same(short));
  });

  test('a long chapter is split into parts at block boundaries', () {
    final split = splitLongSections(book);
    final parts = split.sections.sublist(1, split.sections.length - 1);
    final chars = huge.blocks.fold(
      0,
      (sum, b) => sum + (b is TextBlock ? b.text.length : 0),
    );
    expect(chars, greaterThan(longSectionChars));
    expect(parts.length, closeTo((chars / sectionPartChars).ceil(), 1));
    expect(parts.first.title, 'Огромная');
    expect(parts.first.continued, isFalse);
    expect([for (final p in parts.skip(1)) p.continued], everyElement(isTrue));
    expect([for (final p in parts) ...p.blocks], huge.blocks, reason: 'all');
    var block = 0;
    for (final part in parts) {
      expect(part.firstBlock, block);
      expect(part.blocks.last, isNot(isA<HeadingBlock>()));
      block += part.blocks.length;
    }
    expect(split.sections.last.continued, isFalse);
  });

  test('the parts read as one chapter', () {
    final tokens = tokenize(book);
    final sections = tokens.content.sections;
    expect(sections.length, greaterThan(3));
    expect(tokens.length, greaterThan(0));
    // Chapter starts only where chapters start; numbers by chapter.
    final starts = [
      for (var w = 0; w < tokens.length; w++)
        if (tokens.flagsOf(w) & TokenFlags.sectionStart != 0) w,
    ];
    expect(starts, hasLength(3));
    expect(tokens.chapterNumberOf(sections.length - 1), 3);
    expect(tokens.chapterNumberOf(2), 2);
    final middle = tokens.firstWordOfSection(3) + 5;
    expect(tokens.firstWordOfChapter(tokens.sectionOf(middle)), starts[1]);
    // The contents list chapters, not parts.
    expect(
      [for (final l in contentsOf(tokens.content)) l.sectionIndex],
      [0, 1, sections.length - 1],
    );
    // Saved places do not depend on the parts.
    for (final w in [0, middle, tokens.length - 1]) {
      final position = tokens.positionOf(w);
      final token = tokens[w];
      expect(
        position.anchor.sectionIndex,
        [0, 1, 2][starts.lastIndexWhere((s) => s <= w)],
      );
      expect(
        position.anchor.blockIndex,
        sections[token.sectionIndex].firstBlock + token.blockIndex,
      );
      expect(tokens.resolve(position), w);
      final moved = ReadingPosition(wordIndex: -1, anchor: position.anchor);
      expect(tokens.resolve(moved), w, reason: 'by the anchor');
    }
  });

  test('the table of contents points at the first parts', () {
    final split = splitLongSections(
      BookContent(
        meta: book.meta,
        toc: const [
          TocEntry(title: 'Один', level: 0, sectionIndex: 0),
          TocEntry(title: 'Огромная', level: 0, sectionIndex: 1),
          TocEntry(title: 'Три', level: 0, sectionIndex: 2),
        ],
        sections: book.sections,
      ),
    );
    expect(
      [for (final e in split.toc) e.sectionIndex],
      [0, 1, split.sections.length - 1],
    );
  });
}
