/// Plain text books (ADR 0005): paragraphs by blank lines or indents, hard
/// line wraps (old lib.ru files, ~70 chars) glued back, chapters by heading
/// lines.
library;

import 'dart:typed_data';

import 'package:book_app/book/encoding/text_decoder.dart';
import 'package:book_app/book/model/book_content.dart';

/// Bump when the result for the same file changes (books get re-parsed).
const txtParserVersion = 1;

/// Throws [NotTextException] for binary files.
BookContent parseTxt(Uint8List bytes, {required String title}) =>
    parseTxtString(decodeText(bytes).text, title: title);

BookContent parseTxtString(String text, {required String title}) {
  final lines = text
      .replaceAll('﻿', '')
      .replaceAll('\u001A', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final sections = _sections(_paragraphs(lines));
  return BookContent(
    meta: BookMeta(
      title: title,
      lang: _guessLang(text),
      sourceFormat: SourceFormat.txt,
    ),
    toc: [
      for (var i = 0; i < sections.length; i++)
        for (final b in sections[i].blocks)
          if (b is HeadingBlock)
            TocEntry(title: b.text, level: b.level - 1, sectionIndex: i),
    ],
    sections: sections,
  );
}

final class _Paragraph {
  _Paragraph(this.text, {required this.lines});

  final String text;

  /// Number of source lines glued into it.
  final int lines;
}

List<_Paragraph> _paragraphs(List<String> lines) {
  final layout = _Layout.of(lines);
  final result = <_Paragraph>[];
  final current = StringBuffer();
  var count = 0;
  var previousLength = 0;
  var previousHyphen = false;
  var previousEndsSentence = false;

  void flush() {
    if (count > 0) {
      result.add(_Paragraph(current.toString(), lines: count));
    }
    current.clear();
    count = 0;
  }

  for (final raw in lines) {
    final line = _collapseSpaces(raw.trim());
    if (line.isEmpty) {
      flush();
      continue;
    }
    final glueable =
        count > 0 && layout.hardWrapped && _indent(raw) <= layout.baseIndent;
    // `какой-` + `нибудь`: a word cut at its hyphen by the wrap; lib.ru
    // tools wrap at hyphens, so the hyphen stays.
    final hyphenated =
        glueable && previousHyphen && _lowercase.hasMatch(line[0]);
    // A dash after a wrap is an inline dash unless a sentence just ended.
    final continues =
        hyphenated ||
        (glueable &&
            previousLength >= layout.fullLine &&
            !(_startsWithDash(line) && previousEndsSentence) &&
            !_looksLikeHeadingStart(line));
    if (!continues) {
      flush();
    } else if (!hyphenated) {
      current.write(' ');
    }
    current.write(line);
    count++;
    previousLength = raw.trimRight().length;
    previousHyphen =
        line.length > 1 &&
        line.endsWith('-') &&
        _letter.hasMatch(line[line.length - 2]);
    previousEndsSentence = _sentenceEnd.hasMatch(line);
  }
  flush();
  return result;
}

/// How the file is laid out, from statistics of non-empty lines.
final class _Layout {
  const _Layout({
    required this.hardWrapped,
    required this.fullLine,
    required this.baseIndent,
  });

  factory _Layout.of(List<String> lines) {
    final lengths = <int>[];
    final indents = <int, int>{};
    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.trim().isEmpty) continue;
      lengths.add(trimmed.length);
      final indent = _indent(line);
      indents[indent] = (indents[indent] ?? 0) + 1;
    }
    if (lengths.isEmpty) {
      return const _Layout(hardWrapped: false, fullLine: 0, baseIndent: 0);
    }
    lengths.sort();
    final wrap =
        lengths[(lengths.length * 0.9).floor().clamp(0, lengths.length - 1)];
    final fullLine = (wrap * 0.75).floor();
    final full = lengths.where((l) => l >= fullLine).length;
    // Continuation lines have the smallest indent that is not a rare
    // accident (dialog-heavy books have more indented first lines).
    final sortedIndents = indents.keys.toList()..sort();
    final baseIndent = sortedIndents.firstWhere(
      (i) => indents[i]! >= lengths.length * 0.05,
      orElse: () => sortedIndents.first,
    );
    return _Layout(
      // Lines cut at a fixed width: most are nearly full and short overall.
      hardWrapped:
          lengths.length >= 4 &&
          wrap >= 40 &&
          wrap <= 100 &&
          full >= lengths.length * 0.5,
      fullLine: fullLine,
      baseIndent: baseIndent,
    );
  }

  final bool hardWrapped;

  /// A line at least this long was cut by the wrap, not by the author.
  final int fullLine;

  /// The indent of continuation lines; a bigger one starts a paragraph.
  final int baseIndent;
}

int _indent(String line) {
  var n = 0;
  for (var i = 0; i < line.length; i++) {
    final c = line.codeUnitAt(i);
    if (c == 0x20 || c == 0xA0) {
      n++;
    } else if (c == 0x09) {
      n += 4;
    } else {
      break;
    }
  }
  return n;
}

final _spaces = RegExp(r'[ \t]{2,}');
final _sentenceEnd = RegExp(r'[.!?…]["»”)]*$');

String _collapseSpaces(String s) => s.replaceAll(_spaces, ' ');

bool _looksLikeHeadingStart(String line) => _keywordKind(line) != null;

bool _startsWithDash(String line) {
  final c = line.codeUnitAt(0);
  return c == 0x2014 || c == 0x2013 || c == 0x2D;
}

// --- chapters --------------------------------------------------------------

enum _HeadingKind { part, chapter }

