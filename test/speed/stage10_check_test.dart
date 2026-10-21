import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/section_parts.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/token.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/speed/guide.dart';
import 'package:book_app/speed/phrases.dart';
import 'package:book_app/speed/rsvp_engine.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/speed/steps.dart';
import 'package:book_app/speed/timing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../layout/sample_book.dart';

const _frame = Duration(microseconds: 16667);

/// Pages of [size] words over [words] words.
GuidePage Function(int) _pagesOf(int size, int words) =>
    (word) => (
      first: word - word % size,
      end: (word - word % size + size).clamp(0, words),
    );

BookTokens _text(List<String> paragraphs) => tokenize(
  BookContent(
    meta: const BookMeta(title: 't', sourceFormat: SourceFormat.txt),
    sections: [
      Section(blocks: [for (final p in paragraphs) ParagraphBlock(text: p)]),
    ],
  ),
);

void main() {
  group('one chapter in three modes at 300 wpm', () {
    final tokens = tokenize(sampleBook(sections: 1, paragraphs: 60));
    final words = tokens.length;
    final pace = SmartPace(tokens, 300);
    // Nominal time of the chapter: words / wpm.
    final nominal = Duration(
      microseconds: words * Duration.microsecondsPerMinute ~/ 300,
    );

    /// Time to the end with a frame clock.
    Duration runToEnd(void Function(Duration) advance, bool Function() done) {
      var now = Duration.zero;
      while (!done() && now < nominal * 3) {
        now += _frame;
        advance(_frame);
      }
      return now;
    }

    test('word engine: words / speed', () {
      final engine = RsvpEngine(
        wordCount: words,
        startWord: 0,
        timing: pace,
        rampWords: 0,
      )..play();
      final t = runToEnd(engine.advance, () => engine.isFinished);
      expect(engine.isFinished, isTrue);
      expect(t.inMicroseconds / nominal.inMicroseconds, closeTo(1, 0.005));
    });

    test('phrase engine: the same time as words', () {
      final engine = RsvpEngine(
        wordCount: words,
        startWord: 0,
        timing: pace,
        rampWords: 0,
        steps: PhraseSteps(tokens),
      )..play();
      final t = runToEnd(engine.advance, () => engine.isFinished);
      expect(engine.isFinished, isTrue);
      expect(t.inMicroseconds / nominal.inMicroseconds, closeTo(1, 0.005));
    });

    test('guide: words / speed plus the page-start pauses', () {
      const pageSize = 120;
      var extra = Duration.zero;
      for (var w = 0; w < words; w += pageSize) {
        extra += pace.durationOf(w) * (PaceRules.pageStart - 1);
      }
      final guide = GuideSession(
        wordCount: words,
        startWord: 0,
        timing: pace,
        pageOf: _pagesOf(pageSize, words),
        rampWords: 0,
      )..play();
      final t = runToEnd(guide.advance, () => guide.isFinished);
      expect(guide.isFinished, isTrue);
      final expected = nominal + extra;
      expect(t.inMicroseconds / expected.inMicroseconds, closeTo(1, 0.005));
      expect(extra, greaterThan(Duration.zero));
    });
  });

  group('switching keeps the word', () {
    final tokens = tokenize(sampleBook(sections: 1, paragraphs: 30));
    final phrases = PhraseSteps(tokens);

    test('word <-> phrase engine', () {
      final engine = RsvpEngine(
        wordCount: tokens.length,
        startWord: 50,
        timing: SmartPace(tokens, 300),
        rampWords: 0,
      )..steps = phrases;
      expect(engine.wordIndex, phrases.startOf(50));
      expect(engine.unitEnd, greaterThan(50));
      engine
        ..play()
        ..advance(const Duration(seconds: 3))
        ..pause();
      final at = engine.wordIndex;
      engine.steps = const WordSteps();
      expect(engine.wordIndex, at, reason: 'a phrase start is a word');
      expect(engine.unitEnd, at + 1);
    });

    test('RSVP -> guide -> RSVP: the word is passed as it is', () {
      final rsvp = RsvpEngine(
        wordCount: tokens.length,
        startWord: 200,
        timing: SmartPace(tokens, 300),
        rampWords: 0,
        steps: phrases,
      )..play();
      rsvp.advance(const Duration(seconds: 5));
      final word = rsvp.wordIndex;
      final guide = GuideSession(
        wordCount: tokens.length,
        startWord: word,
        timing: SmartPace(tokens, 250),
        pageOf: _pagesOf(100, tokens.length),
      );
      expect(guide.word, word);
      guide
        ..play()
        ..advance(const Duration(seconds: 4))
        ..pause();
      final back = RsvpEngine(
        wordCount: tokens.length,
        startWord: guide.word,
        timing: SmartPace(tokens, 300),
        steps: phrases,
      );
      expect(back.wordIndex, phrases.startOf(guide.word));
      expect(back.unitEnd, greaterThan(guide.word));
    });
  });

  group('a book of 500k words in one chapter', () {
    late BookTokens tokens;
    setUpAll(() {
      final paragraph = ParagraphBlock(
        text: List.generate(
          100,
          (i) => i % 20 == 19 ? 'конец.' : (i % 9 == 8 ? 'слово,' : 'слово'),
        ).join(' '),
      );
      final content = BookContent(
        meta: const BookMeta(title: 'huge', sourceFormat: SourceFormat.txt),
        sections: [
          Section(
            title: 'Одна',
            blocks: [for (var i = 0; i < 5000; i++) paragraph],
          ),
        ],
      );
      final watch = Stopwatch()..start();
      tokens = tokenize(splitLongSections(content));
      // ignore: avoid_print
      print(
        'tokenize+split: ${tokens.length} words, '
        '${watch.elapsedMilliseconds} ms, '
        '${tokens.content.sections.length} parts',
      );
    });

    test('is one chapter in many parts', () {
      expect(tokens.length, 500000);
      expect(tokens.content.sections.length, greaterThan(5));
      final starts = [
        for (var w = 0; w < tokens.length; w++)
          if (tokens.flagsOf(w) & TokenFlags.sectionStart != 0) w,
      ];
      expect(starts, [0]);
    });

    test('phrase splitting of the whole book is fast', () {
      final watch = Stopwatch()..start();
      final steps = PhraseSteps(tokens);
      var count = 0;
      for (var i = 0; i < tokens.length; i = steps.endOf(i)) {
        count++;
      }
      watch.stop();
      // ignore: avoid_print
      print('PhraseSteps: $count phrases, ${watch.elapsedMilliseconds} ms');
      expect(count, lessThan(tokens.length));
      expect(watch.elapsedMilliseconds, lessThan(3000));
    });

    test('the guide goes through all parts without stopping', () {
      final guide = GuideSession(
        wordCount: tokens.length,
        startWord: 0,
        timing: SmartPace(tokens, SpeedLimits.max),
        pageOf: _pagesOf(250, tokens.length),
        stopBefore: (w) => tokens.flagsOf(w) & TokenFlags.sectionStart != 0,
      )..play();
      var stops = 0;
      var pages = 0;
      var frames = 0;
      final watch = Stopwatch()..start();
      // 500k words at 1000 wpm: 30000 s; a bigger frame keeps it quick.
      const big = Duration(milliseconds: 100);
      while (!guide.isFinished && frames++ < 1000000) {
        if (guide.advance(big) == GuideChange.page) pages++;
        if (guide.isStopped) {
          stops++;
          guide.play();
        }
      }
      expect(guide.isFinished, isTrue);
      expect(stops, 0);
      expect(pages, greaterThan(1900));
      // ignore: avoid_print
      print('guide over 500k: $frames frames, ${watch.elapsedMilliseconds} ms');
    });

    test('stops only before a new chapter', () {
      final other = tokenize(
        BookContent(
          meta: tokens.content.meta,
          sections: [
            ...tokens.content.sections.take(3),
            const Section(blocks: [ParagraphBlock(text: 'Новая глава слово')]),
          ],
        ),
      );
      final chapterStart = other.length - 3;
      expect(other.flagsOf(chapterStart) & TokenFlags.sectionStart, isNot(0));
      final guide = GuideSession(
        wordCount: other.length,
        startWord: chapterStart - 2,
        timing: const ConstantPace(1000),
        pageOf: _pagesOf(50, other.length),
        stopBefore: (w) => other.flagsOf(w) & TokenFlags.sectionStart != 0,
      )..play();
      for (var i = 0; i < 100 && guide.isPlaying; i++) {
        guide.advance(_frame * 3);
      }
      expect((guide.isStopped, guide.word), (true, chapterStart));
    });
  });

  group('stale page cache after layout changes', () {
    test('turning back and forward on a pause: first word gets pageStart', () {
      // Shifted layout of the section: pages start at 0, 13, 23, 33.
      var starts = [0, 13, 23, 33];
      const total = 43;
      GuidePage pageOf(int word) {
        var i = starts.length - 1;
        while (starts[i] > word) {
          i--;
        }
        return (
          first: starts[i],
          end: i + 1 < starts.length ? starts[i + 1] : total,
        );
      }

      final guide = GuideSession(
        wordCount: total,
        startWord: 16,
        timing: const ConstantPace(600),
        pageOf: pageOf,
        rampWords: 0,
      )..play();
      guide
        ..advance(const Duration(milliseconds: 250))
        ..pause();
      // Leaving the section unshifts it (relayout), then pages turn.
      starts = [0, 10, 20, 30, 40];
      guide
        ..relayout()
        ..pageTurned(0)
        ..pageTurned(20)
        ..pageTurned(30)
        ..play();
      expect(guide.word, 30);
      const ms = Duration(milliseconds: 1);
      expect(guide.advance(ms * 179), GuideChange.none);
      expect(guide.advance(ms), GuideChange.word);
      // The second word: plain 100 ms.
      expect(guide.advance(ms * 99), GuideChange.none);
      expect(guide.advance(ms), GuideChange.word);
    });
  });

  group('phrases in English', () {
    List<String> phrasesOf(String text, {int maxChars = 18}) {
      final tokens = _text([text]);
      final steps = PhraseSteps(tokens, maxChars: maxChars);
      return [
        for (var i = 0; i < tokens.length; i = steps.endOf(i))
          [for (var w = i; w < steps.endOf(i); w++) tokens.textOf(w)].join(' '),
      ];
    }

    test('function words stick forward', () {
      final out = phrasesOf(
        'She walked to the end of the old road and looked at the sea.',
      );
      const service = {'a', 'an', 'the', 'of', 'to', 'in', 'and', 'on', 'at'};
      for (final p in out) {
        final last = p.split(' ').last.toLowerCase();
        expect(service.contains(last), isFalse, reason: 'phrase "$p": $out');
      }
    });

    test('a hyphenated word is one word', () {
      final tokens = _text(['Это кто-нибудь из давно-забытых друзей.']);
      final texts = [for (var i = 0; i < tokens.length; i++) tokens.textOf(i)];
      expect(texts, containsAll(['кто-нибудь', 'давно-забытых']));
    });
  });

  group('without Pro', () {
    test('phrase and guide fall back to the word mode', () {
      expect(SpeedMode.phrase.availableWith(pro: false), SpeedMode.word);
      expect(SpeedMode.guide.availableWith(pro: false), SpeedMode.word);
      expect(SpeedMode.word.availableWith(pro: false), SpeedMode.word);
      expect(SpeedMode.guide.availableWith(pro: true), SpeedMode.guide);
    });
  });
}
