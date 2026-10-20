import 'package:book_app/book/model/book_content.dart';

/// Chapters longer than this many characters are read in parts.
const longSectionChars = 100000;

/// About the size of a part (some 40 pages).
const sectionPartChars = 60000;

/// [content] with every chapter longer than [longSectionChars] split into
/// parts of about [sectionPartChars] at block boundaries (ROADMAP 8.9): the
/// reader lays out and keeps a whole section, and one of 500k words took
/// seconds and about 1 GB. The parts stay one chapter for the reader (see
/// [Section.continued]); positions are saved against the whole chapter.
BookContent splitLongSections(BookContent content) {
  if (!content.sections.any((s) => _charsOf(s) > longSectionChars)) {
    return content;
  }
  final sections = <Section>[];
  final firstPart = <int>[];
  for (final section in content.sections) {
    firstPart.add(sections.length);
    sections.addAll(_partsOf(section));
  }
  return BookContent(
    meta: content.meta,
    toc: [
      for (final e in content.toc)
        TocEntry(
          title: e.title,
          level: e.level,
          sectionIndex: e.sectionIndex >= 0 && e.sectionIndex < firstPart.length
              ? firstPart[e.sectionIndex]
              : e.sectionIndex,
        ),
    ],
    sections: sections,
  );
}

int _charsOf(Section section) => section.blocks.fold(
  0,
  (sum, b) => sum + (b is TextBlock ? b.text.length : 0),
);

List<Section> _partsOf(Section section) {
  final total = _charsOf(section);
  if (total <= longSectionChars) return [section];
  final count = (total / sectionPartChars).ceil();
  final size = total / count;
  final blocks = section.blocks;
  final parts = <Section>[];
  var start = 0;
  var chars = 0;
  for (var b = 0; b < blocks.length; b++) {
    // A heading stays with the text after it.
    if (chars >= size * (parts.length + 1) &&
        b > start &&
        blocks[b - 1] is! HeadingBlock) {
      parts.add(_part(section, start, b));
      start = b;
    }
    final block = blocks[b];
    if (block is TextBlock) chars += block.text.length;
  }
  parts.add(_part(section, start, blocks.length));
  return parts;
}

Section _part(Section section, int start, int end) => Section(
  title: start == 0 ? section.title : null,
  blocks: section.blocks.sublist(start, end),
  continued: start > 0,
  firstBlock: start,
);
