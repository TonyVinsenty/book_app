import 'dart:math' as math;

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:flutter/painting.dart';

/// Lines `[firstLine, endLine)` of one block placed on a page at [top].
final class PageSlice {
  const PageSlice({
    required this.blockIndex,
    required this.firstLine,
    required this.endLine,
    required this.top,
    required this.charStart,
    required this.charEnd,
  });

  final int blockIndex;
  final int firstLine;
  final int endLine;

  /// Distance from the top of the page.
  final double top;

  /// Text of the block shown here: `text[charStart, charEnd)`.
  final int charStart;
  final int charEnd;
}

/// One page of a chapter. Its words are `[firstWord, endWord)` (book word
/// indices); a page of only pictures or separators has none.
final class ChapterPage {
  const ChapterPage(this.slices, this.firstWord, this.endWord);

  final List<PageSlice> slices;
  final int firstWord;
  final int endWord;

  bool get hasWords => endWord > firstWord;
}

/// A chapter split into pages of [pageSize] (ADR 0003): every block is laid
/// out whole by a [TextPainter], pages take whole lines, and a page paints
/// the same painters shifted and clipped, so line breaks match exactly.
final class ChapterLayout {
  ChapterLayout._(
    this.sectionIndex,
    this.pageSize,
    this.style,
    this._section,
    this._blocks,
    this.pages,
  );

  /// Lays out section [sectionIndex] of [tokens]' book. Must run on the main
  /// isolate (text layout).
  factory ChapterLayout.build({
    required BookTokens tokens,
    required int sectionIndex,
    required PageStyle style,
    required Size pageSize,
  }) {
    final section = tokens.content.sections[sectionIndex];
    final blocks = [
      for (final block in section.blocks)
        _BlockLayout.of(block, style, pageSize.width),
    ];
    final pages = _paginate(tokens, sectionIndex, blocks, pageSize.height);
    return ChapterLayout._(
      sectionIndex,
      pageSize,
      style,
      section,
      blocks,
      pages,
    );
  }

  final int sectionIndex;
  final Size pageSize;
  final PageStyle style;
  final Section _section;
  final List<_BlockLayout?> _blocks;

  /// Empty when the chapter shows nothing (no text, no separators).
  final List<ChapterPage> pages;

