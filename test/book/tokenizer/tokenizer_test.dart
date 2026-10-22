import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/reading_position.dart';
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
      'Он сказал " привет " и ушёл': [
        'Он',
        'сказал',
        '" привет "',
        'и',
        'ушёл',
      ],
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

  group('long hyphenated words', () {
    const cases = <String, List<String>>{
      'полуавтоматы-получеловеки': ['полуавтоматы-', 'получеловеки'],
      '«полуавтоматы-получеловеки»,': ['«полуавтоматы-', 'получеловеки»,'],
      'научно-исследовательский': ['научно-', 'исследовательский'],
      'Санкт-Петербург': ['Санкт-', 'Петербург'],
      'научно-исследовательско-конструкторский': [
        'научно-',
        'исследовательско-',
        'конструкторский',
      ],
      'Комсомольск-на-Амуре': ['Комсомольск-на-', 'Амуре'],
      'по-русски': ['по-русски'],
      'что-нибудь': ['что-нибудь'],
      'кто-то': ['кто-то'],
      'Ростов-на-Дону': ['Ростов-на-Дону'],
      'по-французски': ['по-французски'],
      'давным-давно': ['давным-давно'],
      'иссиня-чёрный': ['иссиня-чёрный'],
      'Мамин-Сибиряк': ['Мамин-Сибиряк'],
      'полуавтоматы‑получеловеки': ['полуавтоматы‑получеловеки'], // U+2011
      '1234567890-1234567890': ['1234567890-1234567890'],
      'http://www.fun-with-words.com/anagrams': [
        'http://www.fun-with-words.com/anagrams',
      ],
      'RateMy-Professors.com': ['RateMy-Professors.com'],
    };
    cases.forEach((input, expected) {
      test(input, () {
        expect(textsOf(input), expected);
      });
    });

    test('glued dashes stay with their parts', () {
      expect(
        flagged(
          '— Санкт-Петербург, — сказал он. — Полуавтоматы-получеловеки —',
          TokenFlags.dash,
        ),
        ['— Санкт-', 'Петербург, —', '— Полуавтоматы-', 'получеловеки —'],
      );
    });

    test('parts keep sentence flags and their own ORP', () {
      final t = tokensOf(['Это полуавтоматы-получеловеки. Да']);
      expect(t[1].sentenceEnd, isFalse);
      expect(t[1].clauseEnd, isFalse);
      expect(t[2].sentenceEnd, isTrue);
      expect(t[1].text[t[1].orp], 'у'); // 12 letters → 4th
      expect(t[2].text[t[2].orp], 'у');
    });

    test('a position on the whole word moves to its first part', () {
      const text = 'Вот полуавтоматы-получеловеки идут';
      final t = tokensOf([text]);
      // Saved by the old tokenizer: «идут» was word 2, anchored at its start.
      final old = ReadingPosition(
        wordIndex: 2,
        anchor: TextAnchor(
          sectionIndex: 0,
          blockIndex: 0,
          charOffset: text.indexOf('идут'),
        ),
      );
      expect(t.textOf(t.resolve(old)), 'идут');
      final whole = ReadingPosition(
        wordIndex: 1,
        anchor: TextAnchor(
          sectionIndex: 0,
          blockIndex: 0,
          charOffset: text.indexOf('полу'),
        ),
      );
      expect(t.textOf(t.resolve(whole)), 'полуавтоматы-');
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

  test('pictures stand before the next word; sizeless and last ones not', () {
    final t = tokenize(
      const BookContent(
        meta: BookMeta(title: 't', sourceFormat: SourceFormat.epub),
        sections: [
          Section(
            blocks: [ImageBlock(assetId: 'cover', width: 600, height: 900)],
          ),
          Section(
            blocks: [
              ImageBlock(assetId: 'a', width: 10, height: 10),
              ParagraphBlock(text: 'Один два.'),
              ImageBlock(assetId: 'b', width: 10, height: 10),
              ImageBlock(assetId: 'no-size'),
              ImageBlock(assetId: 'c', width: 10, height: 10),
              ParagraphBlock(text: 'Три.'),
              ImageBlock(assetId: 'd', width: 10, height: 10),
            ],
          ),
          Section(
            blocks: [
              ParagraphBlock(text: 'Четыре.'),
              ImageBlock(assetId: 'last', width: 10, height: 10),
            ],
          ),
        ],
      ),
    );
    List<String> ids(int word) => [
      for (final i in t.imagesBefore(word)) i.image.assetId,
    ];
    expect(ids(0), ['cover', 'a']);
    expect(ids(1), isEmpty);
    expect(ids(2), ['b', 'c']);
    expect(ids(3), ['d']);
    expect(t.length, 4);
    final c = t.imagesBefore(2).last;
    expect((c.sectionIndex, c.blockIndex), (1, 4));
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

  group('note labels', () {
    /// Words of [marked], where `{12}` is a note label `12`.
    BookTokens notedTokens(String marked) {
      final text = StringBuffer();
      final spans = <Span>[];
      for (final part in RegExp(r'\{([^}]*)\}|[^{]+').allMatches(marked)) {
        final label = part[1];
        if (label == null) {
          text.write(part[0]);
          continue;
        }
        spans.add(
          Span(
            text.length,
            text.length + label.length,
            SpanKind.noteRef,
            noteId: 'n',
          ),
        );
        text.write(label);
      }
      return tokenize(
        BookContent(
          meta: const BookMeta(title: 't', sourceFormat: SourceFormat.txt),
          sections: [
            Section(
              blocks: [ParagraphBlock(text: text.toString(), spans: spans)],
            ),
          ],
        ),
      );
    }

    List<String> notedTexts(String marked) {
      final t = notedTokens(marked);
      return [for (var i = 0; i < t.length; i++) t.textOf(i)];
    }

    const cases = <String, List<String>>{
      'Он сказал{1}, и ушёл.': ['Он', 'сказал,', 'и', 'ушёл.'],
      'Слово{12}': ['Слово'],
      '{*} Текст сноски': ['Текст', 'сноски'],
      'Раз {2} два': ['Раз', 'два'],
      'полу{3}слово': ['полуслово'],
      '«Да{4}», — сказал он.': ['«Да», —', 'сказал', 'он.'],
      '{5}': [],
    };
    cases.forEach((input, words) {
      test(input, () => expect(notedTexts(input), words));
    });

    test('a label keeps the sentence end and the ORP', () {
      final t = notedTokens('Конец.{7} Начало');
      expect(t.flagsOf(0) & TokenFlags.sentenceEnd, isNot(0));
      final w = notedTokens('сказал{1},')[0];
      expect(w.text, 'сказал,');
      expect(w.text[w.orp], 'а');
    });

    test('offsets cover the word in the block, not a label after it', () {
      final t = notedTokens('Слово{12} и{3},');
      expect([t[0].charStart, t[0].charEnd], [0, 5]);
      expect([t[1].charStart, t[1].charEnd], [8, 11]); // `и3,`
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
