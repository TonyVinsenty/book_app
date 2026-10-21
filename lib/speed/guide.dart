import 'package:book_app/speed/rsvp_engine.dart';
import 'package:book_app/speed/timing.dart';

/// Words of one page: [first]..[end] (end not included).
typedef GuidePage = ({int first, int end});

/// What one [GuideSession.advance] changed.
enum GuideChange { none, word, page }

/// The guide (ADR 0004, addendum for stage 10 п. 6–8): a highlight goes
/// word by word over the reader's page and turns it right after the last
/// word. Pure Dart: pages come from [pageOf] (the reader asks its layouts,
/// normal or shifted, laying out a section if needed), time from outside, as
/// in [RsvpEngine].
final class GuideSession {
  GuideSession({
    required int wordCount,
    required int startWord,
    required WordTiming timing,
    required this.pageOf,
    bool Function(int word)? stopBefore,
    int rampWords = 10,
  }) : _wordCount = wordCount,
       _timing = _PageTiming(timing, pageOf) {
    _engine = RsvpEngine(
      wordCount: wordCount,
      startWord: startWord,
      timing: _timing,
      rampWords: rampWords,
      stopBefore: stopBefore,
    );
    _page = pageOf(_engine.wordIndex);
  }

  /// The page [word] is on.
  final GuidePage Function(int word) pageOf;

  final int _wordCount;
  final _PageTiming _timing;
  late final RsvpEngine _engine;
  late GuidePage _page;

  /// The highlighted word.
  int get word => _engine.wordIndex;

  /// The page shown; on a pause the reader may turn it ([pageTurned]).
  GuidePage get page => _page;

  bool get isPlaying => _engine.isPlaying;

  /// Paused by itself before a new chapter, its first page shown.
  bool get isStopped => _engine.isStopped;

  /// The last word of the book has been shown for its full time.
  bool get isFinished => _engine.isFinished;

  /// New speed; the first word of a page still lasts longer.
  set timing(WordTiming timing) => _timing.base = timing;

  /// Goes on from the highlighted word, or from the first word of the open
  /// page if the reader turned it on a pause.
  void play() {
    if (!_contains(_page, word)) _engine.seek(_page.first);
    _engine.play();
  }

  void pause() => _engine.pause();

  /// Jumps to [word] (long press, back by a sentence) and shows its page.
  void seek(int word) {
    _engine.seek(word);
    _page = pageOf(this.word);
  }

  /// The reader turned the page by hand on a pause: [play] starts there. A
  /// page without words at the book's end has no first word: the last one.
  void pageTurned(int firstWord) =>
      _page = pageOf(firstWord.clamp(0, _wordCount - 1));

  /// Pages were laid out again (font, screen): the same word, its new page.
  void relayout() {
    _timing.forget();
    _page = pageOf(word);
  }

  /// Moves time on by [elapsed]; turns the page once the word leaves it.
  GuideChange advance(Duration elapsed) {
    if (!_engine.advance(elapsed)) return GuideChange.none;
    if (_contains(_page, word)) return GuideChange.word;
    _page = pageOf(word);
    return GuideChange.page;
  }

  static bool _contains(GuidePage page, int word) =>
      word >= page.first && word < page.end;
}

/// [base] times [PaceRules.pageStart] for the first word of a page.
final class _PageTiming implements WordTiming {
  _PageTiming(this.base, this.pageOf);

  WordTiming base;
  final GuidePage Function(int word) pageOf;

  /// Last page asked, so a frame does not search the pages again.
  GuidePage? _last;

  void forget() => _last = null;

  @override
  Duration durationOf(int wordIndex) {
    var page = _last;
    if (page == null || !GuideSession._contains(page, wordIndex)) {
      page = _last = pageOf(wordIndex);
    }
    final duration = base.durationOf(wordIndex);
    return wordIndex == page.first ? duration * PaceRules.pageStart : duration;
  }
}
