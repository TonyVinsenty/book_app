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

    test('the bars: days of the week or the month, months of the year', () {
      final week = StatsPeriod.week.barSpans(today);
      expect(week, hasLength(7));
      expect(week.first, (
        from: DateTime(2026, 10, 19),
        to: DateTime(2026, 10, 19),
      ));
      expect(StatsPeriod.month.barSpans(today), hasLength(31));
      final year = StatsPeriod.year.barSpans(today);
      expect(year, hasLength(12));
      expect(year[1], (from: DateTime(2026, 2), to: DateTime(2026, 2, 28)));
    });
  });

  test('the calendar shade by minutes', () {
    expect([0, 1, 14 * 60000, 15 * 60000, 40 * 60000].map(calendarLevel), [
      0,
      1,
      1,
      2,
      3,
    ]);
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

    test('the bars, the calendar and the year', () {
      final rows = [
        row(ReadingMode.page, minutes: 30, words: 7000),
        row(ReadingMode.guide, minutes: 10, words: 3000),
        row(ReadingMode.word, day: 20261021, minutes: 20, words: 2500),
        row(ReadingMode.phrase, day: 20260915, minutes: 5, words: 1000),
        row(ReadingMode.page, day: 20251231, minutes: 50, words: 9000),
      ];
      final week = StatsOverview.of(
        StatsPeriod.week,
        rows: rows,
        pace: const [],
        today: today,
        finishedAt: [DateTime(2026, 3), null, DateTime(2025, 5)],
      );
      // Mon 19, Tue 20, Wed 21 … Fri 23 is today.
      expect(week.bars[1].ms, {
        ReadingMode.page: 30 * 60000,
        ReadingMode.guide: 10 * 60000,
      });
      expect(week.bars[1].totalWords, 10000);
      expect(week.bars[2].totalMs, 20 * 60000);
      expect(week.bars[4].future, isFalse);
      expect(week.bars[5].future, isTrue);
      // 60 minutes, 12 500 words in 2 days.
      expect(week.perDay, const Duration(minutes: 30));
      expect(week.pagesPerDay, 25);
      expect(week.calendar, hasLength(31));
      expect(week.calendar[19].totalMs, 40 * 60000);
      expect(week.calendar[23].future, isTrue);
      expect(week.year.books, 1);
      expect(week.year.words, 13500);
      expect(week.year.time, const Duration(minutes: 65));

      final year = of(StatsPeriod.year, rows);
      expect(year.bars[8].ms, {ReadingMode.phrase: 5 * 60000});
      expect(year.bars[9].totalMs, 60 * 60000);
      expect(year.bars[10].future, isTrue);
      expect(year.perDay, const Duration(minutes: 65) ~/ 3);
    });

    test('a period without reading', () {
      final o = of(StatsPeriod.week, [
        row(ReadingMode.page, day: 20260101, minutes: 5),
      ]);
      expect(o.readingDays, 0);
      expect(o.perDay, Duration.zero);
      expect(o.pagesPerDay, 0);
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
