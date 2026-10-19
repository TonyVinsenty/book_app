import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/parsers/epub_parser.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../snapshot.dart';

const fixtures = 'test/fixtures/epub';

Uint8List fixture(String name) => File('$fixtures/$name').readAsBytesSync();

BookContent parseFile(String name) => parseEpub(fixture(name), title: name);

const _container =
    '<?xml version="1.0"?><container><rootfiles>'
    '<rootfile full-path="content.opf" '
    'media-type="application/oebps-package+xml"/></rootfiles></container>';

String _opf(List<String> files) =>
    '<package><metadata/><manifest>'
    '${[for (final (i, f) in files.indexed) '<item id="i$i" href="$f" media-type="application/xhtml+xml"/>'].join()}'
    '</manifest><spine>'
    '${[for (var i = 0; i < files.length; i++) '<itemref idref="i$i"/>'].join()}'
    '</spine></package>';

/// An EPUB of [files] (name → body) in this order, unless [extra] replaces
/// the container or the OPF.
Uint8List epubOf(
  Map<String, String> files, {
  Map<String, Object> extra = const {},
}) {
  final entries = <String, Object>{
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml': _container,
    'content.opf': _opf(files.keys.toList()),
    for (final MapEntry(:key, :value) in files.entries)
      key: '<html><body>$value</body></html>',
    ...extra,
  };
  final archive = Archive();
  for (final MapEntry(:key, :value) in entries.entries) {
    archive.addFile(
      value is String
          ? ArchiveFile.string(key, value)
          : ArchiveFile.bytes(key, value as List<int>),
    );
  }
  return ZipEncoder().encodeBytes(archive);
}

/// An EPUB of [files] with contents: the body of an EPUB 3 `nav.xhtml`
/// or the `navMap` of an EPUB 2 `toc.ncx`.
Uint8List epubWithContents(
  Map<String, String> files, {
  String? nav,
  String? ncx,
}) {
  final names = files.keys.toList();
  final opf =
      '<package><metadata/><manifest>'
      '${[for (final (i, f) in names.indexed) '<item id="i$i" href="$f" media-type="application/xhtml+xml"/>'].join()}'
      '${nav == null ? '' : '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'}'
      '${ncx == null ? '' : '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'}'
      '</manifest><spine toc="ncx">'
      '${[for (var i = 0; i < names.length; i++) '<itemref idref="i$i"/>'].join()}'
      '</spine></package>';
  return epubOf(
    files,
    extra: {
      'content.opf': opf,
      if (nav != null) 'nav.xhtml': '<html><body>$nav</body></html>',
      if (ncx != null) 'toc.ncx': '<ncx><navMap>$ncx</navMap></ncx>',
    },
  );
}

/// The same EPUB without its `nav.xhtml` and NCX: a chapter per file.
Uint8List withoutContents(Uint8List epub) {
  final archive = Archive();
  for (final file in ZipDecoder().decodeBytes(epub)) {
    final name = file.name.toLowerCase();
    if (file.isFile && !name.endsWith('nav.xhtml') && !name.endsWith('.ncx')) {
      archive.addFile(ArchiveFile.bytes(file.name, file.content));
    }
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Chapters as `title: #level heading | paragraph | ***`.
List<String> chaptersOf(BookContent book) => [
  for (final s in book.sections)
    '${s.title}: ${[for (final b in s.blocks) switch (b) {
        HeadingBlock(:final text, :final level) => '#$level $text',
        TextBlock(:final text) => text,
        _ => '***',
      }].join(' | ')}',
];

/// The contents as `title → section`, indented by level.
List<String> tocOf(BookContent book) => [
  for (final t in book.toc) '${'  ' * t.level}${t.title} → ${t.sectionIndex}',
];

List<String> textsOf(BookContent book) => [
  for (final s in book.sections)
    for (final b in s.blocks)
      if (b is TextBlock) b.text,
];

List<String> wordsOf(BookContent book) {
  final tokens = tokenize(book);
  return List.generate(tokens.length, tokens.textOf);
}

