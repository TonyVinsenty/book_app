import 'package:book_app/speed/timing.dart';

/// One word at a time (RSVP, ADR 0004). Time comes from outside: the screen
/// feeds frame time into [advance] (a `Ticker`), tests feed a fake clock.
/// Elapsed time accumulates across words, so the pace does not drift even
/// when a word lasts only a few frames.
final class RsvpEngine {
  RsvpEngine({
    required this.wordCount,
    required int startWord,
    required this.timing,
  }) : assert(wordCount > 0),
       _word = startWord.clamp(0, wordCount - 1);

  final int wordCount;
  WordTiming timing;

  int _word;
  bool _playing = false;
  bool _finished = false;

  /// Time the current word has been shown while playing.
  Duration _shown = Duration.zero;

  /// The word on screen (`wordIndex`).
  int get wordIndex => _word;
  bool get isPlaying => _playing;

  /// The last word has been shown for its full time.
  bool get isFinished => _finished;

  /// Starts or continues; the current word is shown again for its full time.
  void play() {
    if (_finished) return;
    _playing = true;
    _shown = Duration.zero;
  }

  void pause() => _playing = false;

  void toggle() => _playing ? pause() : play();

  /// Moves time on by [elapsed]; true if the word on screen changed.
  bool advance(Duration elapsed) {
    if (!_playing) return false;
    final before = _word;
    _shown += elapsed;
    while (_playing) {
      final duration = timing.durationOf(_word);
      if (_shown < duration) break;
      _shown -= duration;
      if (_word + 1 < wordCount) {
        _word++;
      } else {
        _playing = false;
        _finished = true;
      }
    }
    return _word != before;
  }
}
