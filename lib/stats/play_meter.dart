import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/stats_buffer.dart';
import 'package:book_app/stats/stats_records.dart';

/// Time, words and signals of understanding in speed reading (ADR 0009
/// п. 4). Time runs only between [play] and [pause] / [stop]; words are the
/// growth of the word index while playing.
final class PlayMeter {
  PlayMeter({
    required this.bookId,
    required this._mode,
    required this._wpm,
    required int wordIndex,
    required this._buffer,
    required this._now,
  }) : _last = wordIndex;

  final int bookId;
  final StatsBuffer _buffer;
  final DateTime Function() _now;
  SpeedMode _mode;
  int _wpm;
  int _last;
  DateTime? _since;

  /// The pace of a pause by the reader; it is a signal only once reading
  /// goes on.
  (SpeedMode, int)? _userPause;

  bool get playing => _since != null;

  SpeedMode get mode => _mode;
  set mode(SpeedMode value) {
    if (value == _mode) return;
    _credit(0);
    _mode = value;
  }

  int get wpm => _wpm;
  set wpm(int value) {
    if (value == _wpm) return;
    _credit(0);
    _wpm = value;
  }

  /// Reading starts or goes on; a pause by the reader before it counts.
  void play() {
    if (playing) return;
    if (_userPause case (final mode, final wpm)) {
      _addPace(mode, wpm, pauses: 1);
      _userPause = null;
    }
    _since = _now();
  }

  /// The engine moved to [wordIndex] while playing.
  void advance(int wordIndex) {
    if (!playing) {
      _last = wordIndex;
      return;
    }
    final words = wordIndex > _last ? wordIndex - _last : 0;
    _last = wordIndex;
    _credit(words);
  }

  /// A pause by the reader.
  void pause() {
    if (!playing) return;
    _credit(0);
    _since = null;
    _userPause = (_mode, _wpm);
  }

  /// Not the reader's choice (chapter end, picture, exit, hidden app):
  /// time stops, and a pause before it is no signal.
  void stop() {
    if (playing) _credit(0);
    _since = null;
    _userPause = null;
  }

  /// The reader went back to [wordIndex]: a signal; words are not taken off.
  void back(int wordIndex) {
    _credit(0);
    _last = wordIndex;
    _addPace(_mode, _wpm, backs: 1);
  }

  /// A jump to [wordIndex] that is neither reading nor going back.
  void seek(int wordIndex) {
    _credit(0);
    _last = wordIndex;
  }

  /// Adds the time since the last credit and [words] to the buffer.
  void _credit(int words) {
    final since = _since;
    if (since == null) return;
    final now = _now();
    final ms = now.difference(since).inMilliseconds;
    _since = now;
    if (ms <= 0 && words == 0) return;
    _buffer
      ..addReading(
        ReadingDelta(
          day: dayKey(now),
          bookId: bookId,
          mode: ReadingMode.ofSpeed(_mode),
          dayPart: dayPartOf(now),
          activeMs: ms,
          words: words,
        ),
      )
      ..addPace(
        PaceDelta(
          day: dayKey(now),
          mode: _mode,
          wpm: _wpm,
          words: words,
          activeMs: ms,
        ),
      );
  }

  void _addPace(SpeedMode mode, int wpm, {int backs = 0, int pauses = 0}) =>
      _buffer.addPace(
        PaceDelta(
          day: dayKey(_now()),
          mode: mode,
          wpm: wpm,
          backs: backs,
          pauses: pauses,
        ),
      );
}
