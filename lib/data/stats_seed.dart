import 'dart:math';

import 'package:book_app/data/stats_repository.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/stats_records.dart';

/// Days of made-up reading.
const seedDays = 120;

/// Made-up statistics for the debug menu (ADR 0009 п. 8): [seedDays] days up
/// to [today] over [bookIds] (none — book 0), the same every time. By eye
/// 180–260 words a minute; speed reading grows from 300 to 420; backs and
/// pauses jump above 400; some days are skipped; all four modes.
({List<ReadingDelta> reading, List<PaceDelta> pace}) seedStats({
  required DateTime today,
  required List<int> bookIds,
}) {
  final random = Random(13);
  final books = bookIds.isEmpty ? const [0] : bookIds;
  int between(int low, int high) => low + random.nextInt(high - low + 1);

  final reading = <ReadingDelta>[];
  final pace = <PaceDelta>[];
  for (var i = 0; i < seedDays; i++) {
    final date = DateTime(
      today.year,
      today.month,
      today.day - seedDays + 1 + i,
    );
    if (random.nextDouble() < 0.25) continue;
    final day = dayKey(date);
    final bookId = books[i ~/ 10 % books.length];
    final dayPart = random.nextInt(4);

    final eyeWpm = between(180, 260);
    final eyeMinutes = between(5, 40);
    final eyeWords = eyeMinutes * eyeWpm;
    final speeds = <int, int>{};
    for (var p = 0; p < eyeWords ~/ 250; p++) {
      final bucket = speedBucket((eyeWpm + between(-30, 30)).toDouble());
      speeds[bucket] = (speeds[bucket] ?? 0) + 1;
    }
    reading.add(
      ReadingDelta(
        day: day,
        bookId: bookId,
        mode: ReadingMode.page,
        dayPart: dayPart,
        activeMs: eyeMinutes * 60000,
        words: eyeWords,
        pageSpeeds: speeds,
      ),
    );

    if (random.nextDouble() < 0.2) continue;
    final mode = switch (random.nextDouble()) {
      < 0.6 => SpeedMode.word,
      < 0.85 => SpeedMode.phrase,
      _ => SpeedMode.guide,
    };
    final grown = 300 + 120 * i ~/ (seedDays - 1);
    final setWpm = ((grown + between(-50, 100)) / 25).round() * 25;
    final minutes = between(5, 25);
    // Pauses on punctuation and the start: a bit under the set pace.
    final words = minutes * setWpm * 9 ~/ 10;
    final perHundred = setWpm <= 400
        ? 0.8 + random.nextDouble() * 0.8
        : 1.5 + (setWpm - 400) / 20;
    final signals = (words * perHundred / 100).round();
    final backs = signals * 2 ~/ 3;
    reading.add(
      ReadingDelta(
        day: day,
        bookId: bookId,
        mode: ReadingMode.ofSpeed(mode),
        dayPart: dayPart,
        activeMs: minutes * 60000,
        words: words,
      ),
    );
    pace.add(
      PaceDelta(
        day: day,
        mode: mode,
        wpm: setWpm,
        words: words,
        activeMs: minutes * 60000,
        backs: backs,
        pauses: signals - backs,
      ),
    );
  }
  return (reading: reading, pace: pace);
}

/// Replaces all statistics with [seedStats].
Future<void> fillWithSeed(
  StatsRepository stats, {
  required DateTime today,
  required List<int> bookIds,
}) async {
  final (:reading, :pace) = seedStats(today: today, bookIds: bookIds);
  await stats.clear();
  await stats.add(reading: reading, pace: pace);
}
