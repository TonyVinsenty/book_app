import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/tokenizer/token.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/speed/timing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../layout/sample_book.dart';

void main() {
  test('pace rules: one punctuation pause times the other factors', () {
    const s = TokenFlags.sentenceEnd;
    const c = TokenFlags.clauseEnd;
    const d = TokenFlags.dash;
    const p = TokenFlags.paragraphStart;
    const n = TokenFlags.isNumber;
    final cases = <(int flags, int letters, double expected)>[
      (0, 5, 1),
      (0, 3, 0.9),
      (0, 1, 0.9),
      (0, 8, 1),
      (0, 10, 1.1),
      (0, 30, 1.8),
      (s, 5, 2.2),
      (c, 5, 1.5),
      (d, 5, 1.3),
      (s | c | d, 5, 2.2),
      (c | d, 5, 1.5),
      (p, 5, 1.6),
      (n, 4, 1.3 * 1),
      (n, 2, 1.3 * 0.9),
      (p | s, 12, 1.6 * 2.2 * 1.2),
    ];
    for (final (flags, letters, expected) in cases) {
      expect(
        PaceRules.of(flags, letters),
        closeTo(expected, 1e-9),
        reason: 'flags $flags, $letters letters',
      );
    }
  });

  test('a chapter lasts words / wpm minutes at any speed', () {
    final tokens = tokenize(sampleBook(paragraphs: 60));
    for (final wpm in [300, 500]) {
      final pace = SmartPace(tokens, 300).withSpeed(wpm);
      for (var section = 0; section < 3; section++) {
        final first = tokens.firstWordOfSection(section);
        final end = tokens.firstWordOfSection(section + 1);
        var total = Duration.zero;
        for (var i = first; i < end; i++) {
          total += pace.durationOf(i);
        }
        final expected = (end - first) * 60000 / wpm;
        expect(
          total.inMicroseconds / 1000,
          closeTo(expected, 1),
          reason: 'chapter $section at $wpm wpm',
        );
      }
    }
  });

  test('stops and long words last longer than short plain ones', () {
    final tokens = tokenize(
      BookContent(
        meta: const BookMeta(title: 't', sourceFormat: SourceFormat.txt),
        sections: [
          Section(
            blocks: [
              ParagraphBlock(
                text:
                    'Он шёл, а потом остановился. Достопримечательность ждала',
              ),
            ],
          ),
        ],
      ),
    );
    final pace = SmartPace(tokens, 300);
    final ms = [
      for (var i = 0; i < tokens.length; i++)
        pace.durationOf(i).inMicroseconds / 1000,
    ];
    // Он(paragraph start) шёл,(clause) а потом остановился.(sentence)
    // Достопримечательность ждала(last word: sentence end)
    expect(ms[4], greaterThan(ms[1]), reason: 'sentence > clause');
    expect(ms[1], greaterThan(ms[3]), reason: 'clause > plain');
    expect(ms[3], greaterThan(ms[2]), reason: 'plain > short');
    expect(ms[5], greaterThan(ms[3]), reason: 'long > plain');
  });
}
