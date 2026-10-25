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

  /// The bars of the "minutes / pages a day" charts: the days of the week
  /// or the month, the months of the year.
  List<({DateTime from, DateTime to})> barSpans(DateTime today) {
    final (:from, :to) = around(today);
    return switch (this) {
      week || month => [
        for (
          var d = from;
          !d.isAfter(to);
          d = DateTime(d.year, d.month, d.day + 1)
        )
          (from: d, to: d),
      ],
      year => [
        for (var m = 1; m <= 12; m++)
          (from: DateTime(from.year, m), to: DateTime(from.year, m + 1, 0)),
      ],
    };
  }

  static ({DateTime from, DateTime to}) _weekOf(DateTime day) {
    final monday = DateTime(day.year, day.month, day.day - day.weekday + 1);
    return (
      from: monday,
      to: DateTime(monday.year, monday.month, monday.day + 6),
    );
  }
}

/// A bar of the "minutes / pages a day" charts, or a day of the calendar:
/// time and words by mode; [future] — not come yet.
final class DayBar {
  const DayBar({
    required this.from,
    this.ms = const {},
    this.words = const {},
    this.future = false,
  });

  final DateTime from;
  final Map<ReadingMode, int> ms;
  final Map<ReadingMode, int> words;
  final bool future;

  int get totalMs => ms.values.fold(0, (a, b) => a + b);
  int get totalWords => words.values.fold(0, (a, b) => a + b);
}

/// The shade of a calendar day: 0 no reading, 1 under 15 min, 2 under 40,
/// 3 longer.
int calendarLevel(int ms) => switch (ms) {
  <= 0 => 0,
  < 15 * 60000 => 1,
  < 40 * 60000 => 2,
  _ => 3,
};

/// The statistics screen (ADR 0009 п. 6, blocks 1–7).
final class StatsOverview {
  const StatsOverview({
    required this.period,
    required this.from,
    required this.to,
    required this.empty,
    required this.saved,
    required this.readingDays,
    required this.eyeSpeed,
    required this.bars,
    required this.calendar,
    required this.year,
  });

  /// From all the reading [rows]; [finishedAt] — of the books in the
  /// library.
  factory StatsOverview.of(
    StatsPeriod period, {
    required List<ReadingDelta> rows,
    required DateTime today,
    Iterable<DateTime?> finishedAt = const [],
  }) {
    final (:from, :to) = period.around(today);
    final ofPeriod = _within(rows, from, to).toList();
    final eye = pageSpeed([pageSpeedsOf(ofPeriod), pageSpeedsOf(rows)]);
    return StatsOverview(
      period: period,
      from: from,
      to: to,
      empty: !rows.any((r) => r.activeMs > 0 || r.words > 0),
      saved: savedTime(ofPeriod, pageWpm: eye.wpm),
      readingDays: {
        for (final r in ofPeriod)
          if (r.activeMs > 0) r.day,
      }.length,
      eyeSpeed: eye,
      bars: _barsOf(period, ofPeriod, today),
      calendar: _barsOf(StatsPeriod.month, rows, today),
      year: yearTotals(
        today.year,
        finishedAt: finishedAt,
        rows: rows,
        pageWpm: pageSpeed([
          pageSpeedsOf(rows.where((r) => r.day ~/ 10000 == today.year)),
          pageSpeedsOf(rows),
        ]).wpm,
      ),
    );
  }

  final StatsPeriod period;
  final DateTime from;
  final DateTime to;

  /// Nothing read yet, ever.
  final bool empty;

  /// What speed reading saved in the period, against [eyeSpeed].
  final SavedTime saved;

  /// Days with any reading in the period.
  final int readingDays;

  /// Reading by eye in the period, else all time; else a stand-in.
  final Speed eyeSpeed;

  /// The bars of [StatsPeriod.barSpans].
  final List<DayBar> bars;

  /// The days of this month, whatever the period.
  final List<DayBar> calendar;

  /// This year, whatever the period.
  final YearTotals year;

  static List<DayBar> _barsOf(
    StatsPeriod period,
    Iterable<ReadingDelta> rows,
    DateTime today,
  ) {
    final now = dayKey(today);
    return [
      for (final span in period.barSpans(today))
        if (dayKey(span.from) > now)
          DayBar(from: span.from, future: true)
        else
          _barOf(span.from, _within(rows, span.from, span.to)),
    ];
  }

  static DayBar _barOf(DateTime from, Iterable<ReadingDelta> rows) {
    final (ms, words) = (<ReadingMode, int>{}, <ReadingMode, int>{});
    for (final r in rows) {
      ms[r.mode] = (ms[r.mode] ?? 0) + r.activeMs;
      words[r.mode] = (words[r.mode] ?? 0) + r.words;
    }
    return DayBar(from: from, ms: ms, words: words);
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
