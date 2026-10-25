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
    StatsOverview of(StatsPeriod period, List<ReadingDelta> rows) =>
        StatsOverview.of(period, rows: rows, today: today);

    test('nothing read: empty, stand-in speed, no year speeds', () {
      final o = of(StatsPeriod.month, []);
      expect(o.empty, isTrue);
      expect(o.eyeSpeed.known, isFalse);
      expect((o.year.eyeWpm, o.year.playWpm), (null, null));
    });

    test('the period: saved time, days, speeds', () {
      final o = of(StatsPeriod.month, [
        row(ReadingMode.page, minutes: 30, words: 7000, speeds: {24: 10}),
        row(ReadingMode.word, day: 20261021, minutes: 10, words: 3000),
        // September: in the year, not in the month.
        row(ReadingMode.word, day: 20260915, minutes: 10, words: 5000),
      ]);
      expect(o.empty, isFalse);
      expect((o.eyeSpeed.wpm, o.eyeSpeed.known), (245, true));
      expect(o.readingDays, 2);
      expect(o.saved.actual, const Duration(minutes: 10));
      expect(o.saved.usual.inMilliseconds, (3000 * 60000 / 245).round());
      // 8000 words in 20 minutes of speed reading this year.
      expect((o.year.eyeWpm, o.year.playWpm), (245, 400));
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
    });

    test('a period without reading', () {
      final o = of(StatsPeriod.week, [
        row(ReadingMode.page, day: 20260101, minutes: 5),
      ]);
      expect(o.readingDays, 0);
      expect(o.bars.map((b) => b.totalMs), everyElement(0));
    });

    test('a period with few pages takes the eye speed of all time', () {
      final o = of(StatsPeriod.week, [
        row(ReadingMode.page, day: 20260101, speeds: {30: 20}),
        row(ReadingMode.page, speeds: {24: 2}),
      ]);
      expect((o.eyeSpeed.wpm, o.eyeSpeed.known), (305, true));
    });
  });
}
