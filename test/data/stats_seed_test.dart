import 'package:book_app/data/stats_seed.dart';
import 'package:book_app/stats/stats_calc.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 23);
  final seed = seedStats(today: today, bookIds: [3, 7]);

  test('the same every time, over the given books and days', () {
    final again = seedStats(today: today, bookIds: [3, 7]);
    expect(
      [for (final r in again.reading) (r.day, r.mode, r.words)],
      [for (final r in seed.reading) (r.day, r.mode, r.words)],
    );
    final days = {for (final r in seed.reading) r.day};
    expect(days.length, inInclusiveRange(60, seedDays - 1));
    expect(
      days.reduce((a, b) => a < b ? a : b),
      greaterThanOrEqualTo(20260626),
    );
    expect(days.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(20261023));
    expect({for (final r in seed.reading) r.bookId}, {3, 7});
    expect({for (final r in seed.reading) r.mode}, ReadingMode.values.toSet());
  });

  test('speeds as promised; the comfortable pace is about 400', () {
    final eye = seed.reading.where((r) => r.mode == ReadingMode.page);
    for (final r in eye) {
      expect(r.words * 60000 / r.activeMs, inInclusiveRange(180, 260));
    }
    expect(comfortablePace(seed.pace)?.wpm, inInclusiveRange(350, 400));
  });

  test('no books — book 0', () {
    final none = seedStats(today: today, bookIds: const []);
    expect({for (final r in none.reading) r.bookId}, {0});
  });
}
