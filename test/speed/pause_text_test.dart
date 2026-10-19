import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/speed/pause_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 0 Раз 1 два. | 2 Три 3 четыре 4 пять. || 5 Шесть 6 семь.
  final tokens = tokenize(
    BookContent(
      meta: const BookMeta(title: 't', sourceFormat: SourceFormat.txt),
      sections: [
        Section(
          blocks: [
            ParagraphBlock(text: 'Раз два.'),
            ParagraphBlock(text: 'Три четыре пять.'),
          ],
        ),
        Section(blocks: [ParagraphBlock(text: 'Шесть семь.')]),
      ],
    ),
  );

  test('the text before a word keeps paragraphs and stays in the chapter', () {
    expect(textBefore(tokens, 0), '');
    expect(textBefore(tokens, 4), 'Раз два.\nТри четыре ');
    expect(textBefore(tokens, 5), '', reason: 'a new chapter');
    expect(textBefore(tokens, 6), 'Шесть ');
  });

  test('a cut paragraph starts with an ellipsis', () {
    expect(textBefore(tokens, 4, maxWords: 1), '… четыре ');
    expect(textBefore(tokens, 4, maxWords: 2), 'Три четыре ');
  });
}
