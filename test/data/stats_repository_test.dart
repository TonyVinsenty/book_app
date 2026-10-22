import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/stats_repository.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late StatsRepository stats;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    stats = StatsRepository(db);
  });

  tearDown(() => db.close());

  ReadingDelta page(
    int day, {
    int bookId = 1,
    int dayPart = 2,
    int ms = 0,
    int words = 0,
    Map<int, int> speeds = const {},
  }) => ReadingDelta(
    day: day,
    bookId: bookId,
    mode: ReadingMode.page,
    dayPart: dayPart,
    activeMs: ms,
    words: words,
    pageSpeeds: speeds,
  );

  test('adds to the same row and merges page speeds', () async {
    await stats.add(
      reading: [
        page(20261023, ms: 60000, words: 250, speeds: {23: 1, 25: 2}),
      ],
    );
    await stats.add(
      reading: [
        page(20261023, ms: 30000, words: 120, speeds: {25: 1, 30: 4}),
      ],
    );

    final row = (await stats.readingDays()).single;
    expect((row.activeMs, row.words), (90000, 370));
    expect(row.pageSpeedHist, {23: 1, 25: 3, 30: 4});
  });

  test('duplicate keys in one call are summed too', () async {
    await stats.add(
      reading: [
        page(20261023, ms: 1000, words: 5),
        page(20261023, ms: 2000, words: 7),
      ],
    );

    final row = (await stats.readingDays()).single;
    expect((row.activeMs, row.words), (3000, 12));
  });

  test('each part of the key makes its own row', () async {
    await stats.add(
      reading: [
        page(20261023),
        page(20261024),
        page(20261023, bookId: 2),
        page(20261023, dayPart: 0),
        const ReadingDelta(
          day: 20261023,
          bookId: 1,
          mode: ReadingMode.guide,
          dayPart: 2,
        ),
      ],
    );

    expect(await stats.readingDays(), hasLength(5));
  });

  test('pace rows sum words, time, backs and pauses per set pace', () async {
    const day = 20261023;
    await stats.add(
      pace: [
        const PaceDelta(
          day: day,
          mode: SpeedMode.word,
          wpm: 350,
          words: 700,
          activeMs: 120000,
          backs: 1,
        ),
        const PaceDelta(
          day: day,
          mode: SpeedMode.word,
          wpm: 350,
          words: 300,
          activeMs: 50000,
          pauses: 2,
        ),
        const PaceDelta(day: day, mode: SpeedMode.word, wpm: 400, words: 10),
        const PaceDelta(day: day, mode: SpeedMode.phrase, wpm: 350, words: 1),
      ],
    );

    final word = await stats.paceDays(mode: SpeedMode.word);
    expect([for (final r in word) r.wpm], unorderedEquals([350, 400]));
    final at350 = word.firstWhere((r) => r.wpm == 350);
    expect(
      (at350.words, at350.activeMs, at350.backs, at350.pauses),
      (1000, 170000, 1, 2),
    );
    expect(await stats.paceDays(), hasLength(3));
  });

  test('reading days by period and by book, oldest first', () async {
    await stats.add(
      reading: [
        page(20261025),
        page(20261020, bookId: 2),
        page(20261022),
        page(20261101),
      ],
    );

    final october = await stats.readingDays(fromDay: 20261020, toDay: 20261031);
    expect([for (final r in october) r.day], [20261020, 20261022, 20261025]);
    final book1 = await stats.readingDays(bookId: 1);
    expect([for (final r in book1) r.day], [20261022, 20261025, 20261101]);
  });

  test('a failing write leaves nothing behind', () async {
    await stats.add(reading: [page(20261023, words: 10)]);
    await expectLater(
      db.transaction(() async {
        await stats.add(reading: [page(20261023, words: 5)]);
        throw StateError('crash');
      }),
      throwsStateError,
    );

    expect((await stats.readingDays()).single.words, 10);
  });

  test('clear forgets everything', () async {
    await stats.add(
      reading: [page(20261023)],
      pace: [const PaceDelta(day: 20261023, mode: SpeedMode.word, wpm: 300)],
    );
    await stats.clear();

    expect(await stats.readingDays(), isEmpty);
    expect(await stats.paceDays(), isEmpty);
  });

  group('records', () {
    test('day key and back', () {
      expect(dayKey(DateTime(2026, 3, 7, 23, 59)), 20260307);
      expect(dayOfKey(20260307), DateTime(2026, 3, 7));
    });

    test('parts of the day', () {
      int part(int hour) => dayPartOf(DateTime(2026, 1, 1, hour));
      expect(
        [
          for (final h in [4, 5, 11, 12, 16, 17, 22, 23, 0]) part(h),
        ],
        [3, 0, 0, 1, 1, 2, 2, 3, 3],
      );
    });

    test('speed buckets of 10 wpm, capped at 3000', () {
      expect(speedBucket(0), 0);
      expect(speedBucket(239.9), 23);
      expect(speedBucket(240), 24);
      expect(speedBucket(5000), 300);
    });

    test('speed modes map to reading modes', () {
      expect(
        [for (final m in SpeedMode.values) ReadingMode.ofSpeed(m).name],
        [for (final m in SpeedMode.values) m.name],
      );
    });
  });
}
