import 'package:book_app/stats/stats_records.dart';

/// Pages in a histogram of page speeds (buckets of [speedBucketWpm]).
int pageCount(Map<int, int> buckets) =>
    buckets.values.fold(0, (sum, n) => sum + n);

/// Fewer pages with a speed give no reliable median: "being found out"
/// (ADR 0009 п. 3).
const minPagesForSpeed = 10;

/// The median page speed, words per minute: the middle of the bucket the
/// middle page falls into (the lower one for an even count); null — no pages.
int? medianWpm(Map<int, int> buckets) {
  final total = pageCount(buckets);
  if (total == 0) return null;
  final middle = (total + 1) ~/ 2;
  var seen = 0;
  for (final bucket in buckets.keys.toList()..sort()) {
    seen += buckets[bucket]!;
    if (seen >= middle) return bucket * speedBucketWpm + speedBucketWpm ~/ 2;
  }
  return null;
}
