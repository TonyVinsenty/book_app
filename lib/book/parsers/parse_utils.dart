/// Small helpers shared by the FB2 and EPUB parsers.
library;

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
