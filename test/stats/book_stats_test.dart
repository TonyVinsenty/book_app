import 'package:book_app/stats/book_stats.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:flutter_test/flutter_test.dart';

ReadingDelta row(
  ReadingMode mode, {
  int day = 20261023,
  int bookId = 1,
  int minutes = 0,
  int words = 0,
  Map<int, int> speeds = const {},
}) => ReadingDelta(
  day: day,
  bookId: bookId,
  mode: mode,
  dayPart: 2,
  activeMs: minutes * 60000,
  words: words,
  pageSpeeds: speeds,
);

void main() {
  final today = DateTime(2026, 10, 23, 20);
  int setWpm(ReadingMode mode) => switch (mode) {
    ReadingMode.word => 300,
    ReadingMode.phrase => 350,
    _ => 400,
  };

  BookStats of(List<ReadingDelta> rows) =>
      BookStats.of(1, rows: rows, today: today, setWpmOf: setWpm);

  test('a new book: stand-in speeds, nothing spent', () {
    final s = of([]);
    expect((s.speed.wpm, s.speed.known), (200, false));
    expect(s.eyeSpeed.known, isFalse);
    expect(s.playSpeed, isNull);
    expect(s.spent, Duration.zero);
    expect(s.left(2000), const Duration(minutes: 10));
    expect(s.finishOn(2000, today), isNull);
  });

  test('a book read by eye: the median, recent before all time', () {
    final s = of([
      row(ReadingMode.page, day: 20260101, speeds: {40: 50}),
      row(ReadingMode.page, bookId: 2, speeds: {24: 10}),
      row(ReadingMode.page, minutes: 20, words: 5000),
    ]);
    expect((s.speed.wpm, s.speed.known), (245, true));
    expect(s.eyeSpeed.wpm, 245);
    expect(s.spent, const Duration(minutes: 20), reason: 'only this book');
  });

  test('a book read mostly by words: its own speed, else the set pace', () {
    final few = of([
      row(ReadingMode.word, minutes: 30, words: 1500),
      row(ReadingMode.page, minutes: 10, words: 2000),
    ]);
    expect((few.speed.wpm, few.speed.known), (300, false));
    expect(few.playSpeed, isNull);

    final enough = of([
      row(ReadingMode.word, minutes: 10, words: 4000),
      row(ReadingMode.word, bookId: 2, minutes: 10, words: 2000),
      row(ReadingMode.guide, day: 20260901, minutes: 10, words: 9000),
    ]);
    expect((enough.speed.wpm, enough.speed.known), (300, true));
    expect(enough.playSpeed, 300, reason: 'the last 30 days only');
    expect(
      enough.saved.saved,
      const Duration(minutes: 45),
      reason: 'all time: 13000 words by eye at 200 — 65 min, read in 20',
    );
  });

  test('the finish day from the book\'s last 14 days', () {
    final s = of([
      for (final day in [20261023, 20261021, 20261019])
        row(ReadingMode.page, day: day, minutes: 70, words: 14000),
    ]);
    // 200 wpm (no speeds): 3000 words — 15 min, one day of 15 min.
    expect(s.finishOn(3000, today), DateTime(2026, 10, 23));
    expect(s.finishOn(6000, today), DateTime(2026, 10, 24));
  });
}
