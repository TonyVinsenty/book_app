/// Small helpers shared by the FB2 and EPUB parsers.
library;

import 'package:book_app/book/model/book_content.dart';

/// A paragraph that is only a scene break: `* * *`, `———`, `# # #`.
final separatorPattern = RegExp(r'^[*\s]{3,}$|^[-–—\s]{3,}$|^[#\s]{3,}$');

/// Not `\s`: no-break spaces (`т.&nbsp;е.`) stay.
final whitespacePattern = RegExp(r'[ \t\r\n]+');

/// Whitespace runs as one space, no blank edges.
String cleanSpaces(String s) => s.replaceAll(whitespacePattern, ' ').trim();

final _lineEnd = RegExp(r'[.!?:;…]$');

/// Title lines joined for the contents: `Глава 1. Начало`.
String tocTitle(String heading) {
  final lines = heading.split('\n');
  final out = StringBuffer(lines.first);
  for (final line in lines.skip(1)) {
    out.write(_lineEnd.hasMatch(out.toString()) ? ' ' : '. ');
    out.write(line);
  }
  return out.toString();
}

/// [cover] becomes the first page of [sections], unless the text already
/// opens with it (before its first paragraph).
void putCoverFirst(List<Section> sections, ImageBlock cover) {
  if (sections.isEmpty) return;
  final first = sections.first;
  final opening = first.blocks.takeWhile((b) => b is! ParagraphBlock);
  if (opening.any((b) => b is ImageBlock && b.assetId == cover.assetId)) {
    return;
  }
  sections[0] = Section(title: first.title, blocks: [cover, ...first.blocks]);
}

/// [value] without its footnote labels.
String withoutMarks(String value, List<Span> spans) {
  final out = StringBuffer();
  var from = 0;
  for (final s in spans) {
    if (s.kind != SpanKind.noteRef || s.start < from) continue;
    out.write(value.substring(from, s.start));
    from = s.end;
  }
  out.write(value.substring(from));
  return out.toString();
}
