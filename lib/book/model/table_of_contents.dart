import 'package:book_app/book/model/book_content.dart';

/// One line of the table of contents the reader sees; a `null` title is
/// shown as «Глава N» (N = [sectionIndex] + 1).
typedef ContentsLine = ({String? title, int level, int sectionIndex});

/// The book's own table of contents, or its chapters when it has none
/// (a TXT without headings, an EPUB without titles).
List<ContentsLine> contentsOf(BookContent content) => content.toc.isNotEmpty
    ? [
        for (final e in content.toc)
          (title: e.title, level: e.level, sectionIndex: e.sectionIndex),
      ]
    : [
        for (final (i, s) in content.sections.indexed)
          if (!s.continued) (title: s.title, level: 0, sectionIndex: i),
      ];

/// The line of the chapter being read: the last one that starts at or
/// before [section] (a chapter split into several files keeps its name),
/// or `null` before the first line. Lines out of book order are allowed.
int? currentLineOf(List<ContentsLine> lines, int section) {
  int? current;
  for (final (i, line) in lines.indexed) {
    if (line.sectionIndex <= section &&
        (current == null || line.sectionIndex >= lines[current].sectionIndex)) {
      current = i;
    }
  }
  return current;
}
