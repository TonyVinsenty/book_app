import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/table_of_contents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const meta = BookMeta(title: 'Книга', sourceFormat: SourceFormat.epub);
  const sections = [
    Section(blocks: []),
    Section(title: 'Первая', blocks: []),
    Section(blocks: []),
  ];

  test('the book table of contents is used as is', () {
    final lines = contentsOf(
      const BookContent(
        meta: meta,
        toc: [
          TocEntry(title: 'Часть', level: 0, sectionIndex: 1),
          TocEntry(title: 'Глава', level: 1, sectionIndex: 1),
        ],
        sections: sections,
      ),
    );
    expect(lines, [
      (title: 'Часть', level: 0, sectionIndex: 1),
      (title: 'Глава', level: 1, sectionIndex: 1),
    ]);
  });

  test('without one, every chapter is a line, untitled ones too', () {
    final lines = contentsOf(const BookContent(meta: meta, sections: sections));
    expect(lines, [
      (title: null, level: 0, sectionIndex: 0),
      (title: 'Первая', level: 0, sectionIndex: 1),
      (title: null, level: 0, sectionIndex: 2),
    ]);
  });

  test('the current line starts at or before the chapter', () {
    List<ContentsLine> at(List<int> sections) => [
      for (final s in sections) (title: '$s', level: 0, sectionIndex: s),
    ];
    final lines = at([2, 2, 5, 9]);
    expect(currentLineOf(lines, 0), isNull, reason: 'before the first');
    expect(currentLineOf(lines, 2), 1, reason: 'the last of the same start');
    expect(currentLineOf(lines, 4), 1, reason: 'a chapter in several files');
    expect(currentLineOf(lines, 5), 2);
    expect(currentLineOf(lines, 20), 3);
    expect(currentLineOf(at([3, 1, 7]), 4), 0, reason: 'out of order');
    expect(currentLineOf(const [], 4), isNull);
  });
}
