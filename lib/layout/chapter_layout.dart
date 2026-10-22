import 'dart:math' as math;

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/layout/hyphenation.dart';
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
    this._tokens,
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
    final metrics = [for (final block in blocks) block?.metrics];
    final pages = _withWords(
      tokens,
      sectionIndex,
      metrics,
      _split(metrics, pageSize.height, _chapterStart, (blocks.length, 0)),
    );
    return ChapterLayout._(
      sectionIndex,
      pageSize,
      style,
      section,
      blocks,
      pages,
      tokens,
    );
  }

  final int sectionIndex;
  final Size pageSize;
  final PageStyle style;
  final Section _section;
  final List<_BlockLayout?> _blocks;
  final BookTokens _tokens;

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

  /// The word on page [index] under [point] (page coordinates), or null if
  /// no word is within about a letter of it (ADR 0003 п. 3).
  int? wordAt(int index, Offset point) {
    final page = pages[index];
    for (final slice in page.slices) {
      final layout = _blocks[slice.blockIndex]!;
      final block = layout.metrics;
      final top = block.tops[slice.firstLine];
      final bottom = slice.top + block.tops[slice.endLine] - top;
      if (!block.isText || point.dy < slice.top || point.dy >= bottom) {
        continue;
      }
      final shift = Offset(block.dx, slice.top - top);
      final local = point - shift;
      var line = slice.firstLine;
      while (line + 1 < slice.endLine && block.tops[line + 1] <= local.dy) {
        line++;
      }
      final caret = layout.painter.getPositionForOffset(local).offset;
      final char = layout.hyphens
          .toText(caret - block.prefix)
          .clamp(0, block.textLength);
      // The caret is between letters: the word holding it or the one ending
      // right before it; take the nearer one on the touched line.
      final next = _tokens.indexAt(
        TextAnchor(
          sectionIndex: sectionIndex,
          blockIndex: slice.blockIndex,
          charOffset: char,
        ),
      );
      int? best;
      var bestDistance = double.infinity;
      for (final word in [next - 1, next]) {
        if (word < page.firstWord ||
            word >= page.endWord ||
            _tokens[word].blockIndex != slice.blockIndex) {
          continue;
        }
        for (final box in _boxesOf(layout, word)) {
          final middle = box.center.dy;
          if (middle < block.tops[line] || middle >= block.tops[line + 1]) {
            continue;
          }
          final distance = local.dx < box.left
              ? box.left - local.dx
              : math.max(0.0, local.dx - box.right);
          if (distance < bestDistance) {
            best = word;
            bestDistance = distance;
          }
        }
      }
      final tolerance = style.textScaler.scale(style.fontSize);
      return bestDistance <= tolerance ? best : null;
    }
    return null;
  }

  /// Rectangles of [wordIndex] on page [index] (page coordinates), one per
  /// line it takes; empty if the word is not on that page.
  List<Rect> wordBoxes(int index, int wordIndex) {
    if (wordIndex < 0 || wordIndex >= _tokens.length) return const [];
    final token = _tokens[wordIndex];
    if (token.sectionIndex != sectionIndex) return const [];
    final boxes = <Rect>[];
    for (final slice in pages[index].slices) {
      if (slice.blockIndex != token.blockIndex) continue;
      final layout = _blocks[slice.blockIndex]!;
      final block = layout.metrics;
      final top = block.tops[slice.firstLine];
      final bottom = block.tops[slice.endLine];
      for (final box in _boxesOf(layout, wordIndex)) {
        final middle = box.center.dy;
        if (middle < top || middle >= bottom) continue;
        boxes.add(box.shift(Offset(block.dx, slice.top - top)));
      }
    }
    return boxes;
  }

  /// Boxes of a word in its block painter's coordinates.
  Iterable<Rect> _boxesOf(_BlockLayout layout, int wordIndex) {
    final token = _tokens[wordIndex];
    final prefix = layout.metrics.prefix;
    return layout.painter
        .getBoxesForSelection(
          TextSelection(
            baseOffset: layout.hyphens.toPainter(token.charStart) + prefix,
            extentOffset: layout.hyphens.toPainter(token.charEnd) + prefix,
          ),
        )
        .map((box) => box.toRect());
  }

  void paintPage(Canvas canvas, int index) {
    for (final slice in pages[index].slices) {
      final layout = _blocks[slice.blockIndex]!;
      final block = layout.metrics;
      final top = block.tops[slice.firstLine];
      final height = block.tops[slice.endLine] - top;
      final shift = Offset(block.dx, slice.top - top);
      // Only lines of other pages are cut off: hyphens hang in the margin.
      canvas
        ..save()
        ..clipRect(
          Rect.fromLTRB(
            -pageSize.width,
            slice.top,
            pageSize.width * 2,
            slice.top + height,
          ),
        );
      layout.painter.paint(canvas, shift);
      layout.paintHyphens(canvas, shift, slice.firstLine, slice.endLine);
      canvas.restore();
    }
  }

  void dispose() {
    for (final block in _blocks) {
      block?.dispose();
    }
  }

  /// Pages of lines from [from] up to [to] (not included), filled from the
  /// top as far as they go.
  static List<List<PageSlice>> _split(
    List<_BlockMetrics?> blocks,
    double pageHeight,
    _Line from,
    _Line to,
  ) {
    final splitter = _Splitter(pageHeight);
    final (fromBlock, fromLine) = from;
    final (toBlock, toLine) = to;
    for (var b = fromBlock; b < blocks.length && b <= toBlock; b++) {
      final block = blocks[b];
      if (block == null) continue;
      final firstLine = b == fromBlock ? fromLine : 0;
      final endLine = b == toBlock ? toLine : block.lineCount;
      // The lines of the last block from [toLine] on are not in the range.
      if (b == toBlock && firstLine >= endLine) continue;
      splitter.add(b, block, firstLine, endLine);
    }
    return splitter.finish();
  }

  /// Pages of the whole chapter with their word ranges.
  static List<ChapterPage> _withWords(
    BookTokens tokens,
    int sectionIndex,
    List<_BlockMetrics?> blocks,
    List<List<PageSlice>> slicesOfPages,
  ) {
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

/// Splits a chapter into pages a few blocks at a time (ADR 0003, addendum 2
/// п. 5): a block's text painter is freed as soon as its line metrics are
/// taken, and the pages are those [ChapterLayout.build] gives. Main isolate
/// only (text layout).
final class ChapterPaginator {
  ChapterPaginator({
    required this._tokens,
    required this.sectionIndex,
    required this._style,
    required Size pageSize,
  }) : _width = pageSize.width,
       _source = _tokens.content.sections[sectionIndex].blocks,
       _splitter = _Splitter(pageSize.height);

  final int sectionIndex;
  final BookTokens _tokens;
  final PageStyle _style;
  final double _width;
  final List<Block> _source;
  final _Splitter _splitter;
  final _metrics = <_BlockMetrics?>[];
  List<int>? _firstWords;

  bool get isDone => _firstWords != null;

  /// First words (book word indices) of the chapter's pages, once [isDone];
  /// empty if the chapter shows nothing.
  List<int> get pageFirstWords =>
      _firstWords ?? (throw StateError('The chapter is not split yet'));

  /// Lays out blocks until [budget] is spent (at least one block), and
  /// finishes the split after the last one. Returns [isDone].
  bool step([Duration budget = const Duration(milliseconds: 6)]) {
    final watch = Stopwatch()..start();
    while (_metrics.length < _source.length) {
      final b = _metrics.length;
      final layout = _BlockLayout.of(_source[b], _style, _width);
      layout?.dispose();
      final block = layout?.metrics;
      _metrics.add(block);
      if (block != null) _splitter.add(b, block, 0, block.lineCount);
      if (watch.elapsed >= budget) break;
    }
    if (!isDone && _metrics.length == _source.length) {
      final pages = ChapterLayout._withWords(
        _tokens,
        sectionIndex,
        _metrics,
        _splitter.finish(),
      );
      _firstWords = [for (final page in pages) page.firstWord];
    }
    return isDone;
  }
}

/// Fills pages from the top with block lines given in reading order.
final class _Splitter {
  _Splitter(this.pageHeight);

  final double pageHeight;
  final _pages = <List<PageSlice>>[];
  var _slices = <PageSlice>[];
  var _y = 0.0;
  var _spaceAfterPrevious = 0.0;

  void _newPage() {
    if (_slices.isEmpty) return;
    _pages.add(_slices);
    _slices = [];
    _y = 0;
  }

  /// Adds lines `[firstLine, endLine)` of block [b].
  void add(int b, _BlockMetrics block, int firstLine, int endLine) {
    var gap = _slices.isEmpty
        ? 0.0
        : math.max(_spaceAfterPrevious, block.spaceBefore);
    // A heading or separator moves to the next page whole; a heading also
    // takes at least one following line with it.
    if (block.keepTogether && _slices.isNotEmpty) {
      final needed = block.height + block.keepWithNext;
      if (needed <= pageHeight && _y + gap + needed > pageHeight) {
        _newPage();
        gap = 0;
      }
    }
    _y += gap;
    var line = firstLine;
    while (line < endLine) {
      final start = line;
      final top = _y;
      // At least one line per page, even if it is taller than the page.
      while (line < endLine &&
          (_y + block.lineHeight(line) <= pageHeight ||
              (_slices.isEmpty && line == start))) {
        _y += block.lineHeight(line);
        line++;
      }
      if (line > start) {
        _slices.add(
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
      if (line < endLine) _newPage();
    }
    _spaceAfterPrevious = block.spaceAfter;
  }

  /// All pages, the last one closed.
  List<List<PageSlice>> finish() {
    _newPage();
    return _pages;
  }
}

const _separatorText = '* * *';

/// A line of a chapter: (block index, line in the block).
typedef _Line = (int, int);

const _Line _chapterStart = (0, 0);

/// First-line indent of a normal paragraph: about one em. Figure spaces:
/// justified lines drop a leading em space, but keep these non-breaking
/// ones (and letter spacing on them breaks justified lines).
const _indent = '  ';

/// A block laid out at the page width by its painter.
final class _BlockLayout {
  _BlockLayout(
    this.painter, {
    this.hyphens = _SoftHyphens.none,
    required int prefix,
    required int textLength,
    required double dx,
    required bool isText,
    double spaceBefore = 0,
    double spaceAfter = 0,
    bool keepTogether = false,
    double keepWithNext = 0,
  }) : metrics = _BlockMetrics(
         painter,
         hyphens: hyphens,
         prefix: prefix,
         textLength: textLength,
         dx: dx,
         isText: isText,
         spaceBefore: spaceBefore,
         spaceAfter: spaceAfter,
         keepTogether: keepTogether,
         keepWithNext: keepWithNext,
       );

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
        final spaced =
            kind != ParagraphStyle.normal && kind != ParagraphStyle.note;
        return _text(
          block,
          style.paragraph(kind),
          width,
          inset: inset,
          align: switch (kind) {
            ParagraphStyle.subtitle => TextAlign.center,
            ParagraphStyle.normal || ParagraphStyle.note => style.align,
            _ => TextAlign.left,
          },
          indent: kind == ParagraphStyle.normal ? _indent : '',
          strut: kind == ParagraphStyle.normal ? style.bodyStrut : null,
          // Not verses and centred lines.
          hyphenate: switch (kind) {
            ParagraphStyle.normal ||
            ParagraphStyle.note ||
            ParagraphStyle.quote ||
            ParagraphStyle.epigraph => true,
            ParagraphStyle.poem || ParagraphStyle.subtitle => false,
          },
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
    bool hyphenate = false,
    double spaceBefore = 0,
    double spaceAfter = 0,
    bool keepTogether = false,
    double keepWithNext = 0,
  }) {
    final lineWidth = math.max(width - inset, 1.0);
    final hyphenation = hyphenate ? style.hyphenation : null;
    final hyphens = hyphenation == null
        ? _SoftHyphens.none
        : _SoftHyphens.of(hyphenation.breaksOf(block.text));
    final painter = TextPainter(
      text: _span(block, textStyle, indent, hyphens),
      textAlign: align,
      textDirection: TextDirection.ltr,
      textScaler: style.textScaler,
      strutStyle: strut,
    )..layout(minWidth: lineWidth, maxWidth: lineWidth);
    return _BlockLayout(
      painter,
      hyphens: hyphens,
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
  static TextSpan _span(
    TextBlock block,
    TextStyle style,
    String prefix,
    _SoftHyphens hyphens,
  ) {
    final text = hyphens.insertInto(block.text);
    final marks = [
      for (final s in block.spans)
        if (s.kind != SpanKind.noteRef)
          (
            hyphens.toPainter(math.min(s.start, block.text.length)),
            hyphens.toPainter(math.min(s.end, block.text.length)),
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
  final _SoftHyphens hyphens;
  final _BlockMetrics metrics;

  /// Lines that end at a soft hyphen: line → its «-» and where it goes.
  Map<int, (TextPainter, Offset)> get _hyphenMarks => _marks ??= _findHyphens();
  Map<int, (TextPainter, Offset)>? _marks;

  Map<int, (TextPainter, Offset)> _findHyphens() {
    // Soft hyphens may come from the book itself, with hyphenation off too.
    final text = painter.plainText;
    if (hyphens.isEmpty && !text.contains(softHyphen)) return const {};
    final root = painter.text! as TextSpan;
    final lines = painter.computeLineMetrics();
    final marks = <int, (TextPainter, Offset)>{};
    for (var i = 0; i + 1 < metrics.lineCount && i < lines.length; i++) {
      final at =
          metrics.prefix + hyphens.toPainter(metrics.lineStarts[i + 1]) - 1;
      if (at < 0 || at >= text.length || text[at] != softHyphen) continue;
      final leaf = root.getSpanForPosition(TextPosition(offset: at));
      final mark = TextPainter(
        text: TextSpan(
          text: '-',
          style: root.style?.merge(leaf is TextSpan ? leaf.style : null),
        ),
        textDirection: TextDirection.ltr,
        textScaler: painter.textScaler,
      )..layout();
      final x = painter
          .getOffsetForCaret(TextPosition(offset: at), Rect.zero)
          .dx;
      final baseline = mark.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      marks[i] = (mark, Offset(x, lines[i].baseline - baseline));
    }
    return marks;
  }

  /// Draws «-» at the end of lines `[firstLine, endLine)` broken at a soft
  /// hyphen (the text engine breaks there but does not draw it).
  void paintHyphens(Canvas canvas, Offset shift, int firstLine, int endLine) {
    for (final MapEntry(key: line, value: (mark, at)) in _hyphenMarks.entries) {
      if (line >= firstLine && line < endLine) mark.paint(canvas, shift + at);
    }
  }

  void dispose() {
    painter.dispose();
    for (final (mark, _) in _marks?.values ?? const <(TextPainter, Offset)>[]) {
      mark.dispose();
    }
  }
}

/// Soft hyphens put into a block's text for the layout only (ROADMAP
/// 8.8б): words, touches and speed reading keep the block text offsets.
final class _SoftHyphens {
  const _SoftHyphens._(this._at);

  /// Hyphens before the block text offsets [breaks] (ascending).
  factory _SoftHyphens.of(List<int> breaks) => breaks.isEmpty
      ? none
      : _SoftHyphens._([for (var k = 0; k < breaks.length; k++) breaks[k] + k]);

  static const none = _SoftHyphens._([]);

  /// Offsets of the hyphens in the laid-out text (without the prefix).
  final List<int> _at;

  bool get isEmpty => _at.isEmpty;

  String insertInto(String text) {
    if (_at.isEmpty) return text;
    final out = StringBuffer();
    var from = 0;
    for (var k = 0; k < _at.length; k++) {
      final before = _at[k] - k;
      out
        ..write(text.substring(from, before))
        ..write(softHyphen);
      from = before;
    }
    out.write(text.substring(from));
    return out.toString();
  }

  /// Laid-out offset of the block text [offset] (after a hyphen before it).
  int toPainter(int offset) {
    if (_at.isEmpty) return offset;
    // Hyphens k with `_at[k] - k <= offset` come before it.
    var lo = 0;
    var hi = _at.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_at[mid] - mid <= offset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return offset + lo;
  }

  /// Block text offset of the laid-out [offset].
  int toText(int offset) {
    if (_at.isEmpty) return offset;
    var lo = 0;
    var hi = _at.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_at[mid] < offset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return offset - lo;
  }
}

/// Where a laid-out block's lines are: all the page split needs, without
/// the painter (ADR 0003, addendum 2 п. 5).
final class _BlockMetrics {
  _BlockMetrics(
    TextPainter painter, {
    required _SoftHyphens hyphens,
    required this.prefix,
    required this.textLength,
    required this.dx,
    required this.isText,
    required this.spaceBefore,
    required this.spaceAfter,
    required this.keepTogether,
    required this.keepWithNext,
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
      lineStarts[i] = hyphens
          .toText(offset - prefix)
          .clamp(lineStarts[i - 1], textLength);
    }
  }

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
