import 'dart:math' as math;

import 'package:book_app/layout/chapter_layout.dart';
import 'package:book_app/layout/strip_map.dart';
import 'package:flutter_test/flutter_test.dart';

const _line = 20.0;

/// A chapter of rows [_line] high, one word each from [firstWord]; pages of
/// [rowsPerPage] rows, page `p` followed by `seams[p]`.
final class _Pages implements StripPages {
  _Pages(this.firstWord, this.rowsPerPage, {this.seams = const {}});

  final int firstWord;
  final List<int> rowsPerPage;
  final Map<int, double> seams;

  int _start(int page) =>
      firstWord + rowsPerPage.take(page).fold(0, (a, b) => a + b);

  @override
  int get pageCount => rowsPerPage.length;

  @override
  List<PageRow> pageRows(int page) => [
    for (var i = 0; i < rowsPerPage[page]; i++)
      (top: i * _line, bottom: (i + 1) * _line, firstWord: _start(page) + i),
  ];

  @override
  double pageExtent(int page) => rowsPerPage[page] * _line + (seams[page] ?? 0);

  @override
  int pageOfWord(int wordIndex) {
    var p = 0;
    while (p + 1 < pageCount && _start(p + 1) <= wordIndex) {
      p++;
    }
    return p;
  }
}

void main() {
  // Section 1 shows nothing, 3 is a part of 2, 4 is not laid out. A page
  // is 5 rows, as tall as the window.
  StripMap map({int center = 2, Map<int, StripPages>? laidOut}) => StripMap(
    center: center,
    sectionCount: 5,
    laidOut:
        laidOut ??
        {
          0: _Pages(0, [5, 5, 2]),
          1: _Pages(100, []),
          2: _Pages(200, [5, 5, 2]),
          3: _Pages(300, [5, 5, 1], seams: {0: 8}),
        },
    estimate: (s) => 500,
    continued: (s) => s == 3,
    chapterGap: 60,
    windowTop: 10,
    windowBottom: 110,
  );

  test('chapters stack around the center with gaps before chapters', () {
    final m = map();
    expect(m.chapterTop(2), 0);
    expect(m.gapBefore(2), 60);
    expect(m.chapterTop(3), 60 + 12 * _line);
    expect(m.gapBefore(3), 0, reason: 'a part of a chapter');
    expect(m.chapterTop(4), 300 + 11 * _line + 8);
    expect(m.gapBefore(4), 60, reason: 'not laid out: estimated');
    expect(m.chapterTop(1), 0, reason: 'shows nothing, no gap');
    expect(m.chapterTop(0), -12 * _line, reason: 'no gap at the book start');
    expect(m.pageTop(2, 1), 60 + 5 * _line);
    expect(m.pageTop(3, 1), 300 + 5 * _line + 8);
    expect(m.sectionAt(-1), 0);
    expect(m.sectionAt(0), 2);
    expect(m.sectionAt(299), 2);
    expect(m.sectionAt(300), 3);
    expect(m.sectionAt(1e6), 4);
    expect(m.sectionAt(-1e6), 0);
    // Another center gives the same strip, shifted.
    final other = map(center: 0);
    expect(other.chapterTop(2) - other.chapterTop(0), 12 * _line);
  });

  test('a word goes to the window top; the top row is the first whole', () {
    final m = map();
    expect(m.offsetOf(2, 200), 60 - 10);
    expect(m.topRow(50)?.firstWord, 200);
    expect(m.offsetOf(2, 207), 60 + 7 * _line - 10);
    expect(m.topRow(m.offsetOf(2, 207)!)?.firstWord, 207);
    expect(m.offsetOf(3, 305), 300 + 5 * _line + 8 - 10);
    // A row cut at the top is not the top row.
    expect(m.topRow(55)?.firstWord, 201);
    expect(m.topRow(50.3)?.firstWord, 200, reason: 'less than half a point');
    // ...but it is seen while its top is in the margin above the window.
    expect(m.seenRow(55)?.firstWord, 200);
    expect(m.seenRow(50)?.firstWord, 200);
    expect(m.seenRow(61)?.firstWord, 201, reason: 'cut at the screen top');
    expect(m.seenRow(m.offsetOf(2, 207)!)?.firstWord, 207);
    expect(m.offsetOf(4, 400), isNull, reason: 'not laid out');
    expect(m.offsetOf(1, 100), isNull, reason: 'shows nothing');
  });

  test('taps from a whole page give the next and previous page', () {
    final m = map();
    final page0 = m.offsetOf(2, 200)!;
    final page1 = m.offsetOf(2, 205)!;
    expect(m.forward(page0), page1);
    expect(m.backward(page1), page0);
  });

  test('taps go over the chapter gap and an empty chapter', () {
    final m = map();
    final end = m.offsetOf(0, 10)!;
    expect(m.forward(end), m.offsetOf(2, 200));
    final back = m.backward(m.offsetOf(2, 200)!)!;
    expect(m.topRow(back)?.firstWord, 7);
  });

  test('no line is lost or cut by taps, whatever the offset', () {
    final m = map();
    final random = math.Random(3);
    StripRow? lastWhole(double offset) {
      StripRow? last;
      for (var r = m.topRow(offset); r != null; r = m.next(r)) {
        if (r.bottom > offset + m.windowBottom + 0.5) break;
        last = r;
      }
      return last;
    }

    for (var i = 0; i < 300; i++) {
      final offset = -12 * _line - 10 + random.nextDouble() * 600;
      final forward = m.forward(offset);
      if (forward != null) {
        final last = lastWhole(offset);
        final top = m.topRow(forward)!;
        expect(top.top, closeTo(forward + m.windowTop, 0.01));
        final next = last == null ? null : m.next(last);
        if (next != null) {
          expect(
            (top.section, top.page, top.row),
            (next.section, next.page, next.row),
          );
        }
      }
      final backward = m.backward(offset);
      if (backward != null) {
        expect(backward, lessThan(offset));
        final above = m.previous(m.topRow(offset)!)!;
        expect(above.bottom, lessThanOrEqualTo(backward + m.windowBottom + .5));
        expect(m.topRow(backward)!.top, closeTo(backward + m.windowTop, 0.01));
      }
    }
  });

  test('a chapter not laid out stops the taps; the book ends', () {
    final m = map();
    final end = m.offsetOf(3, 310)!;
    expect(m.forward(end), isNull);
    expect(m.backward(m.offsetOf(0, 0)!), isNull);
  });

  test('a row taller than the window moves by a window', () {
    final m = StripMap(
      center: 0,
      sectionCount: 1,
      laidOut: {0: _TallRow()},
      estimate: (s) => 0,
      continued: (s) => false,
      chapterGap: 60,
      windowTop: 10,
      windowBottom: 110,
    );
    expect(m.forward(-10), 90);
    expect(m.topRow(90)?.row, 0);
    expect(m.backward(90), -10);
  });
}

final class _TallRow implements StripPages {
  @override
  int get pageCount => 1;

  @override
  List<PageRow> pageRows(int page) => [(top: 0, bottom: 300, firstWord: 0)];

  @override
  double pageExtent(int page) => 300;

  @override
  int pageOfWord(int wordIndex) => 0;
}
