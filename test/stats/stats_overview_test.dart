import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/stats_overview.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:flutter_test/flutter_test.dart';

ReadingDelta row(
  ReadingMode mode, {
  int day = 20261020,
  int minutes = 0,
  int words = 0,
  Map<int, int> speeds = const {},
}) => ReadingDelta(
  day: day,
  bookId: 1,
  mode: mode,
  dayPart: 2,
  activeMs: minutes * 60000,
  words: words,
  pageSpeeds: speeds,
);

PaceDelta pace(int wpm, int words, int backs, {int day = 20261020}) =>
    PaceDelta(
      day: day,
      mode: SpeedMode.word,
      wpm: wpm,
      words: words,
      backs: backs,
    );

void main() {
  // A Friday.
  final today = DateTime(2026, 10, 23, 20);

  group('StatsPeriod', () {
    test('the week from Monday, the month, the year', () {
      expect(StatsPeriod.week.around(today), (
        from: DateTime(2026, 10, 19),
        to: DateTime(2026, 10, 25),
      ));
      expect(StatsPeriod.month.around(today), (
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 31),
      ));
      expect(StatsPeriod.year.around(today), (
        from: DateTime(2026),
        to: DateTime(2026, 12, 31),
      ));
    });

    test('the line: 8 weeks, or 12 months over the year boundary', () {
      for (final period in [StatsPeriod.week, StatsPeriod.month]) {
        final spans = period.lineSpans(today);
        expect(spans, hasLength(8));
        expect(spans.first.from, DateTime(2026, 8, 31));
        expect(spans.last, StatsPeriod.week.around(today));
      }
      final months = StatsPeriod.year.lineSpans(today);
      expect(months, hasLength(12));
      expect(months.first, (
        from: DateTime(2025, 11),
        to: DateTime(2025, 11, 30),
      ));
      expect(months.last, StatsPeriod.month.around(today));
    });
  });

  group('StatsOverview', () {
    StatsOverview of(
      StatsPeriod period,
      List<ReadingDelta> rows, [
      List<PaceDelta> paceRows = const [],
    ]) => StatsOverview.of(period, rows: rows, pace: paceRows, today: today);

    test('nothing read: empty, stand-in speed, no line', () {
      final o = of(StatsPeriod.month, []);
      expect(o.empty, isTrue);
      expect(o.eyeSpeed.known, isFalse);
      expect(o.playSpeed, isNull);
      expect(o.line, everyElement((eye: null, play: null)));
      expect(o.pace, isNull);
    });

    test('the period: saved time, days, words, speeds', () {
      final o = of(StatsPeriod.month, [
        row(ReadingMode.page, minutes: 30, words: 7000, speeds: {24: 10}),
        row(ReadingMode.word, day: 20261021, minutes: 10, words: 3000),
        // September: in the line, not in the month.
        row(ReadingMode.word, day: 20260915, minutes: 10, words: 5000),
      ]);
      expect(o.empty, isFalse);
      expect((o.eyeSpeed.wpm, o.eyeSpeed.known), (245, true));
      expect(o.playSpeed, 300);
      expect(o.readingDays, 2);
      expect(o.speedWords, 3000);
      expect(o.saved.actual, const Duration(minutes: 10));
      expect(o.saved.usual.inMilliseconds, (3000 * 60000 / 245).round());
      // Weeks: Sep 14 is the 3rd of 8, Oct 19 the last.
      expect(o.line[2], (eye: null, play: 500));
      expect(o.line.last, (eye: 245, play: 300));
    });

    test('a period with few pages takes the eye speed of all time', () {
      final o = of(StatsPeriod.week, [
        row(ReadingMode.page, day: 20260101, speeds: {30: 20}),
        row(ReadingMode.page, speeds: {24: 2}),
      ]);
      expect((o.eyeSpeed.wpm, o.eyeSpeed.known), (305, true));
    });

    test('the comfortable pace: only the last 90 days', () {
      final o = of(
        StatsPeriod.week,
        [row(ReadingMode.word, minutes: 1, words: 300)],
        [
          pace(300, 2000, 20),
          pace(400, 2000, 100),
          // Too old: it would make 500 the comfortable one.
          pace(500, 20000, 0, day: 20260601),
        ],
      );
      expect(o.pace?.wpm, 300);
      expect(o.pace?.rates, {300: 1.0, 400: 5.0});
    });
  });
}
