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
    this.rampWords = 10,
  }) : assert(wordCount > 0),
       _word = startWord.clamp(0, wordCount - 1);

  final int wordCount;
  WordTiming timing;

  /// Gentle start: after [play] the speed grows from [rampFrom] of the set
  /// one to full over this many words (ADR 0004 п. 4); 0 turns it off.
  final int rampWords;
  static const rampFrom = 0.6;

  int _word;
  bool _playing = false;
  bool _finished = false;

  /// Time the current word has been shown while playing.
  Duration _shown = Duration.zero;

  /// Words shown since the last [play], for the gentle start.
  int _sincePlay = 0;

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
    _sincePlay = 0;
  }

  void pause() => _playing = false;

  /// Jumps to [word] (e.g. back by a sentence); it is shown in full, and a
  /// playing engine starts gently again.
  void seek(int word) {
    _word = word.clamp(0, wordCount - 1);
    _finished = false;
    _shown = Duration.zero;
    _sincePlay = 0;
  }

  void toggle() => _playing ? pause() : play();

  /// Moves time on by [elapsed]; true if the word on screen changed.
  bool advance(Duration elapsed) {
    if (!_playing) return false;
    final before = _word;
    _shown += elapsed;
    while (_playing) {
      final duration = _durationOf(_word);
      if (_shown < duration) break;
      _shown -= duration;
      if (_word + 1 < wordCount) {
        _word++;
        _sincePlay++;
      } else {
        _playing = false;
        _finished = true;
      }
    }
    return _word != before;
  }

  Duration _durationOf(int word) {
    final duration = timing.durationOf(word);
    if (_sincePlay >= rampWords) return duration;
    final speed = rampFrom + (1 - rampFrom) * _sincePlay / rampWords;
    return duration * (1 / speed);
  }
}
