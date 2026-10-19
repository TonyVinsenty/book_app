import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:book_app/book/encoding/text_decoder.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/parsers/fb2_parser.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../snapshot.dart';

const fixtures = 'test/fixtures/fb2';

BookContent parseFile(String name) =>
    parseFb2(File('$fixtures/$name').readAsBytesSync(), title: name);

BookContent parse(String body, {String description = ''}) => parseFb2String(
  '<?xml version="1.0"?><FictionBook>'
  '<description><title-info>$description</title-info></description>'
  '<body>$body</body></FictionBook>',
  title: 'file',
);

/// Blocks as short strings: `# text` (level), `[style] text`.
List<String> blocksOf(BookContent book) => [
  for (final s in book.sections)
    for (final b in s.blocks)
      switch (b) {
        HeadingBlock(:final text, :final level) => '#$level $text',
        ParagraphBlock(:final text, style: ParagraphStyle.normal) => text,
        ParagraphBlock(:final text, :final style) => '[${style.name}] $text',
        SeparatorBlock() => '***',
        ImageBlock() => 'image',
      },
];

void main() {
  group('fixtures', () {
    for (final name in [
      'utf8_nested.fb2',
      'cp1251_entities.fb2',
      'broken_tail.fb2',
    ]) {
      test(name, () => expectSnapshot(parseFile(name), '$fixtures/$name'));
    }
  });

  group('utf8_nested.fb2', () {
    final book = parseFile('utf8_nested.fb2');

    test('metadata from title-info only', () {
      final meta = book.meta;
      expect(meta.title, 'Утро над рекой');
      expect(meta.authors, ['Анна Петровна Тестова', 'Аноним']);
      expect(meta.series, 'Тестовые книги');
      expect(meta.seriesNumber, 2);
      expect(meta.lang, 'ru');
      expect(
        meta.annotation,
        'Короткая повесть о тихом утре.\nВторая строка аннотации.',
      );
      expect(meta.sourceFormat, SourceFormat.fb2);
    });

    test('contents: title page, parts and chapters', () {
      expect(
        [for (final t in book.toc) (t.title, t.level, t.sectionIndex)],
        [
          ('Часть первая', 0, 1),
          ('Глава 1. Туман', 1, 1),
          ('Глава 2. Гости', 1, 2),
          ('Часть вторая', 0, 3),
          ('Глава 3', 1, 4),
        ],
      );
      // The body title with its epigraph is a title page of its own; a part
      // title with nothing after it shares a section with the first chapter.
      expect(book.sections, hasLength(6));
      expect(book.sections[0].title, isNull);
      expect(book.sections[1].title, 'Часть первая');
      expect(book.sections[4].title, 'Глава 3');
      expect(book.sections[5].title, isNull);
    });

    test('blocks: styles, poems by stanza, notes and pictures skipped', () {
      final blocks = blocksOf(book);
      expect(blocks.take(7), [
        '#1 Анна Тестова\nУтро над рекой',
        '[epigraph] Над рекой туман клубится,\nСолнце прячется в лесу.',
        '[epigraph] Народное',
        '#1 Часть первая',
        '#2 Глава 1\nТуман',
        'Утро было тихим, и над рекой ещё стоял туман. Анна вышла на '
            'крыльцо.',
        '— Ты опять встала раньше всех? — спросил отец.',
      ]);
      expect(blocks, contains('***'));
      expect(blocks, contains('[quote] Пословица'));
      expect(blocks, contains('[subtitle] Песня'));
      expect(
        blocks,
        contains(
          '[poem] Ждёт их Анна на пороге,\nСмотрит в поле, смотрит в лес.',
        ),
      );
      expect(blocks, contains('[epigraph] Ночью пошёл дождь.'));
      expect(blocks.where((b) => b.contains('Сноска')), isEmpty);
      expect(blocks.last, 'Раздел без заголовка.');
    });

    test('bold and italic spans, nested', () {
      final p = book.sections[1].blocks.whereType<ParagraphBlock>().firstWhere(
        (b) => b.text.startsWith('Слова'),
      );
      expect(
        [for (final s in p.spans) (p.text.substring(s.start, s.end), s.kind)],
        [
          ('жирные и курсивные', SpanKind.strong),
          ('курсивные', SpanKind.emphasis),
        ],
      );
    });

    test('the tokenizer reads every word of the poem', () {
      final tokens = tokenize(book);
      final words = [
        for (var i = 0; i < tokens.length; i++) tokens.textOf(i),
      ];
      expect(words, containsAllInOrder(['пороге,', 'лес.', 'Анна', 'К', 'вечеру']));
    });
  });

  test('cp1251_entities.fb2: declared encoding, entities, table', () {
    final book = parseFile('cp1251_entities.fb2');
    expect(book.meta.title, 'Таблицы и знаки');
    expect(book.meta.authors, ['Иванов']);
    expect(blocksOf(book), [
      '#1 Глава первая',
      '«Слово» — это т. е. пример & проверка.',
      'Год Событие',
      '1812 Война',
      'Текст в CDATA <без> тегов.',
    ]);
  });

  test('broken_tail.fb2: stray text, unclosed tags, cut file', () {
    final book = parseFile('broken_tail.fb2');
    expect(book.meta.title, 'broken_tail.fb2');
    expect(blocksOf(book), [
      '#1 Начало',
      'Текст прямо в разделе, без абзаца.',
      'Абзац без конца',
      'Следующий абзац.',
      '#1 Обрыв',
      'Первый целый абзац.',
      'Этот абзац оборв',
    ]);
  });

  group('encoding', () {
    const text =
        '<?xml version="1.0" encoding="windows-1251"?>'
        '<FictionBook><body><section><p>Привет, мир</p></section></body>'
        '</FictionBook>';

    test('a declaration that lies about UTF-8 text is ignored', () {
      final book = parseFb2(Uint8List.fromList(utf8.encode(text)), title: 't');
      expect(blocksOf(book), ['Привет, мир']);
    });

    test('UTF-16 with BOM', () {
      final units = text.replaceFirst('windows-1251', 'UTF-16').codeUnits;
      final bytes = BytesBuilder()..add([0xFF, 0xFE]);
      for (final u in units) {
        bytes.add([u & 0xFF, u >> 8]);
      }
      expect(blocksOf(parseFb2(bytes.toBytes(), title: 't')), ['Привет, мир']);
    });
  });

  group('structure', () {
    test('whitespace collapses, spans keep their place', () {
      final book = parse(
        '<section><p>  один\n\t два <emphasis> три </emphasis>четыре </p>'
        '</section>',
      );
      final p = book.sections.single.blocks.single as ParagraphBlock;
      expect(p.text, 'один два три четыре');
      expect(p.text.substring(p.spans[0].start, p.spans[0].end), 'три');
    });

    test('empty paragraphs and sections are dropped', () {
      final book = parse(
        '<section><p> </p><empty-line/></section>'
        '<section><title><p>A</p></title><p>текст</p></section>',
      );
      expect(book.sections, hasLength(1));
      expect(blocksOf(book), ['#1 A', 'текст']);
    });

    test('a section with text closes before a nested one', () {
      final book = parse(
        '<section><title><p>Часть</p></title><p>вступление</p>'
        '<section><title><p>Глава</p></title><p>текст</p></section>'
        '</section>',
      );
      expect([for (final s in book.sections) s.title], ['Часть', 'Глава']);
      expect(
        [for (final t in book.toc) (t.level, t.sectionIndex)],
        [(0, 0), (1, 1)],
      );
    });

    test('links without note type but to #id are note marks', () {
      final book = parse(
        '<section><p>Слово<a l:href="#n2"><sup>2</sup></a> и '
        '<a l:href="https://example.com">ссылка</a>.</p></section>',
      );
      expect(blocksOf(book), ['Слово и ссылка.']);
    });

    test('a title with a trailing period joins with a space', () {
      final book = parse(
        '<section><title><p>Глава 1.</p><p>Начало</p></title><p>т</p>'
        '</section>',
      );
      expect(book.toc.single.title, 'Глава 1. Начало');
      expect(book.sections.single.title, 'Глава 1. Начало');
    });

    test('description without author or title falls back to the file', () {
      final book = parse('<section><p>т</p></section>');
      expect(book.meta.title, 'file');
      expect(book.meta.authors, isEmpty);
      expect(book.meta.lang, isNull);
    });

    test('the model survives a JSON round trip', () {
      final book = parseFile('utf8_nested.fb2');
      final again = BookContent.fromJson(
        jsonDecode(jsonEncode(book.toJson())) as Map<String, Object?>,
      );
      expect(jsonEncode(again.toJson()), jsonEncode(book.toJson()));
    });
  });

  group('not FB2', () {
    test('another XML root', () {
      expect(
        () => parseFb2String('<html><body>x</body></html>', title: 't'),
        throwsA(isA<NotFb2Exception>()),
      );
    });

    test('plain text', () {
      expect(
        () => parseFb2String('просто текст', title: 't'),
        throwsA(isA<NotFb2Exception>()),
      );
    });

    test('garbage after the root start', () {
      expect(
        () => parseFb2String('<FictionBook><<<>>>', title: 't'),
        throwsA(isA<NotFb2Exception>()),
      );
    });

    test('binary bytes', () {
      expect(
        () => parseFb2(
          Uint8List.fromList(List.generate(4000, (i) => i % 7)),
          title: 't',
        ),
        throwsA(isA<NotTextException>()),
      );
    });
  });
}
