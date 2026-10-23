import 'dart:math' as math;

import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/speed_histogram.dart';
import 'package:book_app/stats/stats_records.dart';

// What the numbers on the statistics screens are made of (ADR 0009 п. 5).
// Rows of `reading_days` and `pace_days` come in as ReadingDelta and
// PaceDelta: a stored row is the sum of the deltas added to it.

/// Reading by eye when the user's own speed is not known yet: an average
/// adult.
const fallbackPageWpm = 200;

/// A speed and whether it is the user's own (false — a stand-in, shown as
/// "being found out").
typedef Speed = ({int wpm, bool known});

/// Page speeds of the [ReadingMode.page] rows, merged.
Map<int, int> pageSpeedsOf(Iterable<ReadingDelta> rows) => rows
    .where((r) => r.mode == ReadingMode.page)
    .fold(const {}, (sum, r) => mergeBuckets(sum, r.pageSpeeds));

/// The median of the first histogram with [minPagesForSpeed] pages — say,
/// the period, then all time; none — [fallbackPageWpm].
Speed pageSpeed(Iterable<Map<int, int>> histograms) {
  for (final h in histograms) {
    if (pageCount(h) >= minPagesForSpeed) {
      return (wpm: medianWpm(h)!, known: true);
    }
  }
  return (wpm: fallbackPageWpm, known: false);
}

/// Time the speed reading took against the time its words would have taken
/// by eye at [pageWpm].
final class SavedTime {
  const SavedTime({required this.usual, required this.actual});

  final Duration usual;
  final Duration actual;

  /// Never below zero: "speed reading is not faster yet" then.
  Duration get saved => usual > actual ? usual - actual : Duration.zero;

  bool get faster => usual > actual;
}

SavedTime savedTime(Iterable<ReadingDelta> rows, {required int pageWpm}) {
  var words = 0;
  var actualMs = 0;
  for (final r in rows.where((r) => r.mode != ReadingMode.page)) {
    words += r.words;
    actualMs += r.activeMs;
  }
  return SavedTime(
    usual: _timeOf(words, pageWpm),
    actual: Duration(milliseconds: actualMs),
  );
}

/// Pace steps of the comfortable pace, words per minute.
const paceStepWpm = 50;

/// Fewer words at a step tell nothing about it.
const minWordsPerStep = 1500;

/// Days the comfortable pace is taken from, whatever the period shown.
const paceDays = 90;

/// The comfortable pace of [mode] and what it is found from.
final class ComfortablePace {
  const ComfortablePace({
    required this.mode,
    required this.wpm,
    required this.rates,
    required this.limit,
  });

  final SpeedMode mode;

  /// The step, words per minute.
  final int wpm;

  /// Backs and pauses per 100 words by step, slowest first.
  final Map<int, double> rates;

  /// Rates above it are "too fast".
  final double limit;
}

/// The comfortable pace: the mode read most in [rows] (the last [paceDays])
/// and the fastest step of it where the backs and pauses per 100 words stay
/// within max(2 × r_min, r_min + 1); null — fewer than 2 steps with
/// [minWordsPerStep].
ComfortablePace? comfortablePace(Iterable<PaceDelta> rows) {
  final wordsOf = <SpeedMode, int>{};
  for (final r in rows) {
    wordsOf[r.mode] = (wordsOf[r.mode] ?? 0) + r.words;
  }
  if (wordsOf.isEmpty) return null;
  final mode = wordsOf.entries.reduce((a, b) => b.value > a.value ? b : a).key;

  final steps = <int, ({int words, int signals})>{};
  for (final r in rows.where((r) => r.mode == mode)) {
    final step = r.wpm ~/ paceStepWpm * paceStepWpm;
    final old = steps[step] ?? (words: 0, signals: 0);
    steps[step] = (
      words: old.words + r.words,
      signals: old.signals + r.backs + r.pauses,
    );
  }
  final rates = {
    for (final step in steps.keys.toList()..sort())
      if (steps[step]! case (:final words, :final signals)
          when words >= minWordsPerStep)
        step: signals / words * 100,
  };
  if (rates.length < 2) return null;
  final rMin = rates.values.reduce(math.min);
  final limit = math.max(2 * rMin, rMin + 1);
  final wpm = rates.entries
      .where((e) => e.value <= limit)
      .map((e) => e.key)
      .reduce(math.max);
  return ComfortablePace(mode: mode, wpm: wpm, rates: rates, limit: limit);
}

/// The mode a book is read in most, by time; a new book — by eye.
ReadingMode bookMode(Iterable<ReadingDelta> bookRows) {
  final msOf = <ReadingMode, int>{};
  for (final r in bookRows) {
    msOf[r.mode] = (msOf[r.mode] ?? 0) + r.activeMs;
  }
  final read = msOf.entries.where((e) => e.value > 0);
  if (read.isEmpty) return ReadingMode.page;
  return read.reduce((a, b) => b.value > a.value ? b : a).key;
}

