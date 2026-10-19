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
      // Title page (`%20`), Chapter1 (wrong case), its continuation (HTML),
      // broken.xhtml (`./..`); `lost.xhtml`, a repeat and a picture are not.
      expect(book.sections, hasLength(4));
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
        for (final b in book.sections[3].blocks) (b as TextBlock).text,
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
}
