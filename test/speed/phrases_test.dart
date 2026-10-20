import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/speed/phrases.dart';
import 'package:flutter_test/flutter_test.dart';

import '../layout/sample_book.dart';

BookTokens _book(List<List<String>> sections) => tokenize(
  BookContent(
    meta: const BookMeta(title: 't', sourceFormat: SourceFormat.txt),
    sections: [
      for (final paragraphs in sections)
        Section(blocks: [for (final p in paragraphs) ParagraphBlock(text: p)]),
    ],
  ),
);

/// The phrases of the whole book, words joined by spaces.
List<String> _phrases(BookTokens tokens, {int maxChars = 18}) {
  final steps = PhraseSteps(tokens, maxChars: maxChars);
  return [
    for (var i = 0; i < tokens.length; i = steps.endOf(i))
      [for (var w = i; w < steps.endOf(i); w++) tokens.textOf(w)].join(' '),
  ];
}

void main() {
  test('phrases of Russian and English text', () {
    final cases = <(String text, List<String> phrases)>[
      (
        'Дождь шёл с самого утра, и к вечеру улица опустела.',
        ['Дождь шёл', 'с самого утра,', 'и к вечеру', 'улица опустела.'],
      ),
      (
        '— Привет, — сказал он. — Как дела?',
        ['— Привет, —', 'сказал он.', '— Как дела?'],
      ),
      ('Он ушёл — и не вернулся.', ['Он ушёл —', 'и не вернулся.']),
      (
        'Яблоки, груши и т. д. лежали на столе.',
        ['Яблоки,', 'груши и т.', 'д. лежали', 'на столе.'],
      ),
      (
        'Мы прошли 5 км пешком до реки.',
        ['Мы прошли', '5 км пешком', 'до реки.'],
      ),
      (
        'Это достопримечательность города.',
        ['Это', 'достопримечательность', 'города.'],
      ),
      (
        'The cat sat on the mat in the house.',
        ['The cat sat', 'on the mat', 'in the house.'],
      ),
    ];
    for (final (text, phrases) in cases) {
      expect(
        _phrases(
          _book([
            [text],
          ]),
        ),
        phrases,
        reason: text,
      );
    }
  });

  test('a paragraph and a section start a new phrase', () {
    final tokens = _book([
      ['Он шёл', 'Дом стоял'],
      ['Новая глава'],
    ]);
    expect(_phrases(tokens), ['Он шёл', 'Дом стоял', 'Новая глава']);
  });

  test('no phrase is longer than max chars unless it is one word', () {
    final tokens = tokenize(sampleBook(paragraphs: 60));
    for (final maxChars in [12, 18, 24]) {
      final steps = PhraseSteps(tokens, maxChars: maxChars);
      for (var i = 0; i < tokens.length; i = steps.endOf(i)) {
        final words = steps.endOf(i) - i;
        expect(words, lessThanOrEqualTo(PhraseSteps.maxWords));
        if (words > 1) {
          var chars = words - 1;
          for (var w = i; w < i + words; w++) {
            chars += tokens.textOf(w).length;
          }
          expect(chars, lessThanOrEqualTo(maxChars), reason: 'word $i');
        }
      }
    }
  });

  test('every word is in one phrase; a sentence starts a phrase', () {
    final tokens = tokenize(sampleBook(paragraphs: 60));
    final steps = PhraseSteps(tokens);
    var expected = 0;
    for (var i = 0; i < tokens.length; i++) {
      final start = steps.startOf(i);
      expect(start, lessThanOrEqualTo(i));
      expect(steps.endOf(i), greaterThan(i));
      expect(steps.endOf(start), steps.endOf(i), reason: 'word $i');
      if (start == i) {
        expect(i, expected, reason: 'phrases follow one another');
        expected = steps.endOf(i);
      }
      final sentence = tokens.sentenceStartOf(i);
      expect(steps.startOf(sentence), sentence, reason: 'sentence at $i');
      expect(tokens.sectionOf(steps.endOf(i) - 1), tokens.sectionOf(i));
    }
    expect(expected, tokens.length);
  });

  test('a long chapter is split fast', () {
    final tokens = tokenize(sampleBook(sections: 1, paragraphs: 6000));
    final watch = Stopwatch()..start();
    final steps = PhraseSteps(tokens);
    for (var i = 0; i < tokens.length; i = steps.endOf(i)) {}
    watch.stop();
    // ignore: avoid_print
    print(
      'PhraseSteps: ${tokens.length} words in ${watch.elapsedMilliseconds} ms',
    );
    expect(watch.elapsedMilliseconds, lessThan(200));
  });
}
