import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/speed/phrases.dart';
import 'package:book_app/speed/rsvp_engine.dart';
import 'package:book_app/speed/steps.dart';
import 'package:book_app/speed/timing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../layout/sample_book.dart';

/// Frame times like a `Ticker` gives: [frame] apart, fed to the engine.
final class FakeClock {
  FakeClock(this.engine, {this.frame = const Duration(microseconds: 16667)});

  final RsvpEngine engine;
  final Duration frame;
  Duration now = Duration.zero;

  /// Runs frames for [time]; the words shown, in order, including the first.
  List<int> run(Duration time) {
    final shown = [engine.wordIndex];
    final end = now + time;
    while (now + frame <= end) {
      now += frame;
      if (engine.advance(frame)) shown.add(engine.wordIndex);
    }
    return shown;
  }
}

/// Steps of [size] words: 0–2, 3–5, …
final class Groups implements Steps {
  const Groups(this.size);

  final int size;

  @override
  int startOf(int word) => word - word % size;

  @override
  int endOf(int word) => startOf(word) + size;
}

void main() {
  RsvpEngine engine({
    int words = 1000,
    int start = 0,
    int wpm = 600,
    int ramp = 0,
  }) => RsvpEngine(
    wordCount: words,
    startWord: start,
    timing: ConstantPace(wpm),
    rampWords: ramp,
  );

  test('constant pace: 60000 / wpm ms per word', () {
    expect(
      const ConstantPace(300).durationOf(5),
      const Duration(milliseconds: 200),
    );
    expect(
      const ConstantPace(1000).durationOf(0),
      const Duration(milliseconds: 60),
    );
    expect(SpeedLimits.clamp(5000), SpeedLimits.max);
    expect(SpeedLimits.clamp(10), SpeedLimits.min);
  });

  test('starts paused at the given word, clamped to the book', () {
    expect(engine(start: 7).wordIndex, 7);
    expect(engine(start: 7).isPlaying, isFalse);
    expect(engine(words: 5, start: 99).wordIndex, 4);
    expect(engine(start: -3).wordIndex, 0);
  });

  test('does not move while paused', () {
    final e = engine(start: 3);
    expect(e.advance(const Duration(seconds: 10)), isFalse);
    expect(e.wordIndex, 3);
  });

  test('shows words one by one at a steady pace', () {
    final e = engine()..play();
    // 600 wpm = 100 ms per word: 60 words in 6 s, each shown once.
    final shown = FakeClock(e).run(const Duration(seconds: 6));
    expect(shown, List.generate(shown.length, (i) => i));
    expect(e.wordIndex, inInclusiveRange(59, 60));
  });

  test('no drift at 1000 wpm with 60 Hz frames', () {
    // 60 ms per word is 3.6 frames; rounding to frames must not add up.
    final e = engine(words: 100000, wpm: 1000)..play();
    FakeClock(e).run(const Duration(minutes: 1));
    expect(e.wordIndex, inInclusiveRange(999, 1000));
  });

  test('a long frame moves several words at once', () {
    final e = engine()..play();
    expect(e.advance(const Duration(milliseconds: 350)), isTrue);
    expect(e.wordIndex, 3);
  });

  test('pause keeps the word; play shows it again in full', () {
    final e = engine()..play();
    e.advance(const Duration(milliseconds: 250));
    expect(e.wordIndex, 2);
    e.pause();
    expect(e.advance(const Duration(seconds: 5)), isFalse);
    expect(e.wordIndex, 2);

    e.toggle();
    expect(e.isPlaying, isTrue);
    e.advance(const Duration(milliseconds: 99));
    expect(e.wordIndex, 2, reason: 'shown for full 100 ms after resuming');
    e.advance(const Duration(milliseconds: 1));
    expect(e.wordIndex, 3);
    e.toggle();
    expect(e.isPlaying, isFalse);
  });

  test('a new speed applies from the current word', () {
    final e = engine()..play();
    e.advance(const Duration(milliseconds: 100));
    expect(e.wordIndex, 1);
    e.timing = const ConstantPace(300);
    e.advance(const Duration(milliseconds: 199));
    expect(e.wordIndex, 1);
    e.advance(const Duration(milliseconds: 1));
    expect(e.wordIndex, 2);
  });

  test('stops after the last word', () {
    final e = engine(words: 3, start: 1)..play();
    expect(e.advance(const Duration(milliseconds: 100)), isTrue);
    expect(e.wordIndex, 2);
    expect(e.isFinished, isFalse);
    expect(e.advance(const Duration(seconds: 1)), isFalse);
    expect(e.wordIndex, 2);
    expect(e.isPlaying, isFalse);
    expect(e.isFinished, isTrue);
    e.play();
    expect(e.isPlaying, isFalse, reason: 'nothing left to show');
  });

  test('gentle start: 60% of the speed, full after 10 words', () {
    // 600 wpm: 100 ms per word; the first word lasts 100 / 0.6 ms.
    final e = engine(ramp: 10)..play();
    final clock = FakeClock(e, frame: const Duration(milliseconds: 1));
    expect(clock.run(const Duration(milliseconds: 166)), [0]);
    expect(clock.run(const Duration(milliseconds: 2)), [0, 1]);

    // Words 0..9 take 100 ms / (0.6 + 0.04 k); then 100 ms each.
    final e2 = engine(ramp: 10)..play();
    final clock2 = FakeClock(e2, frame: const Duration(milliseconds: 1));
    var ramp = 0.0;
    for (var k = 0; k < 10; k++) {
      ramp += 100 / (0.6 + 0.04 * k);
    }
    clock2.run(Duration(milliseconds: ramp.ceil() + 1000));
    expect(e2.wordIndex, 20);

    // A pause starts the ramp again.
    e2
      ..pause()
      ..play();
    expect(
      clock2.run(const Duration(milliseconds: 150)).length,
      1,
      reason: 'slow again',
    );
  });

  test('seek jumps, shows the word in full and leaves the end', () {
    final e = engine(words: 3)..play();
    final clock = FakeClock(e, frame: const Duration(milliseconds: 1));
    clock.run(const Duration(seconds: 1));
    expect(e.isFinished, isTrue);

    e
      ..seek(1)
      ..play();
    expect(e.isFinished, isFalse);
    expect(clock.run(const Duration(milliseconds: 99)), [1]);
    expect(clock.run(const Duration(milliseconds: 2)), [1, 2]);
    e.seek(99);
    expect(e.wordIndex, 2);
  });

  test('pauses by itself before a chapter start, then goes on', () {
    final e = RsvpEngine(
      wordCount: 10,
      startWord: 0,
      timing: const ConstantPace(600),
      rampWords: 0,
      stopBefore: (word) => word == 4,
    )..play();
    final clock = FakeClock(e, frame: const Duration(milliseconds: 1));
    expect(clock.run(const Duration(seconds: 2)), [0, 1, 2, 3, 4]);
    expect(e.isPlaying, isFalse);
    expect(e.isStopped, isTrue);
    expect(e.wordIndex, 4, reason: 'the chapter start is next to show');

    e.play();
    expect(e.isStopped, isFalse);
    expect(clock.run(const Duration(milliseconds: 101)), [4, 5]);
  });

  group('phrases', () {
    RsvpEngine phrases({int words = 10, int start = 0, int ramp = 0}) =>
        RsvpEngine(
          wordCount: words,
          startWord: start,
          timing: const ConstantPace(600),
          rampWords: ramp,
          steps: const Groups(3),
        );

    test('a phrase lasts as long as its words together', () {
      final e = phrases()..play();
      expect(e.unitEnd, 3);
      final clock = FakeClock(e, frame: const Duration(milliseconds: 1));
      expect(clock.run(const Duration(milliseconds: 299)), [0]);
      expect(clock.run(const Duration(milliseconds: 2)), [0, 3]);
      expect(e.unitEnd, 6);
    });

    test('start and seek go to the start of the phrase', () {
      expect(phrases(start: 4).wordIndex, 3);
      final e = phrases()..seek(8);
      expect(e.wordIndex, 6);
      e.seek(99);
      expect(e.wordIndex, 9);
      expect(e.unitEnd, 10, reason: 'the last phrase ends with the book');
    });

    test('the last phrase is shown, then the end', () {
      final e = phrases()..play();
      final clock = FakeClock(e, frame: const Duration(milliseconds: 1));
      expect(clock.run(const Duration(seconds: 1)), [0, 3, 6, 9]);
      expect(e.isFinished, isTrue);
    });

    test('gentle start takes as long as for single words', () {
      Duration rampTime(Steps steps) {
        final e = RsvpEngine(
          wordCount: 30,
          startWord: 0,
          timing: const ConstantPace(600),
          steps: steps,
        )..play();
        final clock = FakeClock(e, frame: const Duration(microseconds: 100));
        while (e.wordIndex < 12) {
          clock.run(const Duration(microseconds: 100));
        }
        return clock.now;
      }

      final words = rampTime(const WordSteps());
      final groups = rampTime(const Groups(3));
      expect(
        (groups - words).inMicroseconds.abs(),
        lessThan(200),
        reason: '$words vs $groups',
      );
    });

    test('pauses before a chapter start; switching steps keeps the place', () {
      final e = RsvpEngine(
        wordCount: 12,
        startWord: 0,
        timing: const ConstantPace(600),
        rampWords: 0,
        stopBefore: (word) => word == 6,
        steps: const Groups(3),
      )..play();
      final clock = FakeClock(e, frame: const Duration(milliseconds: 1));
      expect(clock.run(const Duration(seconds: 2)), [0, 3, 6]);
      expect(e.isStopped, isTrue);

      e
        ..seek(7)
        ..steps = const WordSteps();
      expect(e.wordIndex, 6);
      e.steps = const Groups(4);
      expect(e.wordIndex, 4);
    });

    test('a chapter in phrases lasts words / wpm minutes', () {
      final tokens = tokenize(sampleBook(paragraphs: 60));
      for (final wpm in [300, 700]) {
        final e = RsvpEngine(
          wordCount: tokens.length,
          startWord: tokens.firstWordOfSection(1),
          timing: SmartPace(tokens, wpm),
          rampWords: 0,
          stopBefore: (word) => word == tokens.firstWordOfSection(2),
          steps: PhraseSteps(tokens),
        )..play();
        final clock = FakeClock(e, frame: const Duration(milliseconds: 1));
        var shown = 0;
        while (e.isPlaying) {
          shown += clock.run(const Duration(milliseconds: 1)).length - 1;
        }
        final words = tokens.firstWordOfSection(2) - tokens.firstWordOfSection(1);
        final expected = words * 60000 / wpm;
        expect(clock.now.inMilliseconds, closeTo(expected, expected * 0.002 + 2));
        expect(shown, lessThan(words * 0.7), reason: 'phrases, not words');
      }
    });
  });
}