/// Fewer words in speed reading give no reliable speed of the mode.
const minWordsForPlaySpeed = 2000;

/// The speed "time left" is counted at: for [ReadingMode.page] — the median
/// of the [recent] rows (30 days), then of [all]; for speed reading — the
/// actual speed of the mode in [recent], else the set pace [setWpm]
/// (SmartPace keeps a chapter at about words ÷ pace, ADR 0004).
Speed readingSpeed(
  ReadingMode mode, {
  required Iterable<ReadingDelta> recent,
  required Iterable<ReadingDelta> all,
  required int setWpm,
}) {
  if (mode == ReadingMode.page) {
    return pageSpeed([pageSpeedsOf(recent), pageSpeedsOf(all)]);
  }
  return switch (playWpm(recent.where((r) => r.mode == mode))) {
    final wpm? => (wpm: wpm, known: true),
    null => (wpm: setWpm, known: false),
  };
}

/// The actual speed of the speed reading [rows] (page rows are skipped);
/// null below [minWordsForPlaySpeed].
int? playWpm(Iterable<ReadingDelta> rows) {
  var words = 0;
  var ms = 0;
  for (final r in rows.where((r) => r.mode != ReadingMode.page)) {
    words += r.words;
    ms += r.activeMs;
  }
  if (words < minWordsForPlaySpeed || ms == 0) return null;
  return (words * 60000 / ms).round();
}

/// The reader's measured speeds over all [rows]: by eye (null below
/// [minPagesForSpeed] pages) and speed reading (null below
/// [minWordsForPlaySpeed] words); for the book page.
({int? page, int? play}) measuredSpeeds(List<ReadingDelta> rows) {
  final eye = pageSpeed([pageSpeedsOf(rows)]);
  return (page: eye.known ? eye.wpm : null, play: playWpm(rows));
}

/// How long [words] take at [wpm].
Duration timeLeft(int words, int wpm) => _timeOf(math.max(words, 0), wpm);

/// Days a finish date is guessed from, today included.
const finishDays = 14;

/// Fewer days with this book in [finishDays] give no date.
const minFinishReadingDays = 3;

/// The day the book is likely finished: [left] ÷ the average time a day on
/// it over the last [finishDays] calendar days (days without it count as
/// zero); today, if it fits into one such day. [bookRows] — the book's rows,
/// any range.
DateTime? finishDate(
  Duration left, {
  required Iterable<ReadingDelta> bookRows,
  required DateTime today,
}) {
  final from = dayKey(
    DateTime(today.year, today.month, today.day - finishDays + 1),
  );
  final to = dayKey(today);
  final days = <int>{};
  var ms = 0;
  for (final r in bookRows.where((r) => r.day >= from && r.day <= to)) {
    if (r.activeMs <= 0) continue;
    days.add(r.day);
    ms += r.activeMs;
  }
  if (days.length < minFinishReadingDays) return null;
  final perDay = ms / finishDays;
  final more = math.max((left.inMilliseconds / perDay).ceil() - 1, 0);
  return DateTime(today.year, today.month, today.day + more);
}

/// A page of the "pages a day" chart: words, as on a paper page. It does
/// not depend on the font and counts speed reading the same way; change
/// freely, nothing stored depends on it.
const wordsPerPage = 250;

int pagesOf(int words) => (words / wordsPerPage).round();

/// The year in numbers: finished books, words, time, saved by speed reading.
final class YearTotals {
  const YearTotals({
    required this.books,
    required this.words,
    required this.time,
    required this.saved,
  });

  final int books;
  final int words;
  final Duration time;
  final SavedTime saved;
}

/// Totals of [year]: books by [finishedAt] (deleted books are not there),
/// the rest from [rows] of that year; other years' rows are skipped.
YearTotals yearTotals(
  int year, {
  required Iterable<DateTime?> finishedAt,
  required Iterable<ReadingDelta> rows,
  required int pageWpm,
}) {
  final ofYear = rows.where((r) => r.day ~/ 10000 == year).toList();
  return YearTotals(
    books: finishedAt.where((t) => t?.year == year).length,
    words: ofYear.fold(0, (sum, r) => sum + r.words),
    time: Duration(milliseconds: ofYear.fold(0, (sum, r) => sum + r.activeMs)),
    saved: savedTime(ofYear, pageWpm: pageWpm),
  );
}

Duration _timeOf(int words, int wpm) =>
    Duration(milliseconds: (words * 60000 / wpm).round());