/// Blocks of one file as short strings: `#level text`, `[style] text`.
List<String> blocksOf(String body) => [
  for (final s in parseEpub(epubOf({'a.xhtml': body}), title: 'x').sections)
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
      'epub3_ru.epub',
      'epub2_gutenberg.epub',
      'cp1251.epub',
      'one_file.epub',
      'calibre_split.epub',
    ]) {
      test(name, () => expectSnapshot(parseFile(name), '$fixtures/$name'));
    }
  });

  group('epub3_ru.epub', () {
    final book = parseFile('epub3_ru.epub');

    test('metadata: main title, authors only, series, description', () {
      final meta = book.meta;
      expect(meta.title, 'Утро над рекой');
      expect(meta.authors, ['Анна Тестова', 'Пётр Соавтор']);
      expect(meta.series, 'Тестовые книги');
      expect(meta.seriesNumber, 2);
      expect(meta.lang, 'ru');
      expect(meta.annotation, 'Короткая повесть о тихом утре.\nВторая строка.');
      expect(meta.sourceFormat, SourceFormat.epub);
    });

    test('a chapter per spine file; cover, notes and css are dropped', () {
      expect(
        [for (final s in book.sections) s.title],
        ['Глава 1. Туман', 'Глава 2. Гости'],
      );
      expect(
        [for (final t in book.toc) (t.title, t.level, t.sectionIndex)],
        [('Глава 1. Туман', 0, 0), ('Глава 2. Гости', 0, 1)],
      );
    });

    test('footnote marks and texts are not words of the book', () {
      final words = tokenize(book).length;
      final text = jsonEncode(book.toJson());
      for (final gone in ['сноска', 'Сноска', '[2]', 'notText', 'Обложка']) {
        expect(text, isNot(contains(gone)), reason: gone);
      }
      expect(words, greaterThan(60));
    });
  });

  group('epub2_gutenberg.epub', () {
    final book = parseFile('epub2_gutenberg.epub');

    test('odd links still find their files; a missing one is skipped', () {
      // Title page (`%20`), Chapter1 (wrong case) with its continuation
      // (HTML, not in the NCX), broken.xhtml (`./..`, starts with a
      // heading); `lost.xhtml`, a repeat and a picture are not.
      expect(
        [for (final s in book.sections) s.title],
        [null, 'CHAPTER I.', 'CHAPTER II.'],
      );
      expect(
        (book.sections[1].blocks.last as TextBlock).text,
        'Another paragraph © 1900 & more.',
      );
      expect(book.sections.last.blocks.last, isA<ParagraphBlock>());
      expect(
        (book.sections.last.blocks.last as TextBlock).text,
        'The last words of the book.',
      );
    });

    test('calibre series, roles other than the author dropped', () {
      expect(book.meta.authors, ['Ann Tester']);
      expect(book.meta.series, 'Test Books');
      expect(book.meta.seriesNumber, 3);
    });

    test('broken markup keeps the text around it', () {
      final texts = [
        for (final b in book.sections[2].blocks) (b as TextBlock).text,
      ];
      expect(texts, [
        'CHAPTER II.',
        'Unquoted attribute, still a paragraph.',
        'Fish & chips, and 1 < 2 is true.',
        'Unknown &foo; entity stays.',
        'The last words of the book.',
      ]);
    });
  });

  test('windows-1251 declared in the file', () {
    final book = parseFile('cp1251.epub');
    expect(book.sections.single.title, 'Старая кодировка');
    expect(book.meta.title, 'cp1251.epub');
  });

  group('errors', () {
    test('DRM: rights.xml and encrypted text', () {
      expect(() => parseFile('drm.epub'), throwsA(isA<EpubDrmException>()));
    });

    test('encrypted text alone is DRM; obfuscated fonts are not', () {
      String encryption(String uri) =>
          '<encryption><EncryptedData><CipherData>'
          '<CipherReference URI="$uri"/></CipherData></EncryptedData>'
          '</encryption>';
      expect(
        () => parseEpub(
          epubOf(
            {'a.xhtml': '<p>Text</p>'},
            extra: {'META-INF/encryption.xml': encryption('a.xhtml')},
          ),
          title: 'x',
        ),
        throwsA(isA<EpubDrmException>()),
      );
      expect(
        parseEpub(
          epubOf(
            {'a.xhtml': '<p>Text</p>'},
            extra: {'META-INF/encryption.xml': encryption('font.otf')},
          ),
          title: 'x',
        ).sections,
        hasLength(1),
      );
    });

    test('no text and only fonts encrypted: damaged, not DRM', () {
      expect(
        () => parseEpub(
          epubOf(
            {'a.xhtml': '<img src="a.png"/>'},
            extra: {
              'META-INF/encryption.xml':
                  '<encryption><CipherReference URI="f.otf"/></encryption>',
            },
          ),
          title: 'x',
        ),
        throwsA(isA<NotEpubException>()),
      );
    });

    test('junk series number is no number', () {
      final book = parseEpub(
        epubOf(
          {'a.xhtml': '<p>Текст</p>'},
          extra: {
            'content.opf':
                '<package><metadata>'
                '<meta name="calibre:series" content="Серия"/>'
                '<meta name="calibre:series_index" content="Infinity"/>'
                '</metadata><manifest><item id="a" href="a.xhtml" '
                'media-type="application/xhtml+xml"/></manifest>'
                '<spine><itemref idref="a"/></spine></package>',
          },
        ),
        title: 'x',
      );
      expect(book.meta.series, 'Серия');
      expect(book.meta.seriesNumber, isNull);
    });

    test('no text and a DRM file: DRM, not damaged', () {
      expect(
        () => parseEpub(
          epubOf({'a.xhtml': ''}, extra: {'META-INF/rights.xml': '<rights/>'}),
          title: 'x',
        ),
        throwsA(isA<EpubDrmException>()),
      );
    });

    test('empty spine, no OPF, no text, not a ZIP: damaged', () {
      final cases = {
        'empty spine': fixture('empty_spine.epub'),
        'no opf': epubOf({'a.xhtml': '<p>a</p>'}, extra: {'content.opf': ''}),
        'only pictures': epubOf({'a.xhtml': '<img src="a.png"/>'}),
        'not a zip': Uint8List.fromList(utf8.encode('<p>a</p>')),
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        expect(
          () => parseEpub(value, title: 'x'),
          throwsA(isA<NotEpubException>()),
          reason: key,
        );
      }
    });

    test('container.xml pointing nowhere: any .opf is taken', () {
      final book = parseEpub(
        epubOf(
          {'a.xhtml': '<p>Text</p>'},
          extra: {
            'META-INF/container.xml':
                '<container><rootfiles><rootfile full-path="nope.opf"/>'
                '</rootfiles></container>',
          },
        ),
        title: 'x',
      );
      expect(book.sections, hasLength(1));
    });

    test('parseBook maps the errors', () {
      expect(
        () => parseBook(fixture('drm.epub'), fileName: 'drm.epub'),
        throwsA(
          isA<ImportException>().having(
            (e) => e.error,
            'error',
            ImportError.drm,
          ),
        ),
      );
      expect(
        () => parseBook(fixture('empty_spine.epub'), fileName: 'e.epub'),
        throwsA(
          isA<ImportException>().having(
            (e) => e.error,
            'error',
            ImportError.damaged,
          ),
        ),
      );
      final parsed = parseBook(fixture('epub3_ru.epub'), fileName: 'a.epub');
      expect(parsed.parserVersion, epubParserVersion);
      expect(parsed.wordCount, greaterThan(60));
    });
  });

  group('xhtml', () {
    test('headings by level, lines of a heading joined for the contents', () {
      expect(
        blocksOf('<h3>Часть<br/>первая</h3><h1><p>Глава</p><p>1</p></h1>'),
        ['#3 Часть\nпервая', '#1 Глава\n1'],
      );
    });

    test('a note link is dropped only when it looks like a mark', () {
      expect(
        blocksOf(
          '<p>Раз<a href="n.xhtml#1">[1]</a>, два<a href="n.xhtml#2">*</a>, '
          'три<a href="n.xhtml#x"><sup>3</sup></a>, '
          'четыре<a href="notes.xhtml#x">4</a>, пять<a href="#n_5">5</a>, '
          'см. <a href="c.xhtml#c3">главу 3</a>, '
          'в <a href="#y1812">1812</a> году.</p>',
        ),
        ['Раз, два, три, четыре, пять, см. главу 3, в 1812 году.'],
      );
    });

    test('a span around whole paragraphs reaches them', () {
      final book = parseEpub(
        epubOf({'a.xhtml': '<em><p>Один</p><p>Два</p></em><p>Три</p>'}),
        title: 'x',
      );
      expect(
        [
          for (final b in book.sections.single.blocks)
            [for (final s in (b as TextBlock).spans) s.kind],
        ],
        [
          [SpanKind.emphasis],
          [SpanKind.emphasis],
          <SpanKind>[],
        ],
      );
    });

    test('a heading never closed does not swallow the chapter', () {
      final long = 'слово ' * 50;
      final blocks = blocksOf('<h2>Глава<div><p>$long</p><p>Ещё</p></div>');
      expect(blocks.first, startsWith('#2 Глава'));
      expect(blocks.last, 'Ещё');
    });

    test('hidden navigation is not text', () {
      expect(
        blocksOf(
          '<nav epub:type="landmarks"><a href="a.xhtml">Начало</a></nav>'
          '<nav hidden=""><a href="b.xhtml">Список</a></nav><p>Текст</p>',
        ),
        ['Текст'],
      );
    });

    test('spans stay on their words after a dropped mark and indents', () {
      final book = parseEpub(
        epubOf({
          'a.xhtml':
              '<p>&nbsp;&nbsp;Он<a href="#n1">1</a> <em>шёл</em> домой</p>',
        }),
        title: 'x',
      );
      final block = book.sections.single.blocks.single as ParagraphBlock;
      expect(block.text, 'Он шёл домой');
      final span = block.spans.single;
      expect(block.text.substring(span.start, span.end), 'шёл');
    });

    test('poems, epigraphs and quotes by class or tag', () {
      expect(
        blocksOf(
          '<div class="epigraph"><div class="poem"><p>Э</p></div></div>'
          '<div class="stanza"><p>Стих</p></div>'
          '<p class="cite">Цитата</p><blockquote>Тоже</blockquote>'
          '<p class="subtitle">Подзаголовок</p>',
        ),
        [
          '[epigraph] Э',
          '[poem] Стих',
          '[quote] Цитата',
          '[quote] Тоже',
          '[subtitle] Подзаголовок',
        ],
      );
    });

    test('separators: hr and stars, never two in a row or first', () {
      expect(blocksOf('<hr/><p>а</p><hr/><p>* * *</p><hr/><p>б</p>'), [
        'а',
        '***',
        'б',
      ]);
    });

    test('blank paragraphs are dropped', () {
      expect(blocksOf('<p>&nbsp;</p><p> </p><p>а</p><div>\n</div>'), ['а']);
    });
  });

  group('chapters', () {
    test('one file cut by the anchors of a nested nav', () {
      final book = parseFile('one_file.epub');
      expect(tocOf(book), [
        // Not in the contents, but the file starts with a heading.
        'Одна книга → 0',
        'Часть первая → 1',
        '  I → 2',
        '  II → 3',
        // Its anchor is lost: it goes with II, no text is lost.
        '  III → 3',
        'Часть вторая → 4',
        '  IV → 5',
        // A label without a link points where its first child does.
        'Приложения → 6',
        '  Письма → 6',
      ]);
      expect(chaptersOf(book), [
        'Одна книга: #1 Одна книга | Предисловие без ссылки в оглавлении.',
        'Часть первая: #2 Часть первая',
        // `I` is a plain paragraph in the file: the contents makes it the
        // heading.
        'I: #2 I | Первая глава, один абзац. | Второй абзац первой главы.',
        'II: #2 II | Вторая глава. Здесь якорь не тот. | III | '
            'Третья глава без своего якоря остаётся во второй.',
        'Часть вторая: #2 Часть вторая | Вступление ко второй части.',
        'IV: #2 IV | Четвёртая глава до конца файла.',
        'Приложения: #3 Письма | Письмо первое. | '
            'Продолжение писем, без ссылки и без заголовка.',
      ]);
    });

    test('calibre split: nested NCX, a file goes on the chapter before', () {
      final book = parseFile('calibre_split.epub');
      expect(tocOf(book), [
        'Part One → 1',
        '  Chapter 1 → 2',
        '  Chapter 2 → 3',
        '    A Letter → 4',
        '  Afterword → 5',
      ]);
      expect(
        [for (final s in book.sections) s.title],
        [
          null,
          'Part One',
          'Chapter 1',
          'Chapter 2',
          'A Letter',
          // Not in the contents, but the file starts with a heading.
          'Afterword',
        ],
      );
      expect(book.sections[2].blocks, hasLength(3));
    });

    test('words are neither lost nor repeated by the cuts', () {
      for (final name in [
        'one_file.epub',
        'calibre_split.epub',
        'epub2_gutenberg.epub',
        'epub3_ru.epub',
      ]) {
        final bytes = fixture(name);
        final cut = parseEpub(bytes, title: name);
        final whole = parseEpub(withoutContents(bytes), title: name);
        expect(textsOf(cut), textsOf(whole), reason: name);
        expect(wordsOf(cut), wordsOf(whole), reason: name);
      }
    });

    test('anchors: a heading begun goes after, a paragraph ended before', () {
      final id = Uri.encodeComponent('глава 3');
      final book = parseEpub(
        epubWithContents(
          {
            'Text/a.xhtml':
                '<p>Пролог.</p><h2>Глава <a id="c1"/>первая</h2>'
                '<p>Текст.<a name="c2"></a></p><p>Хвост.</p>'
                '<p id="глава 3">Третья</p><p>Конец.</p>',
          },
          nav:
              '<nav epub:type="toc"><ol>'
              '<li><a href="text/A.XHTML#c1">Первая</a></li>'
              '<li><a href="Text/a.xhtml#c2">Вторая</a></li>'
              '<li><a href="Text/a.xhtml#$id">Третья</a></li>'
              '</ol></nav>',
        ),
        title: 'x',
      );
      expect(chaptersOf(book), [
        'null: Пролог.',
        'Первая: #2 Глава первая | Текст.',
        'Вторая: Хвост.',
        'Третья: #1 Третья | Конец.',
      ]);
    });

    test('NCX: levels, a lost anchor, links out of the book dropped', () {
      String point(String title, String src, [String inner = '']) =>
          '<navPoint><navLabel><text>$title</text></navLabel>'
          '<content src="$src"/>$inner</navPoint>';
      final book = parseEpub(
        epubWithContents(
          {
            'a.xhtml': '<h1>Часть 1</h1><h2 id="g1">Глава 1</h2><p>Раз.</p>',
            'b.xhtml': '<h2>Глава 2</h2><p>Два.</p>',
            'c.xhtml': '<p>Ещё два.</p>',
            'd.xhtml': '<h3>Послесловие</h3><p>Три.</p>',
          },
          ncx:
              point(
                'Часть 1',
                'a.xhtml',
                point('Глава 1', 'a.xhtml#g1') +
                    point(
                      'Глава 2',
                      'b.xhtml',
                      point('Письмо', 'b.xhtml#nope'),
                    ),
              ) +
              point('Сайт', 'http://example.com/') +
              point('Картинка', 'cover.jpg'),
        ),
        title: 'x',
      );
      expect(chaptersOf(book), [
        'Часть 1: #1 Часть 1',
        'Глава 1: #2 Глава 1 | Раз.',
        'Глава 2: #2 Глава 2 | Два. | Ещё два.',
        'Послесловие: #3 Послесловие | Три.',
      ]);
      expect(tocOf(book), [
        'Часть 1 → 0',
        '  Глава 1 → 1',
        '  Глава 2 → 2',
        '    Письмо → 2',
        '  Послесловие → 3',
      ]);
    });

    test('links to places without text go to the next or last chapter', () {
      final book = parseEpub(
        epubWithContents(
          {
            'cover.xhtml': '<svg><title>Обложка</title></svg>',
            'ch.xhtml': '<p>Текст главы.</p>',
            'back.xhtml': '<div>&nbsp;</div>',
          },
          nav:
              '<nav epub:type="toc"><ol>'
              '<li><a href="cover.xhtml">Обложка</a></li>'
              '<li><a href="ch.xhtml">Глава</a></li>'
              '<li><a href="back.xhtml">Задняя обложка</a></li>'
              '</ol></nav>',
        ),
        title: 'x',
      );
      expect(chaptersOf(book), ['Глава: Текст главы.']);
      expect(tocOf(book), ['Обложка → 0', 'Глава → 0', 'Задняя обложка → 0']);
    });

    test('chapters numbered I, II… as paragraphs (Wikisource)', () {
      const story =
          '<p>Эпиграф.</p><div>I</div><p>Раз.</p><p>II.</p><p>Два.</p>'
          '<p>IV</p><p>Не по порядку.</p><p>III</p><p>Три.</p>';
      final withNav = parseEpub(
        epubWithContents(
          {'t.xhtml': '<h1>Повесть</h1>', 'a.xhtml': story},
          nav:
              '<nav epub:type="toc"><ol><li><a href="t.xhtml">Заглавие</a>'
              '</li><li><a href="a.xhtml">Повесть</a></li></ol></nav>',
        ),
        title: 'x',
      );
      expect(chaptersOf(withNav), [
        'Заглавие: #1 Повесть',
        'Повесть: Эпиграф.',
        'I: #2 I | Раз.',
        'II.: #2 II. | Два. | IV | Не по порядку.',
        'III: #2 III | Три.',
      ]);
      expect(tocOf(withNav), [
        'Заглавие → 0',
        'Повесть → 1',
        '  I → 2',
        '  II. → 3',
        '  III → 4',
      ]);
      final plain = parseEpub(epubOf({'a.xhtml': story}), title: 'x');
      expect(tocOf(plain), ['I → 1', 'II. → 2', 'III → 3']);
      expect(textsOf(plain), textsOf(withNav).skip(1));
    });

    test('nav decorations; numbers go on into the next file, once', () {
      final book = parseEpub(
        epubWithContents(
          {
            'cover.xhtml': '<svg/>',
            'title.xhtml': '<p>Титул.</p>',
            'a.xhtml': '<p>I</p><p>Раз.</p><p>II</p><p>Два.</p>',
            'b.xhtml': '<p>Ещё два.</p><p>III</p><p>Три.</p>',
          },
          nav:
              '<nav epub:type="toc"><h2><span>Содержание</span></h2><ol>'
              '<li><a href="cover.xhtml">Обложка</a></li>'
              '<li><span class="num">1.</span> <a href="a.xhtml">Глава</a>'
              ' <span>(начало)</span></li></ol></nav>',
        ),
        title: 'x',
      );
      expect(chaptersOf(book), [
        // The cover's link does not name the title page.
        'null: Титул.',
        'Глава: #2 I | Раз.',
        'II: #2 II | Два. | Ещё два.',
        'III: #2 III | Три.',
      ]);
      expect(tocOf(book), [
        'Обложка → 0',
        'Глава → 1',
        '  II → 2',
        '  III → 3',
      ]);
    });

    test('a lone I, a run not from I, verses and cut files stay text', () {
      expect(blocksOf('<p>I</p><p>Раз.</p><p>III</p>'), ['I', 'Раз.', 'III']);
      expect(blocksOf('<p>II</p><p>III</p>'), ['II', 'III']);
      expect(blocksOf('<div class="poem"><p>I</p><p>II</p></div>'), [
        '[poem] I',
        '[poem] II',
      ]);
      final cut = parseEpub(
        epubWithContents(
          {'a.xhtml': '<p>I</p><p>Раз.</p><h2 id="g">Глава</h2><p>II</p>'},
          nav:
              '<nav epub:type="toc"><ol><li><a href="a.xhtml#g">Глава</a>'
              '</li></ol></nav>',
        ),
        title: 'x',
      );
      expect(chaptersOf(cut), ['null: I | Раз.', 'Глава: #2 Глава | II']);
    });

    test('contents leading nowhere: a chapter per file', () {
      final book = parseEpub(
        epubWithContents(
          {'a.xhtml': '<h1>Один</h1><p>Раз.</p>', 'b.xhtml': '<p>Два.</p>'},
          nav:
              '<nav epub:type="toc"><ol><li><a href="gone.xhtml">Нет</a>'
              '</li></ol></nav>',
        ),
        title: 'x',
      );
      expect(chaptersOf(book), ['Один: #1 Один | Раз.', 'null: Два.']);
      expect(tocOf(book), ['Один → 0']);
    });
  });
}