  /// The page showing [wordIndex]: the last page starting at or before it
  /// (0 for words before the chapter, the last page for words after it).
  int pageOfWord(int wordIndex) {
    var lo = 0;
    var hi = pages.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (pages[mid].firstWord <= wordIndex) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Text of page [index], for screen readers.
  String pageText(int index) => [
    for (final slice in pages[index].slices)
      switch (_section.blocks[slice.blockIndex]) {
        TextBlock(:final text) => text.substring(
          slice.charStart,
          slice.charEnd,
        ),
        _ => _separatorText,
      },
  ].join('\n');

  void paintPage(Canvas canvas, int index) {
    for (final slice in pages[index].slices) {
      final block = _blocks[slice.blockIndex]!;
      final top = block.tops[slice.firstLine];
      final height = block.tops[slice.endLine] - top;
      canvas
        ..save()
        ..clipRect(Rect.fromLTWH(0, slice.top, pageSize.width, height));
      block.painter.paint(canvas, Offset(block.dx, slice.top - top));
      canvas.restore();
    }
  }

  void dispose() {
    for (final block in _blocks) {
      block?.painter.dispose();
    }
  }

  static List<ChapterPage> _paginate(
    BookTokens tokens,
    int sectionIndex,
    List<_BlockLayout?> blocks,
    double pageHeight,
  ) {
    final slicesOfPages = <List<PageSlice>>[];
    var slices = <PageSlice>[];
    var y = 0.0;
    var spaceAfterPrevious = 0.0;

    void newPage() {
      if (slices.isEmpty) return;
      slicesOfPages.add(slices);
      slices = [];
      y = 0;
    }

    for (final (b, block) in blocks.indexed) {
      if (block == null) continue;
      var gap = slices.isEmpty
          ? 0.0
          : math.max(spaceAfterPrevious, block.spaceBefore);
      // A heading or separator moves to the next page whole; a heading also
      // takes at least one following line with it.
      if (block.keepTogether && slices.isNotEmpty) {
        final needed = block.height + block.keepWithNext;
        if (needed <= pageHeight && y + gap + needed > pageHeight) {
          newPage();
          gap = 0;
        }
      }
      y += gap;
      var line = 0;
      while (line < block.lineCount) {
        final start = line;
        final top = y;
        // At least one line per page, even if it is taller than the page.
        while (line < block.lineCount &&
            (y + block.lineHeight(line) <= pageHeight ||
                (slices.isEmpty && line == start))) {
          y += block.lineHeight(line);
          line++;
        }
        if (line > start) {
          slices.add(
            PageSlice(
              blockIndex: b,
              firstLine: start,
              endLine: line,
              top: top,
              charStart: block.lineStarts[start],
              charEnd: block.lineStarts[line],
            ),
          );
        }
        if (line < block.lineCount) newPage();
      }
      spaceAfterPrevious = block.spaceAfter;
    }
    newPage();

    // A page's words start at its first text; pages without text share the
    // next page's start and so have no words.
    final chapterEnd = tokens.firstWordOfSection(sectionIndex + 1);
    final firstWords = List.filled(slicesOfPages.length, chapterEnd);
    var next = chapterEnd;
    for (var p = slicesOfPages.length - 1; p >= 0; p--) {
      for (final slice in slicesOfPages[p]) {
        if (!blocks[slice.blockIndex]!.isText) continue;
        next = math.min(
          next,
          _wordAtOrAfter(
            tokens,
            sectionIndex,
            slice.blockIndex,
            slice.charStart,
          ),
        );
        break;
      }
      firstWords[p] = next;
    }
    if (firstWords.isNotEmpty) {
      firstWords[0] = tokens.firstWordOfSection(sectionIndex);
    }
    return [
      for (var p = 0; p < slicesOfPages.length; p++)
        ChapterPage(
          slicesOfPages[p],
          firstWords[p],
          p + 1 < firstWords.length ? firstWords[p + 1] : chapterEnd,
        ),
    ];
  }

  /// The first word that starts at or after the place.
  static int _wordAtOrAfter(
    BookTokens tokens,
    int section,
    int block,
    int char,
  ) {
    if (tokens.isEmpty) return 0;
    final i = tokens.indexAt(
      TextAnchor(sectionIndex: section, blockIndex: block, charOffset: char),
    );
    final t = tokens[i];
    final startsBefore = t.sectionIndex != section
        ? t.sectionIndex < section
        : t.blockIndex != block
        ? t.blockIndex < block
        : t.charStart < char;
    return startsBefore ? i + 1 : i;
  }
}

const _separatorText = '* * *';

/// First-line indent of a normal paragraph: one em.
const _indent = ' ';

/// A block laid out at the page width, with its line boundaries.
final class _BlockLayout {
  _BlockLayout(
    this.painter, {
    required this.prefix,
    required this.textLength,
    required this.dx,
    required this.isText,
    this.spaceBefore = 0,
    this.spaceAfter = 0,
    this.keepTogether = false,
    this.keepWithNext = 0,
  }) {
    final metrics = painter.computeLineMetrics();
    final n = metrics.length;
    tops = List.filled(n + 1, 0)..[n] = painter.height;
    lineStarts = List.filled(n + 1, 0)..[n] = textLength;
    for (var i = 1; i < n; i++) {
      // Halfway between the line above and this one, whatever the leading.
      final above = metrics[i - 1].baseline + metrics[i - 1].descent;
      final top = metrics[i].baseline - metrics[i].ascent;
      tops[i] = (above + top) / 2;
      final middle = (tops[i] + metrics[i].baseline) / 2;
      // Left of the text, so it hits the line start in any alignment.
      final offset = painter.getPositionForOffset(Offset(-1, middle)).offset;
      lineStarts[i] = (offset - prefix).clamp(lineStarts[i - 1], textLength);
    }
  }

