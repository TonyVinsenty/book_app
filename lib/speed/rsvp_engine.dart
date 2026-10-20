import 'package:book_app/speed/steps.dart';
import 'package:book_app/speed/timing.dart';

/// One word or one phrase at a time (RSVP, ADR 0004; [Steps]). Time comes
/// from outside: the screen
/// feeds frame time into [advance] (a `Ticker`), tests feed a fake clock.
/// Elapsed time accumulates across words, so the pace does not drift even
/// when a word lasts only a few frames.
final class RsvpEngine {
  RsvpEngine({
    required this.wordCount,
    required int startWord,
    required this.timing,
    this.rampWords = 10,
    this.stopBefore,
    Steps steps = const WordSteps(),
  }) : assert(wordCount > 0),
       _steps = steps,
       _word = steps.startOf(startWord.clamp(0, wordCount - 1));

  final int wordCount;
  WordTiming timing;

  /// A phrase lasts as long as its words together, so the shown speed stays
  /// the average one (ADR 0004, addendum for stage 10 п. 4).
  Steps get steps => _steps;
  Steps _steps;

  /// Another way to split the words; goes on from the start of the step the
  /// current word is in, shown in full.
  set steps(Steps steps) {
    _steps = steps;
    _word = steps.startOf(_word);
    _shown = Duration.zero;
  }

  /// Gentle start: after [play] the speed grows from [rampFrom] of the set
  /// one to full over this many words (ADR 0004 п. 4); 0 turns it off.
  final int rampWords;
  static const rampFrom = 0.6;

  /// Words the engine pauses on by itself, before showing them: chapter
  /// starts (ADR 0004 п. 8; a step never crosses them).
  final bool Function(int word)? stopBefore;

  int _word;
  bool _playing = false;
  bool _finished = false;
  bool _stopped = false;

  /// Time the current word has been shown while playing.
  Duration _shown = Duration.zero;

  /// Words shown since the last [play], for the gentle start.
  int _sincePlay = 0;

  /// The (first) word on screen (`wordIndex`).
  int get wordIndex => _word;

  /// The word after the step on screen.
  int get unitEnd => _steps.endOf(_word).clamp(_word + 1, wordCount);
  bool get isPlaying => _playing;

  /// The last word has been shown for its full time.
  bool get isFinished => _finished;

  /// Paused by itself before [wordIndex] (see [stopBefore]); [play] goes on
  /// from that word.
  bool get isStopped => _stopped;

  /// Starts or continues; the current word is shown again for its full time.
  void play() {
    if (_finished) return;
    _playing = true;
    _stopped = false;
    _shown = Duration.zero;
    _sincePlay = 0;
  }

  void pause() => _playing = false;

  /// Jumps to the step of [word] (e.g. back by a sentence); it is shown in
  /// full, and a playing engine starts gently again.
  void seek(int word) {
    _word = _steps.startOf(word.clamp(0, wordCount - 1));
    _finished = false;
    _stopped = false;
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
      final end = unitEnd;
      final duration = _durationOf(_word, end);
      if (_shown < duration) break;
      _shown -= duration;
      if (end < wordCount) {
        _sincePlay += end - _word;
        _word = end;
        if (stopBefore?.call(_word) ?? false) {
          _playing = false;
          _stopped = true;
        }
      } else {
        _playing = false;
        _finished = true;
      }
    }
    return _word != before;
  }

  /// Time of words [start]..[end]; each word of the gentle start is slower.
  Duration _durationOf(int start, int end) {
    var total = Duration.zero;
    for (var word = start; word < end; word++) {
      final duration = timing.durationOf(word);
      final shown = _sincePlay + word - start;
      if (shown >= rampWords) {
        total += duration;
      } else {
        total +=
            duration * (1 / (rampFrom + (1 - rampFrom) * shown / rampWords));
      }
    }
    return total;
  }
}
