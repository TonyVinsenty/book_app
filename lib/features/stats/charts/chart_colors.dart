import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:flutter/painting.dart';

/// Colors of the statistics charts (mockup `docs/design/stats.html`): by
/// eye — the accent, speed reading — green, "too fast" — violet; lighter at
/// night. In the bars of days the modes: by word — green, by phrase —
/// violet, the highlight — blue.
final class ChartColors {
  factory ChartColors.of(ReadingColors colors) {
    final night = colors.background.computeLuminance() < 0.2;
    return ChartColors._(
      eye: colors.accent,
      play: night ? const Color(0xFF8FB597) : const Color(0xFF6E9F7E),
      fast: night ? const Color(0xFFA99BD3) : const Color(0xFF9885C9),
      guide: night ? const Color(0xFF94AED0) : const Color(0xFF6F8DB5),
      line: Color.lerp(colors.surface, colors.textSecondary, 0.3)!,
    );
  }

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
