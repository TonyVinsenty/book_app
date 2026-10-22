import 'package:book_app/stats/speed_histogram.dart';
import 'package:book_app/stats/stats_calc.dart';
import 'package:book_app/stats/stats_records.dart';

/// The switch on the statistics screen: this week (from Monday), this month
/// or this year.
enum StatsPeriod {
  week,
  month,
  year;

  /// The first and the last day of the period [today] falls into.
  ({DateTime from, DateTime to}) around(DateTime today) => switch (this) {
    week => _weekOf(today),
    month => (
      from: DateTime(today.year, today.month),
      to: DateTime(today.year, today.month + 1, 0),
    ),
    year => (from: DateTime(today.year), to: DateTime(today.year, 12, 31)),
  };

  /// The speed line: 8 weeks for the week and the month, 12 months for the
  /// year, the one with [today] last.
  List<({DateTime from, DateTime to})> lineSpans(DateTime today) =>
      switch (this) {
        week || month => [
          for (var i = 7; i >= 0; i--)
            _weekOf(DateTime(today.year, today.month, today.day - 7 * i)),
        ],
        year => [
          for (var i = 11; i >= 0; i--)
            (
              from: DateTime(today.year, today.month - i),
              to: DateTime(today.year, today.month - i + 1, 0),
            ),
        ],
      };

  static ({DateTime from, DateTime to}) _weekOf(DateTime day) {
    final monday = DateTime(day.year, day.month, day.day - day.weekday + 1);
    return (
      from: monday,
      to: DateTime(monday.year, monday.month, monday.day + 6),
    );
  }
}

/// One point of the speed line; null — too little reading in its span.
typedef SpeedPoint = ({int? eye, int? play});

/// The upper part of the statistics screen (ADR 0009 п. 6, blocks 1–3).
final class StatsOverview {
  const StatsOverview({
    required this.period,
    required this.from,
    required this.to,
    required this.empty,
    required this.saved,
    required this.speedWords,
    required this.readingDays,
    required this.eyeSpeed,
    required this.playSpeed,
    required this.line,
    required this.pace,
  });

  /// From all the reading [rows] and the [pace] rows of any range (the last
  /// [paceDays] are taken).
  factory StatsOverview.of(
    StatsPeriod period, {
    required List<ReadingDelta> rows,
    required List<PaceDelta> pace,
    required DateTime today,
  }) {
    final (:from, :to) = period.around(today);
    final ofPeriod = _within(rows, from, to).toList();
    final eye = pageSpeed([pageSpeedsOf(ofPeriod), pageSpeedsOf(rows)]);
    final paceFrom = dayKey(
      DateTime(today.year, today.month, today.day - paceDays + 1),
    );
    return StatsOverview(
      period: period,
      from: from,
      to: to,
      empty: !rows.any((r) => r.activeMs > 0 || r.words > 0),
      saved: savedTime(ofPeriod, pageWpm: eye.wpm),
      speedWords: ofPeriod
          .where((r) => r.mode != ReadingMode.page)
          .fold(0, (sum, r) => sum + r.words),
      readingDays: {
        for (final r in ofPeriod)
          if (r.activeMs > 0) r.day,
      }.length,
      eyeSpeed: eye,
      playSpeed: playWpm(ofPeriod),
      line: [
        for (final span in period.lineSpans(today))
          _pointOf(_within(rows, span.from, span.to).toList()),
      ],
      pace: comfortablePace(pace.where((r) => r.day >= paceFrom)),
    );
  }

  final StatsPeriod period;
  final DateTime from;
  final DateTime to;

  /// Nothing read yet, ever.
  final bool empty;

  /// What speed reading saved in the period, against [eyeSpeed].
  final SavedTime saved;

  /// Words read in speed reading in the period.
  final int speedWords;

  /// Days with any reading in the period.
  final int readingDays;

  /// Reading by eye in the period, else all time; else a stand-in.
  final Speed eyeSpeed;

  /// Speed reading in the period; null — too few words.
  final int? playSpeed;

  /// The speed line, oldest first (see [StatsPeriod.lineSpans]).
  final List<SpeedPoint> line;

  /// Over the last [paceDays], whatever the period; null — not found yet.
  final ComfortablePace? pace;

  static SpeedPoint _pointOf(List<ReadingDelta> rows) {
    final speeds = pageSpeedsOf(rows);
    return (
      eye: pageCount(speeds) >= minPagesForSpeed ? medianWpm(speeds) : null,
      play: playWpm(rows),
    );
  }

  static Iterable<ReadingDelta> _within(
    Iterable<ReadingDelta> rows,
    DateTime from,
    DateTime to,
  ) {
    final (first, last) = (dayKey(from), dayKey(to));
    return rows.where((r) => r.day >= first && r.day <= last);
  }
}