  /// Null for blocks not shown yet (pictures come in a later stage).
  static _BlockLayout? of(Block block, PageStyle style, double width) {
    final em = style.textScaler.scale(style.fontSize);
    final line = style.bodyLine;
    switch (block) {
      case HeadingBlock():
        return _text(
          block,
          style.heading(block.level),
          width,
          align: TextAlign.center,
          spaceBefore: line * 1.5,
          spaceAfter: line,
          keepTogether: true,
          keepWithNext: line,
          style: style,
        );
      case ParagraphBlock(style: final kind):
        final inset = switch (kind) {
          ParagraphStyle.epigraph => width * 0.3,
          ParagraphStyle.poem => em * 2,
          ParagraphStyle.quote => em * 1.5,
          _ => 0.0,
        };
        final spaced = kind != ParagraphStyle.normal && kind != ParagraphStyle.note;
        return _text(
          block,
          style.paragraph(kind),
          width,
          inset: inset,
          align: kind == ParagraphStyle.subtitle
              ? TextAlign.center
              : TextAlign.left,
          indent: kind == ParagraphStyle.normal ? _indent : '',
          strut: kind == ParagraphStyle.normal ? style.bodyStrut : null,
          spaceBefore: spaced ? line / 2 : 0,
          spaceAfter: spaced ? line / 2 : 0,
          style: style,
        );
      case SeparatorBlock():
        final painter = TextPainter(
          text: TextSpan(text: _separatorText, style: style.body),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          textScaler: style.textScaler,
        )..layout(minWidth: width, maxWidth: width);
        return _BlockLayout(
          painter,
          prefix: 0,
          textLength: 0,
          dx: 0,
          isText: false,
          spaceBefore: line / 2,
          spaceAfter: line / 2,
          keepTogether: true,
        );
      case ImageBlock():
        return null;
    }
  }

  static _BlockLayout _text(
    TextBlock block,
    TextStyle textStyle,
    double width, {
    required PageStyle style,
    double inset = 0,
    TextAlign align = TextAlign.left,
    String indent = '',
    StrutStyle? strut,
    double spaceBefore = 0,
    double spaceAfter = 0,
    bool keepTogether = false,
    double keepWithNext = 0,
  }) {
    final lineWidth = math.max(width - inset, 1.0);
    final painter = TextPainter(
      text: _span(block, textStyle, indent),
      textAlign: align,
      textDirection: TextDirection.ltr,
      textScaler: style.textScaler,
      strutStyle: strut,
    )..layout(minWidth: lineWidth, maxWidth: lineWidth);
    return _BlockLayout(
      painter,
      prefix: indent.length,
      textLength: block.text.length,
      dx: inset,
      isText: true,
      spaceBefore: spaceBefore,
      spaceAfter: spaceAfter,
      keepTogether: keepTogether,
      keepWithNext: keepWithNext,
    );
  }

  /// The block text after [prefix], italic and bold where its spans say.
  static TextSpan _span(TextBlock block, TextStyle style, String prefix) {
    final text = block.text;
    final marks = [
      for (final s in block.spans)
        if (s.kind != SpanKind.noteRef)
          (
            math.min(s.start, text.length),
            math.min(s.end, text.length),
            s.kind,
          ),
    ];
    if (marks.isEmpty) return TextSpan(text: '$prefix$text', style: style);
    final cuts = {
      0,
      text.length,
      for (final m in marks) ...[m.$1, m.$2],
    }.toList()..sort();
    return TextSpan(
      style: style,
      children: [
        if (prefix.isNotEmpty) TextSpan(text: prefix),
        for (var i = 0; i + 1 < cuts.length; i++)
          if (cuts[i] < cuts[i + 1])
            _segment(text, cuts[i], cuts[i + 1], marks),
      ],
    );
  }

  static TextSpan _segment(
    String text,
    int start,
    int end,
    List<(int, int, SpanKind)> marks,
  ) {
    bool marked(SpanKind kind) =>
        marks.any((m) => m.$3 == kind && m.$1 <= start && end <= m.$2);
    final italic = marked(SpanKind.emphasis);
    final bold = marked(SpanKind.strong);
    return TextSpan(
      text: text.substring(start, end),
      style: italic || bold
          ? TextStyle(
              fontStyle: italic ? FontStyle.italic : null,
              fontWeight: bold ? FontWeight.w700 : null,
            )
          : null,
    );
  }

  final TextPainter painter;

  /// Characters added before the block text (the first-line indent).
  final int prefix;
  final int textLength;

  /// Left inset inside the page.
  final double dx;

  /// Holds words (headings and paragraphs).
  final bool isText;
  final double spaceBefore;
  final double spaceAfter;
  final bool keepTogether;

  /// Room needed below the block on the same page.
  final double keepWithNext;

  /// Line `i` spans `[tops[i], tops[i + 1])`; the last entry is the height.
  late final List<double> tops;

  /// Line `i` shows `text[lineStarts[i], lineStarts[i + 1])`.
  late final List<int> lineStarts;

  int get lineCount => tops.length - 1;
  double get height => tops.last;
  double lineHeight(int line) => tops[line + 1] - tops[line];
}
