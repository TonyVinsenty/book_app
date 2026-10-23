import 'dart:math' as math;

import 'package:book_app/layout/chapter_layout.dart';

/// A laid-out chapter as the scroll sees it ([ChapterLayout]).
abstract interface class StripPages {
  int get pageCount;
  List<PageRow> pageRows(int page);
  double pageExtent(int page);
  int pageOfWord(int wordIndex);
}

/// A row of the scroll: row [row] of page [page] of section [section], at
/// `[top, bottom)` in strip coordinates.
typedef StripRow = ({
  int section,
  int page,
  int row,
  double top,
  double bottom,
  int firstWord,
});

/// Positions in the seamless scroll (ADR 0003, addendum 5): the strip is
/// the chapters one under another, the top of [center] at 0, chapters before
/// it above. A laid-out chapter is its pages stitched by
/// [StripPages.pageExtent] after a [chapterGap] (none before a part of a
/// chapter); others take their estimated height. The window shows the strip
/// from `offset + windowTop` to `offset + windowBottom`; the top row sits at
/// [windowTop], where the first line of a turned page is.
final class StripMap {
  StripMap({
    required this.center,
    required this.sectionCount,
    required this._laidOut,
    required this._estimate,
    required this._continued,
    required this.chapterGap,
    required this.windowTop,
    required this.windowBottom,
  });

  final int center;
  final int sectionCount;
  final double chapterGap;
  final double windowTop;
  final double windowBottom;
  final Map<int, StripPages> _laidOut;
  final double Function(int) _estimate;
  final bool Function(int) _continued;

  final _pageTops = <int, List<double>>{};
  final _chapterTops = <int, double>{};
  final _rows = <(int, int), List<PageRow>>{};

  /// Rows closer than this to the window edge count as inside it.
  static const _eps = 0.5;

  double get windowHeight => windowBottom - windowTop;

  StripPages? pagesOf(int section) => _laidOut[section];

  double gapBefore(int section) =>
      section == 0 || _continued(section) || _contentExtent(section) == 0
      ? 0
      : chapterGap;

  double chapterExtent(int section) =>
      gapBefore(section) + _contentExtent(section);

  double _contentExtent(int section) =>
      _laidOut.containsKey(section) ? _tops(section).last : _estimate(section);

  /// Page tops within the chapter's pages; the last entry is their height.
  List<double> _tops(int section) => _pageTops.putIfAbsent(section, () {
    final pages = _laidOut[section]!;
    final tops = [0.0];
    for (var p = 0; p < pages.pageCount; p++) {
      tops.add(tops.last + pages.pageExtent(p));
    }
    return tops;
  });

  double chapterTop(int section) => _chapterTops.putIfAbsent(section, () {
    if (section == center) return 0;
    return section > center
        ? chapterTop(section - 1) + chapterExtent(section - 1)
        : chapterTop(section + 1) - chapterExtent(section);
  });

  /// Top of page [page] of a laid-out section.
  double pageTop(int section, int page) =>
      chapterTop(section) + gapBefore(section) + _tops(section)[page];

  /// The section at strip position [y] (its gap included); the first or the
  /// last one beyond the ends.
  int sectionAt(double y) {
    var s = center.clamp(0, sectionCount - 1);
    while (s + 1 < sectionCount && y >= chapterTop(s + 1)) {
      s++;
    }
    while (s > 0 && y < chapterTop(s)) {
      s--;
    }
    return s;
  }

  List<PageRow> _rowsOf(int section, int page) =>
      _rows.putIfAbsent((section, page), () {
        return _laidOut[section]!.pageRows(page);
      });

  StripRow _row(int section, int page, int row) {
    final base = pageTop(section, page);
    final r = _rowsOf(section, page)[row];
    return (
      section: section,
      page: page,
      row: row,
      top: base + r.top,
      bottom: base + r.bottom,
      firstWord: r.firstWord,
    );
  }

  /// The first row from page [page] of [section] on, or null if a chapter
  /// on the way is not laid out (or the book ends).
  StripRow? _firstFrom(int section, int page) {
    for (var s = section, p = page; s < sectionCount; s++, p = 0) {
      final pages = _laidOut[s];
      if (pages == null) return null;
      for (; p < pages.pageCount; p++) {
        if (_rowsOf(s, p).isNotEmpty) return _row(s, p, 0);
      }
    }
    return null;
  }