/// After `Глава`: end of line, a number, a roman numeral or an ordinal word
/// (`Глава 5`, `ГЛАВА ПЕРВАЯ`, `Часть II. Название`), not `Том вошёл`.
const _numbering =
    r'(?:[.:]?$|\s+(?:\d+|[IVXLC]+|'
    r'(?:перв|втор|трет|четв[её]рт|пят|шест|седьм|восьм|девят|десят|'
    r'одиннадцат|двенадцат|\S+надцат|двадцат|тридцат|сороков|последн)\S*|'
    r'one|two|three|four|five|six|seven|eight|nine|ten|first|second|third|'
    r'\S+th|last)(?=$|[\s.:,]))';
final _partWords = RegExp(
  '^(?:часть|том|книга|part|book|volume)$_numbering',
  caseSensitive: false,
  unicode: true,
);
final _chapterWords = RegExp(
  '^(?:глава|chapter)$_numbering',
  caseSensitive: false,
  unicode: true,
);

/// Headings that stand alone: `Пролог`, `Эпилог.`
final _soloWords = RegExp(
  r'^(?:пролог|эпилог|предисловие|послесловие|вступление|заключение|'
  r'prologue|epilogue|preface|introduction|afterword)[.:]?$',
  caseSensitive: false,
  unicode: true,
);
final _romanLine = RegExp(r'^[IVXLC]{1,7}\.?$');
final _separatorLine = RegExp(r'^[*\s]{3,}$|^[-–—\s]{3,}$|^[#\s]{3,}$');
final _letter = RegExp(r'\p{L}', unicode: true);
final _lowercase = RegExp(r'\p{Ll}', unicode: true);
final _capsTitleEnd = RegExp(r'[,;!?]$');

_HeadingKind? _keywordKind(String t) {
  if (t.isEmpty || _lowercase.hasMatch(t[0])) return null;
  if (_partWords.hasMatch(t)) return _HeadingKind.part;
  if (_chapterWords.hasMatch(t) ||
      _soloWords.hasMatch(t) ||
      _romanLine.hasMatch(t)) {
    return _HeadingKind.chapter;
  }
  return null;
}

_HeadingKind? _headingKind(_Paragraph p, {required bool capsAllowed}) {
  final t = p.text;
  if (p.lines > 1 || t.length > 80) return null;
  if (_keywordKind(t) case final kind?) return kind;
  if (capsAllowed && _isCapsTitle(t)) return _HeadingKind.chapter;
  return null;
}

/// `ВОЙНА И МИР`, but not `— СТОЙ!` or a shouted sentence.
bool _isCapsTitle(String t) =>
    t.length <= 60 &&
    t.split(' ').length <= 8 &&
    _letter.allMatches(t).length >= 3 &&
    !_lowercase.hasMatch(t) &&
    !_startsWithDash(t) &&
    !_capsTitleEnd.hasMatch(t);

List<Section> _sections(List<_Paragraph> paragraphs) {
  // Too many caps lines means caps are the author's style, not headings.
  final caps = paragraphs
      .where((p) => p.lines == 1 && _isCapsTitle(p.text))
      .length;
  final capsAllowed = caps <= 3 || caps <= paragraphs.length * 0.2;
  final kinds = [
    for (final p in paragraphs) _headingKind(p, capsAllowed: capsAllowed),
  ];
  // Three or more headings in a row are a contents list, not chapters.
  for (var i = 0; i < kinds.length;) {
    var j = i;
    while (j < kinds.length && kinds[j] != null) {
      j++;
    }
    if (j - i >= 3) {
      // The real first chapter right after the list repeats its first line.
      final keepLast = paragraphs[j - 1].text == paragraphs[i].text;
      kinds.fillRange(i, keepLast ? j - 1 : j, null);
    }
    i = j == i ? i + 1 : j;
  }
  final hasParts = kinds.contains(_HeadingKind.part);

  final sections = <Section>[];
  var blocks = <Block>[];
  String? title;
  _HeadingKind? previousHeading;

  void close() {
    if (blocks.isNotEmpty) sections.add(Section(title: title, blocks: blocks));
    blocks = <Block>[];
    title = null;
  }

  for (var i = 0; i < paragraphs.length; i++) {
    final p = paragraphs[i];
    final kind = kinds[i];
    if (kind != null) {
      // `ЧАСТЬ I` + `Глава 1` share one section.
      if (!(previousHeading == _HeadingKind.part &&
          kind == _HeadingKind.chapter)) {
        close();
      }
      title ??= p.text;
      blocks.add(
        HeadingBlock(
          text: p.text,
          level: kind == _HeadingKind.chapter && hasParts ? 2 : 1,
        ),
      );
    } else if (_separatorLine.hasMatch(p.text)) {
      blocks.add(const SeparatorBlock());
    } else {
      blocks.add(ParagraphBlock(text: p.text));
    }
    previousHeading = kind;
  }
  close();
  return sections;
}

/// `ru` or `en` by the letters at the start of the text.
String? _guessLang(String text) {
  final sample = text.length > 20000 ? text.substring(0, 20000) : text;
  var cyrillic = 0;
  var latin = 0;
  for (var i = 0; i < sample.length; i++) {
    final c = sample.codeUnitAt(i);
    if (c >= 0x0400 && c <= 0x04FF) {
      cyrillic++;
    } else if ((c | 0x20) >= 0x61 && (c | 0x20) <= 0x7A) {
      latin++;
    }
  }
  if (cyrillic + latin < 20) return null;
  return cyrillic >= latin ? 'ru' : 'en';
}
