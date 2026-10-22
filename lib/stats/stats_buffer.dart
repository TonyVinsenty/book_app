import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/stats_records.dart';

/// Counts the meters keep in memory between writes to the base, merged by
/// row key (ADR 0009 п. 2).
final class StatsBuffer {
  StatsBuffer({required DateTime Function() now})
    : _now = now,
      _lastTake = now();

  /// How often the counts go to the base while reading goes on.
  static const flushEvery = Duration(seconds: 30);

  final DateTime Function() _now;
  DateTime _lastTake;
  final _reading = <(int, int, ReadingMode, int), ReadingDelta>{};
  final _pace = <(int, SpeedMode, int), PaceDelta>{};

  bool get isEmpty => _reading.isEmpty && _pace.isEmpty;

  /// Something to write, and [flushEvery] passed since the last [take].
  bool get due => !isEmpty && !_now().isBefore(_lastTake.add(flushEvery));

  void addReading(ReadingDelta d) {
    final key = (d.day, d.bookId, d.mode, d.dayPart);
    final old = _reading[key];
    _reading[key] = old == null
        ? d
        : ReadingDelta(
            day: d.day,
            bookId: d.bookId,
            mode: d.mode,
            dayPart: d.dayPart,
            activeMs: old.activeMs + d.activeMs,
            words: old.words + d.words,
            pageSpeeds: mergeBuckets(old.pageSpeeds, d.pageSpeeds),
          );
  }

  void addPace(PaceDelta d) {
    final key = (d.day, d.mode, d.wpm);
    final old = _pace[key];
    _pace[key] = old == null
        ? d
        : PaceDelta(
            day: d.day,
            mode: d.mode,
            wpm: d.wpm,
            words: old.words + d.words,
            activeMs: old.activeMs + d.activeMs,
            backs: old.backs + d.backs,
            pauses: old.pauses + d.pauses,
          );
  }

  /// Everything gathered since the last take; the buffer is empty after.
  ({List<ReadingDelta> reading, List<PaceDelta> pace}) take() {
    final taken = (
      reading: _reading.values.toList(),
      pace: _pace.values.toList(),
    );
    _reading.clear();
    _pace.clear();
    _lastTake = _now();
    return taken;
  }
}
