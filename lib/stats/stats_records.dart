import 'package:book_app/speed/speed_mode.dart';

/// How words were read: the page by eye or one of the speed modes
/// (ADR 0009 п. 2).
enum ReadingMode {
  page,
  word,
  phrase,
  guide;

  static ReadingMode ofSpeed(SpeedMode mode) => switch (mode) {
    SpeedMode.word => word,
    SpeedMode.phrase => phrase,
    SpeedMode.guide => guide,
  };
}

/// The local date as `yyyymmdd`: a day ends at midnight.
int dayKey(DateTime time) => time.year * 10000 + time.month * 100 + time.day;

/// The date of a [dayKey], at midnight.
DateTime dayOfKey(int key) =>
    DateTime(key ~/ 10000, key ~/ 100 % 100, key % 100);

/// 0 morning (5–12 h), 1 afternoon (12–17), 2 evening (17–23), 3 night.
int dayPartOf(DateTime time) => switch (time.hour) {
  >= 5 && < 12 => 0,
  >= 12 && < 17 => 1,
  >= 17 && < 23 => 2,
  _ => 3,
};

/// Width of a page speed bucket, words per minute; buckets cover 0–3000.
const speedBucketWpm = 10;
const maxBucket = 3000 ~/ speedBucketWpm;

/// The bucket of a page read at [wpm]; faster than 3000 goes to the last one.
int speedBucket(double wpm) =>
    (wpm / speedBucketWpm).floor().clamp(0, maxBucket);

/// Page counts by speed bucket, summed key by key.
Map<int, int> mergeBuckets(Map<int, int> a, Map<int, int> b) => {
  ...a,
  for (final MapEntry(:key, :value) in b.entries) key: (a[key] ?? 0) + value,
};

/// Reading to add to one `reading_days` row.
final class ReadingDelta {
  const ReadingDelta({
    required this.day,
    required this.bookId,
    required this.mode,
    required this.dayPart,
    this.activeMs = 0,
    this.words = 0,
    this.pageSpeeds = const {},
  });

  final int day;
  final int bookId;
  final ReadingMode mode;
  final int dayPart;
  final int activeMs;
  final int words;

  /// Only for [ReadingMode.page]: pages by [speedBucket].
  final Map<int, int> pageSpeeds;
}

/// Speed reading to add to one `pace_days` row: words, time and the signals
/// of understanding at the set pace [wpm].
final class PaceDelta {
  const PaceDelta({
    required this.day,
    required this.mode,
    required this.wpm,
    this.words = 0,
    this.activeMs = 0,
    this.backs = 0,
    this.pauses = 0,
  });

  final int day;
  final SpeedMode mode;
  final int wpm;
  final int words;
  final int activeMs;
  final int backs;
  final int pauses;
}
