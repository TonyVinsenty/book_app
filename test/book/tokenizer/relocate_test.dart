import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/relocate.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

BookTokens tokensOf(List<String> paragraphs) => tokenize(
  BookContent(
    meta: const BookMeta(title: 't', sourceFormat: SourceFormat.txt),
    sections: [
      Section(blocks: [for (final p in paragraphs) ParagraphBlock(text: p)]),
    ],
  ),
);

void main() {
  test('the same words are found after new words before them', () {
    final old = tokensOf(['Раз два три четыре пять шесть семь.']);
    final fresh = tokensOf([
      'Новое начало.',
      'Раз два три четыре пять шесть семь.',
    ]);
    expect(fresh.textOf(relocateWord(old, 3, fresh)!), 'четыре');
  });

  test('glued note numbers do not break the match', () {
    final old = tokensOf(['Он сказал1, что придёт завтра утром.']);
    final fresh = tokensOf(['Он сказал, что придёт завтра утром.']);
    expect(relocateWord(old, 2, fresh), 2);
  });

  test('a repeated phrase: the one nearer by proportion wins', () {
    const phrase = 'и снова тот же самый припев песни';
    final old = tokensOf([phrase, 'куплет', phrase]);
    final fresh = tokensOf([phrase, 'куплет', phrase]);
    expect(relocateWord(old, 8, fresh), 8);
    expect(relocateWord(old, 1, fresh), 1);
  });

  test('null when the text is gone', () {
    final old = tokensOf(['Совсем другой текст здесь был.']);
    final fresh = tokensOf(['Ничего общего с прежним.']);
    expect(relocateWord(old, 1, fresh), isNull);
  });
}
