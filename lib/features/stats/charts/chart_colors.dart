import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:flutter/painting.dart';

/// Colors of the statistics charts (mockup `docs/design/stats.html`, values
/// from `docs/design/polish.md` A15): by eye — the accent; the speed
/// reading modes — each palette's own, never the same as its accent.
final class ChartColors {
  factory ChartColors.of(ReadingColors colors) => ChartColors._(
    eye: colors.accent,
    play: colors.chartWord,
    fast: colors.chartPhrase,
    guide: colors.chartGuide,
    line: Color.lerp(colors.surface, colors.textSecondary, 0.3)!,
  );

  const ChartColors._({
    required this.eye,
    required this.play,
    required this.fast,
    required this.guide,
    required this.line,
  });

  final Color eye;
  final Color play;
  final Color fast;
  final Color guide;

  /// Axes and empty bars.
  final Color line;

  Color ofMode(ReadingMode mode) => switch (mode) {
    ReadingMode.page => eye,
    ReadingMode.word => play,
    ReadingMode.phrase => fast,
    ReadingMode.guide => guide,
  };
}
