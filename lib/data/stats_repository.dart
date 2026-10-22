import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/stats_buffer.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:drift/drift.dart';

/// Reading statistics: sums by day (ADR 0009 п. 2). The meters keep their
/// counts in memory and add them here in one go.
final class StatsRepository {
  StatsRepository(this._db);

  final AppDatabase _db;

  /// Adds every delta to its row in one transaction: numbers are summed,
  /// page speeds merged bucket by bucket; a missing row is made.
  Future<void> add({
    Iterable<ReadingDelta> reading = const [],
    Iterable<PaceDelta> pace = const [],
  }) => _db.transaction(() async {
    for (final d in reading) {
      await _addReading(d);
    }
    for (final d in pace) {
      await _addPace(d);
    }
  });

  /// Writes what [buffer] gathered, if anything; it is empty after.
  Future<void> flush(StatsBuffer buffer) {
    if (buffer.isEmpty) return Future.value();
    final (:reading, :pace) = buffer.take();
    return add(reading: reading, pace: pace);
  }

  Future<void> _addReading(ReadingDelta d) async {
    final old =
        await (_db.select(_db.readingDays)..where(
              (r) =>
                  r.day.equals(d.day) &
                  r.bookId.equals(d.bookId) &
                  r.mode.equalsValue(d.mode) &
                  r.dayPart.equals(d.dayPart),
            ))
            .getSingleOrNull();
    await _db
        .into(_db.readingDays)
        .insertOnConflictUpdate(
          ReadingDaysCompanion.insert(
            day: d.day,
            bookId: d.bookId,
            mode: d.mode,
            dayPart: d.dayPart,
            activeMs: (old?.activeMs ?? 0) + d.activeMs,
            words: (old?.words ?? 0) + d.words,
            pageSpeedHist: Value(
              mergeBuckets(old?.pageSpeedHist ?? const {}, d.pageSpeeds),
            ),
          ),
        );
  }

  Future<void> _addPace(PaceDelta d) async {
    final old =
        await (_db.select(_db.paceDays)..where(
              (r) =>
                  r.day.equals(d.day) &
                  r.mode.equalsValue(d.mode) &
                  r.wpm.equals(d.wpm),
            ))
            .getSingleOrNull();
    await _db
        .into(_db.paceDays)
        .insertOnConflictUpdate(
          PaceDaysCompanion.insert(
            day: d.day,
            mode: d.mode,
            wpm: d.wpm,
            words: (old?.words ?? 0) + d.words,
            activeMs: (old?.activeMs ?? 0) + d.activeMs,
            backs: (old?.backs ?? 0) + d.backs,
            pauses: (old?.pauses ?? 0) + d.pauses,
          ),
        );
  }

  /// Reading rows from [fromDay] to [toDay] inclusive (`dayKey`), of one
  /// book if [bookId] is given, oldest first.
  Future<List<ReadingDayRow>> readingDays({
    int? fromDay,
    int? toDay,
    int? bookId,
  }) =>
      (_db.select(_db.readingDays)
            ..where(
              (r) => Expression.and([
                if (fromDay != null) r.day.isBiggerOrEqualValue(fromDay),
                if (toDay != null) r.day.isSmallerOrEqualValue(toDay),
                if (bookId != null) r.bookId.equals(bookId),
              ]),
            )
            ..orderBy([(r) => OrderingTerm.asc(r.day)]))
          .get();

  /// Pace rows from [fromDay] to [toDay] inclusive, of one [mode] if given,
  /// oldest first.
  Future<List<PaceDayRow>> paceDays({
    int? fromDay,
    int? toDay,
    SpeedMode? mode,
  }) =>
      (_db.select(_db.paceDays)
            ..where(
              (r) => Expression.and([
                if (fromDay != null) r.day.isBiggerOrEqualValue(fromDay),
                if (toDay != null) r.day.isSmallerOrEqualValue(toDay),
                if (mode != null) r.mode.equalsValue(mode),
              ]),
            )
            ..orderBy([(r) => OrderingTerm.asc(r.day)]))
          .get();

  /// Forgets all statistics (the debug menu, ADR 0009 п. 8).
  Future<void> clear() => _db.transaction(() async {
    await _db.delete(_db.readingDays).go();
    await _db.delete(_db.paceDays).go();
  });
}
