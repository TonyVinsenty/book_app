import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/stats_calc.dart';
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

PaceDelta pace(
  int wpm,
  int words,
  int signals, {
  SpeedMode mode = SpeedMode.word,
}) => PaceDelta(
  day: 20261023,
  mode: mode,
  wpm: wpm,
  words: words,
  backs: signals,
);

void main() {
  group('pageSpeed', () {
    final enough = {20: 10}; // 10 pages at 200–209 → 205
    final few = {30: 9};
    for (final (name, histograms, expected) in [
      ('the period when it has enough pages', [enough, few], (205, true)),
      ('all time when the period has few', [few, enough], (205, true)),
      ('the stand-in when both have few', [few, few], (200, false)),
      ('the stand-in with no data', <Map<int, int>>[], (200, false)),
    ]) {
      test(name, () {
        final s = pageSpeed(histograms);
        expect((s.wpm, s.known), expected);
      });
    }

    test('only page rows give speeds', () {
      expect(
        pageSpeedsOf([
          row(ReadingMode.page, speeds: {20: 3}),
          row(ReadingMode.page, speeds: {20: 1, 25: 2}),
          row(ReadingMode.word, speeds: {40: 5}),
        ]),
        {20: 4, 25: 2},
      );
    });
  });

  group('savedTime', () {
    for (final (name, rows, usual, actual, saved) in [
      (
        'speed modes against reading by eye',
        [
          row(ReadingMode.word, words: 4000, minutes: 10),
          row(ReadingMode.guide, words: 2000, minutes: 5),
          row(ReadingMode.page, words: 9000, minutes: 45),
        ],
        30, // 6000 words at 200
        15,
        15,
      ),
      (
        'slower than the eye is zero',
        [row(ReadingMode.phrase, words: 1000, minutes: 8)],
        5,
        8,
        0,
      ),
      ('nothing read', <ReadingDelta>[], 0, 0, 0),
    ]) {
      test(name, () {
        final s = savedTime(rows, pageWpm: 200);
        expect(
          (s.usual.inMinutes, s.actual.inMinutes, s.saved.inMinutes),
          (usual, actual, saved),
        );
        expect(s.faster, saved > 0);
      });
    }
  });

  group('comfortablePace', () {
    for (final (name, rows, expected) in [
      (
        'the fastest step within twice the lowest rate',
        // r: 300 → 1, 350 → 1.8, 400 → 2.5
        [pace(300, 2000, 20), pace(350, 2000, 36), pace(400, 2000, 50)],
        (SpeedMode.word, 350),
      ),
      (
        'r_min + 1 when it is wider than twice r_min',
        // r: 300 → 0.25, 350 → 1.2 (≤ 1.25), 400 → 1.5
        [pace(300, 2000, 5), pace(350, 2000, 24), pace(400, 2000, 30)],
        (SpeedMode.word, 350),
      ),
      (
        '325 falls to the 300 step',
        [pace(300, 1000, 10), pace(325, 1000, 10), pace(400, 2000, 100)],
        (SpeedMode.word, 300),
      ),
      (
        'steps with few words do not count',
        [pace(300, 2000, 20), pace(400, 1499, 0)],
        null,
      ),
      ('one step is not enough', [pace(300, 5000, 10)], null),
      ('no rows', <PaceDelta>[], null),
      (
        'the mode with most words',
        [
          pace(300, 2000, 20),
          pace(400, 2000, 20),
          pace(500, 3000, 30, mode: SpeedMode.guide),
          pace(600, 3000, 30, mode: SpeedMode.guide),
        ],
        (SpeedMode.guide, 600),
      ),
    ]) {
      test(name, () {
        final p = comfortablePace(rows);
        expect(p == null ? null : (p.mode, p.wpm), expected);
      });
    }
  });

  group('bookMode', () {
    for (final (name, rows, expected) in [
      ('a new book is read by eye', <ReadingDelta>[], ReadingMode.page),
      (
        'the mode with most time, not words',
        [
          row(ReadingMode.page, minutes: 30, words: 6000),
          row(ReadingMode.word, minutes: 40, words: 12000),
          row(ReadingMode.page, minutes: 5, words: 1000),
        ],
        ReadingMode.word,
      ),
      (
        'rows without time do not count',
        [row(ReadingMode.guide, words: 10)],
        ReadingMode.page,
      ),
    ]) {
      test(name, () => expect(bookMode(rows), expected));
    }
  });

  group('readingSpeed', () {
    final pages = row(ReadingMode.page, speeds: {24: 10});
    for (final (name, mode, recent, all, expected) in [
      (
        'by eye — the recent median',
        ReadingMode.page,
        [pages],
        <ReadingDelta>[],
        (245, true),
      ),
      (
        'by eye — all time when recent has few',
        ReadingMode.page,
        <ReadingDelta>[],
        [pages],
        (245, true),
      ),
      (
        'by eye — the stand-in',
        ReadingMode.page,
        <ReadingDelta>[],
        <ReadingDelta>[],
        (200, false),
      ),
      (
        'speed reading — the actual speed',
        ReadingMode.word,
        [
          row(ReadingMode.word, words: 3000, minutes: 10),
          row(ReadingMode.phrase, words: 9000, minutes: 10),
        ],
        <ReadingDelta>[],
        (300, true),
      ),
      (
        'speed reading — the set pace below 2000 words',
        ReadingMode.word,
        [row(ReadingMode.word, words: 1999, minutes: 4)],
        <ReadingDelta>[],
        (350, false),
      ),
    ]) {
      test(name, () {
        final s = readingSpeed(mode, recent: recent, all: all, setWpm: 350);
        expect((s.wpm, s.known), expected);
      });
    }
  });

  group('timeLeft', () {
    for (final (words, wpm, expected) in [
      (2000, 200, const Duration(minutes: 10)),
      (100, 300, const Duration(seconds: 20)),
      (0, 200, Duration.zero),
      (-50, 200, Duration.zero),
    ]) {
      test(
        '$words words at $wpm',
        () => expect(timeLeft(words, wpm), expected),
      );
    }
  });

  group('finishDate', () {
    final today = DateTime(2026, 10, 23, 21);
    // 3 days × 70 min in 14 days → 15 min a day
    final read = [
      for (final day in [20261023, 20261015, 20261010])
        row(ReadingMode.page, day: day, minutes: 70),
    ];
    for (final (name, left, rows, expected) in [
      ('15 min left fits today', 15, read, DateTime(2026, 10, 23)),
      ('16 min left is tomorrow', 16, read, DateTime(2026, 10, 24)),
      ('150 min crosses the month', 150, read, DateTime(2026, 11, 1)),
      ('nothing left is today', 0, read, DateTime(2026, 10, 23)),
      ('2 reading days give no date', 60, read.take(2), null),
      (
        'days before the 14 do not count',
        60,
        [...read.take(2), row(ReadingMode.page, day: 20261009, minutes: 70)],
        null,
      ),
      (
        'several rows of one day are one day',
        60,
        [...read.take(2), row(ReadingMode.word, day: 20261023, minutes: 5)],
        null,
      ),
    ]) {
      test(name, () {
        expect(
          finishDate(
            Duration(minutes: left),
            bookRows: rows,
            today: today,
          ),
          expected,
        );
      });
    }
  });

  test('a page is 250 words', () {
    expect([0, 124, 125, 250, 1000].map(pagesOf), [0, 0, 1, 1, 4]);
  });

  test('year totals take only that year', () {
    final t = yearTotals(
      2026,
      finishedAt: [
        DateTime(2026, 3, 1),
        DateTime(2025, 12, 31),
        null,
        DateTime(2026, 10, 1),
      ],
      rows: [
        row(ReadingMode.page, day: 20260105, words: 3000, minutes: 15),
        row(ReadingMode.word, day: 20261023, words: 4000, minutes: 10),
        row(ReadingMode.word, day: 20251231, words: 9999, minutes: 99),
      ],
      pageWpm: 200,
    );
    expect(
      (t.books, t.words, t.time.inMinutes, t.saved.saved.inMinutes),
      (2, 7000, 25, 10),
    );
  });
}