  /// The last row up to page [page] of [section] (null: to the chapter end).
  StripRow? _lastUpTo(int section, int? page) {
    int? p = page;
    for (var s = section; s >= 0; s--, p = null) {
      final pages = _laidOut[s];
      if (pages == null) return null;
      for (p ??= pages.pageCount - 1; p! >= 0; p--) {
        final rows = _rowsOf(s, p);
        if (rows.isNotEmpty) return _row(s, p, rows.length - 1);
      }
    }
    return null;
  }

  StripRow? next(StripRow r) => r.row + 1 < _rowsOf(r.section, r.page).length
      ? _row(r.section, r.page, r.row + 1)
      : _firstFrom(r.section, r.page + 1);

  StripRow? previous(StripRow r) => r.row > 0
      ? _row(r.section, r.page, r.row - 1)
      : r.page > 0
      ? _lastUpTo(r.section, r.page - 1)
      : r.section > 0
      ? _lastUpTo(r.section - 1, null)
      : null;

  /// The row reaching below strip position [y] (holding it, or the first
  /// after it); null if that chapter is not laid out.
  StripRow? rowAt(double y) {
    final s = sectionAt(y);
    final pages = _laidOut[s];
    if (pages == null) return null;
    final tops = _tops(s);
    final base = chapterTop(s) + gapBefore(s);
    var p = 0;
    while (p + 1 < pages.pageCount && base + tops[p + 1] <= y) {
      p++;
    }
    final rows = _rowsOf(s, p);
    for (var i = 0; i < rows.length; i++) {
      if (base + tops[p] + rows[i].bottom > y) return _row(s, p, i);
    }
    return _firstFrom(s, p + 1);
  }

  /// The first row seen whole at scroll [offset]: the row at the window top,
  /// or the next one if it is cut (unless that one is out of the window).
  StripRow? topRow(double offset) {
    final y = offset + windowTop;
    final r = rowAt(y + _eps);
    if (r == null || r.top >= y - _eps) return r;
    final n = next(r);
    return n != null && n.top < offset + windowBottom ? n : r;
  }

  /// The first row seen whole on screen at scroll [offset]: like [topRow],
  /// but a row in the margin above the window counts, as it is not hidden.
  StripRow? seenRow(double offset) {
    final r = rowAt(offset + _eps);
    final inMargin =
        r != null && r.top >= offset - _eps && r.top < offset + windowTop;
    return inMargin ? r : topRow(offset);
  }

  /// The offset that puts the row of word [wordIndex] at the window top;
  /// null if its chapter is not laid out or shows nothing.
  double? offsetOf(int section, int wordIndex) {
    final pages = _laidOut[section];
    if (pages == null || pages.pageCount == 0) return null;
    final p = pages.pageOfWord(wordIndex);
    final rows = _rowsOf(section, p);
    var i = 0;
    while (i + 1 < rows.length && rows[i + 1].firstWord <= wordIndex) {
      i++;
    }
    final row = rows.isEmpty ? _firstFrom(section, p) : _row(section, p, i);
    return row == null ? null : row.top - windowTop;
  }

  /// A tap forward: the row cut at the window bottom (or the first one
  /// below it) becomes the top row, so no line is lost. Null if it is in a
  /// chapter not laid out, or the book ends.
  double? forward(double offset) {
    final cut = rowAt(offset + windowBottom + _eps);
    if (cut == null) return null;
    final target = cut.top - windowTop;
    // A row taller than the window is already at the top.
    return target > offset + _eps ? target : offset + windowHeight;
  }

  /// A tap back: the row above the top row becomes the bottom row, and the
  /// new top row is not cut. Null at the book start or before a chapter not
  /// laid out.
  double? backward(double offset) {
    final top = topRow(offset);
    if (top == null) return null;
    // Inside a row taller than the window: up by a window, to its top.
    if (top.top < offset + windowTop - _eps) {
      return math.max(offset - windowHeight, top.top - windowTop);
    }
    final above = previous(top);
    if (above == null) return null;
    final shown = topRow(above.bottom - windowBottom);
    final target = shown == null ? null : shown.top - windowTop;
    return target != null && target < offset - _eps
        ? target
        : offset - windowHeight;
  }
}
