import 'dart:io';

import 'package:book_app/book/encoding/text_decoder.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../snapshot.dart';

const fixtures = 'test/fixtures/txt';

List<String> paragraphsOf(BookContent book) => [
  for (final s in book.sections)
    for (final b in s.blocks)
      switch (b) {
        HeadingBlock(:final text) => '# $text',
        ParagraphBlock(:final text) => text,
        SeparatorBlock() => '***',
        ImageBlock() => 'image',
      },
];

BookContent parse(String text) => parseTxtString(text, title: 't');

void main() {
  group('fixtures', () {
    const names = [
      'utf8_lines.txt',
      'utf8_bom_crlf.txt',
      'cp1251_librus.txt',
      'koi8r_blank.txt',
      'utf16le_bom.txt',
    ];
    for (final name in names) {
      test(name, () {
        final path = '$fixtures/$name';
        final book = parseTxt(File(path).readAsBytesSync(), title: name);
        expectSnapshot(book, path);
      });
    }

    test('lib.ru file: chapters, paragraphs and glued lines', () {
      final book = parseTxt(
        File('$fixtures/cp1251_librus.txt').readAsBytesSync(),
        title: 't',
      );
      expect(book.meta.lang, 'ru');
      expect(
        [for (final t in book.toc) (t.title, t.level, t.sectionIndex)],
        [('ЧАСТЬ ПЕРВАЯ', 0, 0), ('I', 1, 0), ('II', 1, 1)],
      );
      final paragraphs = paragraphsOf(book);
      expect(paragraphs, hasLength(2 + 4 + 1 + 2 + 1));
      expect(paragraphs[2], startsWith('Утро было тихим'));
      expect(paragraphs[2], endsWith('не раньше полудня.'));
      expect(
        paragraphs.last,
        'Слово на переносе: какой-нибудь пример в конце.',
      );
    });

    test('KOI8-R file: chapters in capitals', () {
      final book = parseTxt(
        File('$fixtures/koi8r_blank.txt').readAsBytesSync(),
        title: 't',
      );
      expect([for (final s in book.sections) s.title], ['ТИХОЕ УТРО', 'ДОЖДЬ']);
      expect(book.sections[0].blocks, hasLength(1 + 4));
    });
  });

  group('paragraphs', () {
    test('one line per paragraph, dialog lines are not glued', () {
      expect(paragraphsOf(parse('Первый абзац.\n— Реплика.\nВторой абзац.')), [
        'Первый абзац.',
        '— Реплика.',
        'Второй абзац.',
      ]);
    });

    test('blank lines and extra spaces', () {
      expect(
        paragraphsOf(parse('\n\n  Один   два.\n\n\n\nТри\t\tчетыре.\n\n')),
        ['Один два.', 'Три четыре.'],
      );
    });

    test('hard-wrapped lines: lowercase keywords and inline dashes', () {
      const w = 'Слово слово слово слово слово слово слово слово слово';
      final book = parse(
        [
          '     $w и большая',
          'часть войска ушла к реке, а $w',
          '- ответила она. $w конец.',
          '     $w снова.',
          '- Да, $w конец.',
          '     Последний $w абзац.',
        ].join('\n'),
      );
      final paragraphs = paragraphsOf(book);
      expect(paragraphs, hasLength(4));
      expect(paragraphs[0], contains('большая часть войска'));
      expect(paragraphs[0], contains('а Слово'));
      expect(paragraphs[0], contains('- ответила она.'));
      expect(paragraphs[1], startsWith('Слово'));
      expect(paragraphs[2], startsWith('- Да,')); // after a sentence end
    });

    test('separator lines', () {
      expect(paragraphsOf(parse('Раз.\n* * *\nДва.\n---\nТри.')), [
        'Раз.',
        '***',
        'Два.',
        '***',
        'Три.',
      ]);
    });

    test('empty text', () {
      final book = parse('');
      expect(book.sections, isEmpty);
      expect(book.toc, isEmpty);
    });
  });

  group('headings', () {
    const cases = <String, bool>{
      'Глава 1': true,
      'ГЛАВА ПЕРВАЯ': true,
      'Глава 5. Встреча': true,
      'Часть вторая': true,
      'Chapter 12': true,
      'Пролог': true,
      'XIV': true,
      'ВОЙНА И МИР': true,
      'Часть II. Возвращение': true,
      'Эпилог': true,
      'Том вошёл в комнату.': false,
      'Глава семьи уехал.': false,
      'Часть денег пропала.': false,
      'Главная мысль была проста.': false,
      '— СТОЙ!': false,
      'ДА, КОНЕЧНО,': false,
      'Он сказал: глава семьи уехал, а мы остались ждать его возвращения домой.':
          false,
    };
    cases.forEach((line, isHeading) {
      test(line, () {
        final book = parse('Начало.\n$line\nТекст.');
        expect(paragraphsOf(book).contains('# $line'), isHeading);
      });
    });

    test('headings in a row share a section, parts are level 1', () {
      final book = parse(
        'ЧАСТЬ I\nГлава 1\nТекст.\nГлава 2\nТекст.\nЧАСТЬ II\nГлава 3\nТекст.',
      );
      expect(book.sections, hasLength(3));
      expect([for (final t in book.toc) t.level], [0, 1, 1, 0, 1]);
      expect([for (final t in book.toc) t.sectionIndex], [0, 0, 1, 2, 2]);
    });

    test('a contents list is not a row of chapters', () {
      final book = parse(
        'Оглавление\nГлава 1\nГлава 2\nГлава 3\nГлава 1\nТекст.\nГлава 2\nТекст.',
      );
      expect([for (final t in book.toc) t.title], ['Глава 1', 'Глава 2']);
      expect(book.sections, hasLength(3));
    });

    test('caps as the author\'s style are not headings', () {
      final text = [
        for (var i = 0; i < 10; i++) 'КРИК НОМЕР $i\nобычная строка.',
      ].join('\n');
      expect(parse(text).sections, hasLength(1));
    });
  });

  test('binary files are rejected', () {
    expect(
      () => parseTxt(
        File('assets/fonts/Lora-Regular.ttf').readAsBytesSync(),
        title: 'x',
      ),
      throwsA(isA<NotTextException>()),
    );
  });
}
