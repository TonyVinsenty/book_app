import 'dart:math';

import 'package:book_app/stats/stats_buffer.dart';
import 'package:book_app/stats/stats_records.dart';

/// Time and words of reading the page by eye (ADR 0009 п. 3). The reader
/// opens each page it shows and hides the meter while anything covers the
/// page; time runs only while a page is open and [visible].
final class PageMeter {
  PageMeter({required this.bookId, required this._buffer, required this._now});

  /// Shorter than this is leafing through: the page counts for nothing.
  static const minTime = Duration(seconds: 2);

  /// A page with fewer words (chapter end, picture) gives time and words,
  /// not a speed.
  static const shortPageWords = 20;
  static const shortPageMaxTime = Duration(seconds: 60);

  /// Time over this many expected times is cut: the reader looked away.
  static const cutFactor = 3;
  static const maxTime = Duration(minutes: 10);

  /// The expected speed before the owner has a median.
  static const defaultWpm = 150;

  final int bookId;
  final StatsBuffer _buffer;
  final DateTime Function() _now;

  /// The owner's median page speed, if known: sets the expected time.
  int? medianWpm;

  int? _words;

  /// The page was laid out again while open: its time is not one page's.
  var _relaid = false;
  var _shown = Duration.zero;
  DateTime? _shownSince;
  var _visible = true;

  bool get visible => _visible;
  set visible(bool value) {
    if (value == _visible) return;
    _visible = value;
    if (_words == null) return;
    if (value) {
      _shownSince = _now();
    } else {
      _stopClock();
    }
  }

  /// Closes the page shown before and starts a page of [words] words.
  void open(int words) {
    close();
    _words = words;
    _relaid = false;
    _shown = Duration.zero;
    _shownSince = _visible ? _now() : null;
  }

  /// The open page was laid out again (new font, size or colors) and now
  /// has [words] words: its time goes on, and a new word count gives no
  /// speed. Opens the page if none is open.
  void reopen(int words) {
    final opened = _words;
    if (opened == null) return open(words);
    if (words == opened) return;
    _words = words;
    _relaid = true;
  }

  /// Counts the open page; none is open after. [words] — only so many were
  /// read by eye (speed reading went on from the middle of the page).
  void close({int? words}) {
    final opened = _words;
    if (opened == null) return;
    _stopClock();
    _words = null;
    _count(words == null ? opened : min(words, opened), _shown);
  }

  void _stopClock() {
    final since = _shownSince;
    if (since == null) return;
    _shown += _now().difference(since);
    _shownSince = null;
  }

  void _count(int words, Duration shown) {
    if (shown < minTime) return;
    var time = shown;
    var speeds = const <int, int>{};
    if (words < shortPageWords) {
      if (time > shortPageMaxTime) time = shortPageMaxTime;
    } else {
      final wpm = medianWpm ?? defaultWpm;
      final expectedMs = words * 60000 ~/ wpm;
      final cap = Duration(
        milliseconds: min(expectedMs * cutFactor, maxTime.inMilliseconds),
      );
      if (time > cap) {
        time = cap;
      } else if (!_relaid) {
        speeds = {speedBucket(words * 60000 / time.inMilliseconds): 1};
      }
    }
    final end = _now();
    _buffer.addReading(
      ReadingDelta(
        day: dayKey(end),
        bookId: bookId,
        mode: ReadingMode.page,
        dayPart: dayPartOf(end),
        activeMs: time.inMilliseconds,
        words: words,
        pageSpeeds: speeds,
      ),
    );
  }
}
