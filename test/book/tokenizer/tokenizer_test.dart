import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/token.dart';
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

List<String> textsOf(String paragraph) {
  final t = tokensOf([paragraph]);
  return [for (var i = 0; i < t.length; i++) t.textOf(i)];
}

/// Words of [paragraph] that have [flag].
List<String> flagged(String paragraph, int flag) {
  final t = tokensOf([paragraph]);
  return [
    for (var i = 0; i < t.length; i++)
      if (t.flagsOf(i) & flag != 0) t.textOf(i),
  ];
}

void main() {
  group('splitting', () {
    const cases = <String, List<String>>{
      'Привет, мир!': ['Привет,', 'мир!'],
      '  много   пробелов\tи\nстрок  ': ['много', 'пробелов', 'и', 'строк'],
      '«Привет», — сказал он.': ['«Привет», —', 'сказал', 'он.'],
      '— Привет, — сказал он. — Как дела?': [
        '— Привет, —',
        'сказал',
        'он.',
        '— Как',
        'дела?',
      ],
      '– Hi there': ['– Hi', 'there'],
      '- Дефис вместо тире': ['- Дефис', 'вместо', 'тире'],
      'Кто-то из Ростова-на-Дону прислал e-mail': [
        'Кто-то',
        'из',
        'Ростова-на-Дону',
        'прислал',
        'e-mail',
      ],
      'Тираж 1 000 000 экземпляров': ['Тираж', '1 000 000', 'экземпляров'],
      'и т. е. так далее': ['и', 'т. е.', 'так', 'далее'],
      'Число 12,5 и 3.14, дата 2026-10-19, XIX век': [
        'Число',
        '12,5',
        'и',
        '3.14,',
        'дата',
        '2026-10-19,',
        'XIX',
        'век',
      ],
      'Конец ... и « кавычки » врозь': [
        'Конец ...',
        'и',
        '« кавычки »',
        'врозь',
      ],
      '* * *': ['* * *'],
      'Он сказал: — Привет!': ['Он', 'сказал:', '— Привет!'],
      'Он сказал " привет " и ушёл': ['Он', 'сказал', '" привет "', 'и', 'ушёл'],
      '—': ['—'],
      'Слово​слово': ['Слово', 'слово'],
      '': [],
    };
    cases.forEach((input, expected) {
      test(input.isEmpty ? '(empty)' : input, () {
        expect(textsOf(input), expected);
      });
    });
  });

  group('sentence ends', () {
    const cases = <String, List<String>>{
      'Он пришёл. Она ушла! Кто там? Тишина… Конец': [
        'пришёл.',
        'ушла!',
        'там?',
        'Тишина…',
        'Конец',
      ],
      '«Иди!» Он пошёл.': ['«Иди!»', 'пошёл.'],
      'Яблоки, груши и т. д. Потом всё.': ['д.', 'всё.'],
      'Яблоки, груши и т. д. и т. п.': ['п.'],
      'Мы жили в г. Москва на ул. Ленина.': ['Ленина.'],
      'Поэт А. С. Пушкин родился в 1799 г. в Москве.': ['Москве.'],
      'Mr. Smith met Dr. Watson, e.g. here.': ['here.'],
      '— Куда? — спросил он.': ['он.'],
      'См. с. 45 и д. 5.': ['5.'],
      'Строка без точки': ['точки'],
      'Он родился в 1799 г. Его отец служил.': ['г.', 'служил.'],
      '— Кто там? — Я. А ты кто?': ['там?', '— Я.', 'кто?'],
    };
    cases.forEach((input, expected) {
      test(input, () {
        expect(flagged(input, TokenFlags.sentenceEnd), expected);
      });
    });
  });

  group('other flags', () {
    test('clause ends', () {
      expect(flagged('Один, два; три: четыре — пять', TokenFlags.clauseEnd), [
        'Один,',
        'два;',
        'три:',
      ]);
      expect(flagged('— Куда? — спросил он.', TokenFlags.clauseEnd), [
        '— Куда?',
      ]);
    });

    test('dash', () {
      expect(flagged('— Да, — сказал он — и ушёл', TokenFlags.dash), [
        '— Да, —',
        'он —',
      ]);
    });

    test('numbers', () {
      expect(
        flagged(
          'Было 12,5% и 3.14, в 2026-10-19 XIX MIX DID I 1 000 №5 x2',
          TokenFlags.isNumber,
        ),
        ['12,5%', '3.14,', '2026-10-19', 'XIX', 'MIX', '1 000', '№5'],
      );
    });

    test('paragraph and section starts', () {
      final t = tokenize(
        const BookContent(
          meta: BookMeta(title: 't', sourceFormat: SourceFormat.fb2),
          sections: [
            Section(
              blocks: [
                ImageBlock(assetId: 'a'),
                HeadingBlock(text: 'Глава 1'),
                ParagraphBlock(text: 'Первый абзац.'),
                SeparatorBlock(),
                ParagraphBlock(text: 'Второй.'),
              ],
            ),
            Section(blocks: []),
            Section(blocks: [ParagraphBlock(text: 'Глава два')]),
          ],
        ),
      );
      final starts = [
        for (var i = 0; i < t.length; i++)
          if (t[i].paragraphStart) t[i].text,
      ];
      final sections = [
        for (var i = 0; i < t.length; i++)
          if (t[i].sectionStart) t[i].text,
      ];
      expect(starts, ['Глава', 'Первый', 'Второй.', 'Глава']);
      expect(sections, ['Глава', 'Глава']);
      expect(t[0].blockIndex, 1);
      expect(t[0].sectionIndex, 0);
      expect(t[5].sectionIndex, 2);
      expect([0, 1, 2, 3].map(t.firstWordOfSection), [0, 5, 5, 7]);
    });
  });

  group('ORP', () {
    const cases = <String, String>{
      'я': 'я',
      'он': 'н',
      'слово': 'л',
      'привет': 'и',
      'книжечка,': 'и',
      'библиотека': 'л',
      'достопримечательность': 'о',
      '«Привет»': 'и',
      '— Привет': 'и',
      'за́мок': 'а',
      '...': '.',
      'по-русски': 'р',
      'что-нибудь': 'о',
      'т. е.': 'е',
    };
    cases.forEach((word, letter) {
      test(word, () {
        expect(word[orpIndex(word)], letter);
      });
    });

    test('stored in tokens', () {
      final t = tokensOf(['— Привет, мир']);
      expect(t[0].text[t[0].orp], 'и');
    });
  });

  test('token text matches block text and offsets', () {
    const text = '«Да», — сказал он. — Кто-то!';
    final t = tokensOf([text]);
    for (var i = 0; i < t.length; i++) {
      expect(text.substring(t[i].charStart, t[i].charEnd), t[i].text);
    }
  });

  test('sentence starts', () {
    final t = tokensOf(['Раз два. Три четыре пять.', 'Шесть']);
    expect(
      [for (var i = 0; i < t.length; i++) t.sentenceStartOf(i)],
      [0, 0, 2, 2, 2, 5],
    );
  });

  test('a big book tokenizes quickly', () {
    final paragraph = List.filled(
      100,
      '«Привет», — сказал он. Кто-то пришёл в 1812 г. и т. д.',
    ).join(' ');
    final sw = Stopwatch()..start();
    final t = tokensOf(List.filled(500, paragraph)); // ~600k words
    sw.stop();
    expect(t.length, 500 * 100 * 11);
    expect(sw.elapsed, lessThan(const Duration(seconds: 30)));
  });
}
