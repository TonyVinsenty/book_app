import 'dart:math';

import 'package:book_app/book/model/table_of_contents.dart';
import 'package:book_app/layout/book_pagination.dart';
import 'package:flutter/material.dart';

/// The book pages (from 1) the chapters of [lines] start on, in order and
/// once each; the first page has no mark. [starts] — the start page of
/// every section ([BookPagination.chapterStarts]).
List<int> chapterPages(List<ContentsLine> lines, List<PageNumber> starts) {
  final pages = {
    for (final line in lines)
      if (line.sectionIndex < starts.length) starts[line.sectionIndex].value,
  }..remove(1);
  return pages.toList()..sort();
}

/// [value] moved onto the chapter start nearest to it when that is within
/// [reach] pages, or `null` when no chapter is that close.
int? snapToChapter(double value, List<int> pages, double reach) {
  int? best;
  for (final page in pages) {
    final off = (page - value).abs();
    if (off <= reach && (best == null || off < (best - value).abs())) {
      best = page;
    }
  }
  return best;
}

/// The slider track with a thin mark at every chapter start. Marks closer
/// than [minGap] to the last one drawn are left out: in a book of hundreds
/// of chapters the track does not turn into a fence.
class ChapterTrackShape extends RoundedRectSliderTrackShape {
  const ChapterTrackShape({
    required this.marks,
    required this.color,
    required this.activeColor,
    this.minGap = 7,
  });

  /// Where the marks are, from 0 (the start of the track) to 1.
  final List<double> marks;

  /// A mark on the part not read yet, and on the read part.
  final Color color;
  final Color activeColor;
  final double minGap;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );
    if (marks.isEmpty) return;
    final track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final height = (sliderTheme.trackHeight ?? 4) + 6;
    final rtl = textDirection == TextDirection.rtl;
    final active = Paint()..color = activeColor;
    final inactive = Paint()..color = color;
    var last = double.negativeInfinity;
    for (final mark in marks) {
      final x = track.left + track.width * (rtl ? 1 - mark : mark);
      if ((x - last).abs() < minGap) continue;
      last = x;
      final read = rtl ? x > thumbCenter.dx : x < thumbCenter.dx;
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, track.center.dy),
            width: 1.5,
            height: max(height, 0),
          ),
          const Radius.circular(1),
        ),
        read ? active : inactive,
      );
    }
  }
}
