import 'package:book_app/speed/guide.dart';
import 'package:book_app/speed/timing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pages starting at [starts] (sorted, first is 0), the last up to [words].
final class FakePages {
  FakePages(this.starts, this.words);

  List<int> starts;
  final int words;
  int asked = 0;

  GuidePage pageOf(int word) {
    asked++;
    var i = starts.length - 1;
    while (starts[i] > word) {
      i--;
    }
    return (
      first: starts[i],
      end: i + 1 < starts.length ? starts[i + 1] : words,
    );
  }
}

const ms = Duration(milliseconds: 1);
const frame = Duration(microseconds: 16667);

void main() {
  // 600 wpm: 100 ms a word, the first word of a page 180 ms.
  GuideSession session(
    FakePages pages, {
    int start = 0,
    Set<int> chapters = const {},
  }) => GuideSession(
    wordCount: pages.words,
    startWord: start,
    timing: const ConstantPace(600),
    pageOf: pages.pageOf,
    stopBefore: chapters.contains,
    rampWords: 0,
  );

  /// Plays to the end with a frame clock; every page shown, in order.
  List<GuidePage> playAll(GuideSession guide) {
    final shown = [guide.page];
    guide.play();
    for (var i = 0; i < 100000 && !guide.isFinished; i++) {
      if (guide.isStopped) guide.play();
      if (guide.advance(frame) == GuideChange.page) shown.add(guide.page);
    }
    return shown;
  }

  test('turns the page right after its last word', () {
    final guide = session(FakePages([0, 10, 20], 30))..play();
    expect(guide.advance(ms * 1079), GuideChange.word);
    expect((guide.word, guide.page), (9, (first: 0, end: 10)));
    expect(guide.advance(ms), GuideChange.page);
    expect((guide.word, guide.page), (10, (first: 10, end: 20)));
  });

  test('the first word of a page lasts pageStart times longer', () {
    expect(PaceRules.pageStart, greaterThan(1));
    final guide = session(FakePages([0, 10], 20), start: 10)..play();
    expect(guide.advance(ms * 179), GuideChange.none);
    expect(guide.advance(ms), GuideChange.word);
    expect(guide.word, 11);
    expect(guide.advance(ms * 99), GuideChange.none);
    expect(guide.advance(ms), GuideChange.word);
  });

  test('shifted and uneven pages: every page once, in order', () {
    final pages = FakePages([0, 7, 15, 16, 26, 40, 41, 55], 60);
    final shown = playAll(session(pages));
    expect(shown.map((p) => p.first), pages.starts);
    expect(shown.last.end, 60);
  });

  test('parts of a long chapter: no stop, a new chapter: pause', () {
    // Parts of one chapter start at 30 and 60, a new chapter at 90.
    final pages = FakePages([0, 15, 30, 45, 60, 75, 90, 105], 120);
    final guide = session(pages, chapters: {90})..play();
    final stops = <int>[];
    for (var i = 0; i < 10000 && !guide.isFinished; i++) {
      guide.advance(frame);
      if (guide.isStopped) {
        stops.add(guide.word);
        expect(guide.page, (first: 90, end: 105));
        expect(guide.isPlaying, isFalse);
        expect(guide.advance(frame), GuideChange.none);
        guide.play();
      }
    }
    expect(stops, [90]);
    expect(guide.isFinished, isTrue);
  });

  test('end of the book: finished on the last word and page', () {
    final guide = session(FakePages([0, 10], 15), start: 12)..play();
    guide.advance(const Duration(seconds: 5));
    expect(guide.isFinished, isTrue);
    expect(guide.isPlaying, isFalse);
    expect((guide.word, guide.page), (14, (first: 10, end: 15)));
    guide.play();
    expect(guide.isPlaying, isFalse);
  });

  test('a page turned on a pause: goes on from its first word', () {
    final guide = session(FakePages([0, 10, 20, 30], 40), start: 5)..play();
    guide
      ..advance(ms * 250)
      ..pause();
    expect(guide.word, 7);
    guide
      ..pageTurned(20)
      ..play();
    expect((guide.word, guide.page), (20, (first: 20, end: 30)));
  });

  test('turned away and back on a pause: goes on from the word', () {
    final guide = session(FakePages([0, 10, 20], 30), start: 5)
      ..pageTurned(10)
      ..pageTurned(3)
      ..play();
    expect((guide.word, guide.page), (5, (first: 0, end: 10)));
  });

  test('seek shows the page of the word', () {
    final guide = session(FakePages([0, 10, 20], 30))..seek(23);
    expect((guide.word, guide.page), (23, (first: 20, end: 30)));
  });

  test('relayout keeps the word, takes its new page', () {
    final pages = FakePages([0, 10, 20], 30);
    final guide = session(pages, start: 12);
    pages.starts = [0, 6, 12, 18, 24];
    guide.relayout();
    expect((guide.word, guide.page), (12, (first: 12, end: 18)));
    // Word 12 is now the first of a page: it lasts longer.
    guide.play();
    expect(guide.advance(ms * 179), GuideChange.none);
    expect(guide.advance(ms), GuideChange.word);
  });

  test('a new speed applies; pages are not searched every frame', () {
    final pages = FakePages([0, 100], 200);
    final guide = session(pages, start: 1)
      ..timing = const ConstantPace(300)
      ..play();
    expect(guide.advance(ms * 199), GuideChange.none);
    expect(guide.advance(ms), GuideChange.word);
    pages.asked = 0;
    for (var i = 0; i < 300; i++) {
      guide.advance(frame);
    }
    expect(pages.asked, lessThan(5));
  });
}
