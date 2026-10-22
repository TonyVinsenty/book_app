import 'package:book_app/stats/stats_calc.dart';
import 'package:book_app/stats/stats_records.dart';

/// Days the reader's own speeds are taken from (ADR 0009 п. 5).
const recentDays = 30;

/// What the reader shows about one book: the line "time left" and the
/// sheet "This book" (ADR 0009 п. 5–6).
final class BookStats {
  const BookStats({
    required this.speed,
    required this.eyeSpeed,
    required this.playSpeed,
    required this.spent,
    required this.saved,
    required this.bookRows,
  });

  /// From all the rows of all books; [setWpmOf] — the set pace of a speed
  /// mode, for a book read mostly in it with too few words for its speed.
  factory BookStats.of(
    int bookId, {
    required List<ReadingDelta> rows,
    required DateTime today,
    required int Function(ReadingMode mode) setWpmOf,
  }) {
    final from = dayKey(
      DateTime(today.year, today.month, today.day - recentDays + 1),
    );
    final recent = rows.where((r) => r.day >= from).toList();
    final bookRows = rows.where((r) => r.bookId == bookId).toList();
    final mode = bookMode(bookRows);
    final page = pageSpeed([pageSpeedsOf(recent), pageSpeedsOf(rows)]);
    return BookStats(
      speed: readingSpeed(
        mode,
        recent: recent,
        all: rows,
        setWpm: mode == ReadingMode.page ? 0 : setWpmOf(mode),
      ),
      eyeSpeed: page,
      playSpeed: playWpm(recent),
      spent: Duration(
        milliseconds: bookRows.fold(0, (sum, r) => sum + r.activeMs),
      ),
      saved: savedTime(bookRows, pageWpm: page.wpm),
      bookRows: bookRows,
    );
  }

  /// The speed time left is counted at: of the mode the book is read in
  /// most.
  final Speed speed;

  /// Reading by eye, over [recentDays], else all time.
  final Speed eyeSpeed;

  /// Speed reading in all its modes over [recentDays]; null — too few words.
  final int? playSpeed;

  /// Time spent on this book in all modes.
  final Duration spent;

  /// What speed reading saved on this book.
  final SavedTime saved;

  final List<ReadingDelta> bookRows;

  /// How long [words] take at [speed].
  Duration left(int words) => timeLeft(words, speed.wpm);

  /// The likely day the book is finished, [words] before its end.
  DateTime? finishOn(int words, DateTime today) =>
      finishDate(left(words), bookRows: bookRows, today: today);
}
