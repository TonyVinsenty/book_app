import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/speed/rewind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'back: to the sentence start, or the previous one in its first words',
    () {
      // 0 Раз 1 два 2 три. | 3 Четыре 4 пять 5 шесть. | 6 Семь 7 восемь.
      final tokens = tokenize(
        BookContent(
          meta: const BookMeta(title: 't', sourceFormat: SourceFormat.txt),
          sections: [
            Section(
              blocks: [
                ParagraphBlock(text: 'Раз два три. Четыре пять шесть.'),
                ParagraphBlock(text: 'Семь восемь.'),
              ],
            ),
          ],
        ),
      );
      final cases = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 3, 6: 3, 7: 3};
      for (final MapEntry(key: word, value: target) in cases.entries) {
        expect(sentenceBack(tokens, word), target, reason: 'from $word');
      }
    },
  );
}
