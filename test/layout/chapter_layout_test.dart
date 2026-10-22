import 'dart:io';
import 'dart:ui' show Paragraph;

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/layout/chapter_layout.dart';
import 'package:book_app/layout/hyphenation.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sample_book.dart';

const _sizes = [Size(320, 520), Size(200, 260), Size(700, 380)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Hyphenation hyphenation;

  setUpAll(() async => hyphenation = await Hyphenation.load());

  PageStyle hyphenated(PageStyle base) => PageStyle(
    fontFamily: base.fontFamily,
    fontSize: base.fontSize,
    lineHeight: base.lineHeight,
    color: base.color,
    align: base.align,
    hyphenation: hyphenation,
  );

  PageStyle style({double fontSize = 18}) => PageStyle(
    fontFamily: 'Literata',
    fontSize: fontSize,
    color: const Color(0xFF000000),
  );

  /// Reading settings mixes (ADR 0003, addendum 2): fonts, sizes, line
  /// heights, justify.
  const mixes = [
    PageStyle(
      fontFamily: 'PT Serif',
      fontSize: 14,
      lineHeight: 1.3,
      color: Color(0xFF000000),
      align: TextAlign.justify,
    ),
    PageStyle(
      fontFamily: 'Lora',
      fontSize: 32,
      lineHeight: 1.8,
      color: Color(0xFF000000),
      align: TextAlign.justify,
    ),
    PageStyle(
      fontFamily: 'Noto Serif',
      fontSize: 22,
      lineHeight: 2,
      color: Color(0xFF000000),
    ),
  ];

  ChapterLayout build(BookTokens tokens, int s, Size size, PageStyle st) =>
      ChapterLayout.build(
        tokens: tokens,
        sectionIndex: s,
        style: st,
        pageSize: size,
      );

  /// Pages split the chapter's words without gaps or repeats, each word is
  /// on the page that claims it, and every text block is shown whole.
  void expectExactSplit(BookTokens tokens, ChapterLayout layout) {
    final s = layout.sectionIndex;
    final start = tokens.firstWordOfSection(s);
    final end = tokens.firstWordOfSection(s + 1);
    final pages = layout.pages;
    final blocks = tokens.content.sections[s].blocks;
    if (pages.isEmpty) {
      expect(end, start, reason: 'only an empty chapter has no pages');
      return;
    }
    expect(pages.first.firstWord, start);
    expect(pages.last.endWord, end);
    for (var p = 0; p + 1 < pages.length; p++) {
      expect(pages[p].endWord, pages[p + 1].firstWord, reason: 'page $p');
    }
    for (final (p, page) in pages.indexed) {
      expect(page.firstWord, lessThanOrEqualTo(page.endWord));
      for (var w = page.firstWord; w < page.endWord; w++) {
        final t = tokens[w];
        final visible = page.slices.any(
          (sl) =>
              sl.blockIndex == t.blockIndex &&
              sl.charStart <= t.charStart &&
              t.charStart < sl.charEnd,
        );
        expect(visible, isTrue, reason: 'word $w "${t.text}" on page $p');
      }
    }
    final shown = <int, int>{};
    for (final sl in pages.expand((p) => p.slices)) {
      if (blocks[sl.blockIndex] is! TextBlock) continue;
      expect(sl.charStart, shown[sl.blockIndex] ?? 0, reason: 'no text lost');
      shown[sl.blockIndex] = sl.charEnd;
    }
    for (final (b, block) in blocks.indexed) {
      if (block is TextBlock) {
        expect(shown[b], block.text.length, reason: 'block $b shown to end');
      }
    }
  }

  /// Every word on a page has boxes there, and touching the middle of each
  /// box finds that word (long press → speed reading, ADR 0003 п. 3).
  void expectWordsTouchable(ChapterLayout layout) {
    for (final (p, page) in layout.pages.indexed) {
      for (var w = page.firstWord; w < page.endWord; w++) {
        final boxes = layout.wordBoxes(p, w);
        expect(boxes, isNotEmpty, reason: 'word $w has boxes on page $p');
        for (final box in boxes) {
          expect(
            layout.wordAt(p, box.center),
            w,
            reason: 'word $w at ${box.center} on page $p',
          );
        }
      }
    }
  }

  /// The book-wide pass (ADR 0003, addendum 2 п. 5), one block per step,
  /// gives the same pages as the layout shown on screen.
  void expectSameAsPaginator(BookTokens tokens, ChapterLayout layout) {
    final paginator = ChapterPaginator(
      tokens: tokens,
      sectionIndex: layout.sectionIndex,
      style: layout.style,
      pageSize: layout.pageSize,
    );
    final blocks = tokens.content.sections[layout.sectionIndex].blocks.length;
    var steps = 0;
    while (!paginator.step(Duration.zero)) {
      steps++;
    }
    expect(steps, blocks == 0 ? 0 : blocks - 1, reason: 'a block per step');
    expect(paginator.pageFirstWords, [
      for (final page in layout.pages) page.firstWord,
    ], reason: 'chapter ${layout.sectionIndex} at ${layout.pageSize}');
  }

  void expectBookSplits(
    BookContent content, {
    List<Size> sizes = _sizes,
    PageStyle? pageStyle,
  }) {
    final tokens = tokenize(content);
    for (final size in sizes) {
      for (var s = 0; s < content.sections.length; s++) {
        final layout = build(tokens, s, size, pageStyle ?? style());
        expectExactSplit(tokens, layout);
        expectWordsTouchable(layout);
        expectSameAsPaginator(tokens, layout);
        layout.dispose();
      }
    }
  }

  test('a generated book splits exactly at several page sizes', () {
    expectBookSplits(sampleBook());
  });

  test('settings mixes split exactly', () {
    for (final mix in mixes) {
      expectBookSplits(sampleBook(), pageStyle: mix);
      expectBookSplits(sampleBook(), pageStyle: hyphenated(mix));
    }
  });

  test('only the color is not a layout change', () {
    final base = style();
    const black = Color(0xFF000000);
    PageStyle with_({
      String font = 'Literata',
      double size = 18,
      double height = 1.45,
      Color color = black,
      TextAlign align = TextAlign.left,
    }) => PageStyle(
      fontFamily: font,
      fontSize: size,
      lineHeight: height,
      color: color,
      align: align,
    );
    expect(with_(color: const Color(0xFFFFFFFF)).sameLayoutAs(base), isTrue);
    expect(with_(color: const Color(0xFFFFFFFF)) == base, isFalse);
    for (final other in [
      with_(font: 'Lora'),
      with_(size: 19),
      with_(height: 1.6),
      with_(align: TextAlign.justify),
      hyphenated(base),
    ]) {
      expect(other.sameLayoutAs(base), isFalse);
    }
  });

  test('a paragraph starts indented, left-aligned or justified', () {
    final tokens = tokenize(
      BookContent(
        meta: const BookMeta(title: 'Отступ', sourceFormat: SourceFormat.txt),
        sections: [
          Section(
            blocks: [
              for (var i = 0; i < 2; i++) ParagraphBlock(text: 'Слово ' * 40),
            ],
          ),
        ],
      ),
    );
    for (final align in [TextAlign.left, TextAlign.justify]) {
      final layout = build(
        tokens,
        0,
        _sizes.first,
        PageStyle(
          fontFamily: 'Literata',
          fontSize: 18,
          color: const Color(0xFF000000),
          align: align,
        ),
      );
      final second = layout.pages.first.firstWord + 40;
      for (final word in [layout.pages.first.firstWord, second]) {
        expect(
          layout.wordBoxes(0, word).first.left,
          // Two figure spaces: one em each in the test font.
          moreOrLessEquals(36, epsilon: 0.01),
          reason: '$align, word $word',
        );
      }
    }
  });

  test('touching outside words finds nothing; other pages have no boxes', () {
    final tokens = tokenize(sampleBook());
    final layout = build(tokens, 0, _sizes.first, style());
    final page = layout.pages[1];
    expect(layout.wordBoxes(1, page.firstWord), isNotEmpty);
    expect(layout.wordBoxes(0, page.firstWord), isEmpty);
    expect(layout.wordBoxes(1, tokens.firstWordOfSection(1)), isEmpty);
    expect(layout.wordAt(1, const Offset(100, -50)), isNull);
    expect(layout.wordAt(1, const Offset(100, 10000)), isNull);
    // Just after the chapter's last word still finds it; far after, nothing.
    final last = layout.pages.length - 1;
    final box = layout.wordBoxes(last, layout.pages[last].endWord - 1).last;
    expect(
      layout.wordAt(last, Offset(box.right + 2, box.center.dy)),
      isNotNull,
    );
    expect(layout.wordAt(last, Offset(box.right + 60, box.center.dy)), isNull);
    layout.dispose();
  });

  test('pages are filled and a long chapter takes several pages', () {
    final tokens = tokenize(sampleBook(sections: 1, paragraphs: 60));
    final layout = build(tokens, 0, const Size(320, 520), style());
    expect(layout.pages.length, greaterThan(5));
    expect(layout.pages.every((p) => p.slices.isNotEmpty), isTrue);
    expect(layout.pageText(0), startsWith('Глава 1'));
    layout.dispose();
  });

  test('a heading is not left alone at the bottom of a page', () {
    final tokens = tokenize(sampleBook(sections: 1, paragraphs: 60));
    for (final size in _sizes) {
      final layout = build(tokens, 0, size, style());
      final blocks = tokens.content.sections[0].blocks;
      for (final page in layout.pages) {
        expect(blocks[page.slices.last.blockIndex], isNot(isA<HeadingBlock>()));
      }
      layout.dispose();
    }
  });

  test('the same word stays on screen after a page size or font change', () {
    final tokens = tokenize(sampleBook(sections: 1, paragraphs: 80));
    final before = build(tokens, 0, const Size(320, 520), style());
    final layouts = [
      for (final size in _sizes) build(tokens, 0, size, style(fontSize: 24)),
      build(tokens, 0, const Size(320, 520), style(fontSize: 14)),
    ];
    for (final page in before.pages.where((p) => p.hasWords)) {
      final word = page.firstWord;
      for (final after in layouts) {
        final shown = after.pages[after.pageOfWord(word)];
        expect(shown.firstWord, lessThanOrEqualTo(word));
        expect(shown.endWord, greaterThan(word));
      }
    }
    before.dispose();
    for (final layout in layouts) {
      layout.dispose();
    }
  });

  test('test books split exactly', () {
    final files = [
      ...Directory('test/fixtures/fb2').listSync(),
      ...Directory('test/fixtures/txt').listSync(),
      for (final name in [
        'epub3_ru',
        'epub2_gutenberg',
        'cp1251',
        'one_file',
        'calibre_split',
      ])
        File('test/fixtures/epub/$name.epub'),
    ].whereType<File>().where((f) => !f.path.endsWith('.json'));
    expect(files, isNotEmpty);
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      expectBookSplits(
        parseBook(file.readAsBytesSync(), fileName: name).content,
      );
    }
  });

  test('test books split exactly with hyphens', () {
    final files = [
      ...Directory('test/fixtures/fb2').listSync(),
      ...Directory('test/fixtures/txt').listSync(),
      File('test/fixtures/epub/epub3_ru.epub'),
      File('test/fixtures/epub/epub2_gutenberg.epub'),
    ].whereType<File>().where((f) => !f.path.endsWith('.json'));
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      expectBookSplits(
        parseBook(file.readAsBytesSync(), fileName: name).content,
        sizes: const [Size(200, 260), Size(320, 520)],
        pageStyle: hyphenated(mixes.first),
      );
    }
  });

  test('a word broken at a line end: two boxes, one word, a drawn «-»', () {
    const text =
        'Сельскохозяйственный рыцарь подъезжал к замку, '
        'перепрыгивая через препятствия и размахивая неимоверно '
        'тяжёлым мечом.';
    final tokens = tokenize(
      const BookContent(
        meta: BookMeta(title: 'Переносы', sourceFormat: SourceFormat.txt),
        sections: [
          Section(blocks: [ParagraphBlock(text: text)]),
        ],
      ),
    );
    const size = Size(500, 2000);
    final plain = build(tokens, 0, size, style());
    final layout = build(tokens, 0, size, hyphenated(style()));
    expectExactSplit(tokens, layout);
    expectWordsTouchable(layout);
    final broken = [
      for (var w = 0; w < tokens.length; w++)
        if (layout.wordBoxes(0, w).length == 2) w,
    ];
    expect(broken, isNotEmpty, reason: 'some words break');
    for (var w = 0; w < tokens.length; w++) {
      expect(plain.wordBoxes(0, w), hasLength(1), reason: 'whole words');
    }
    expect(layout.pageText(0), text, reason: 'no hyphens in the text');

    int paragraphsPainted(ChapterLayout l) {
      final canvas = _CountingCanvas();
      l.paintPage(canvas, 0);
      return canvas.paragraphs;
    }

    expect(paragraphsPainted(plain), 1);
    expect(paragraphsPainted(layout), 1 + broken.length, reason: 'a «-» each');
    plain.dispose();
    layout.dispose();
  });

  test('parts of a very long chapter split exactly, words touchable', () {
    final tokens = tokenize(
      BookContent(
        meta: const BookMeta(title: 'Огромная', sourceFormat: SourceFormat.txt),
        sections: [
          Section(
            blocks: [
              for (var i = 0; i < 260; i++)
                ParagraphBlock(text: List.filled(80, 'слово$i').join(' ')),
            ],
          ),
          const Section(blocks: [ParagraphBlock(text: 'Вторая глава.')]),
        ],
      ),
    );
    final sections = tokens.content.sections;
    expect(sections.length, greaterThan(3), reason: 'split into parts');
    for (var s = 0; s < sections.length; s++) {
      final layout = build(tokens, s, const Size(320, 520), style());
      expectExactSplit(tokens, layout);
      expectWordsTouchable(layout);
      layout.dispose();
    }
  });

  test('soft hyphens from the book get a «-» with hyphenation off', () {
    // Some books carry their own soft hyphens; the engine breaks there too.
    final text = [
      for (var i = 0; i < 12; i++)
        'Сель$softHyphenско$softHyphenхо$softHyphenзяй',
    ].join(' ');
    final tokens = tokenize(
      BookContent(
        meta: const BookMeta(title: 'Переносы', sourceFormat: SourceFormat.txt),
        sections: [
          Section(blocks: [ParagraphBlock(text: text)]),
        ],
      ),
    );
    final layout = build(tokens, 0, const Size(330, 2000), style());
    final broken = [
      for (var w = 0; w < tokens.length; w++)
        if (layout.wordBoxes(0, w).length == 2) w,
    ];
    expect(broken, isNotEmpty, reason: 'some words break');
    final canvas = _CountingCanvas();
    layout.paintPage(canvas, 0);
    expect(canvas.paragraphs, 1 + broken.length, reason: 'a «-» each');
    layout.dispose();
  });

  // Big real books live outside the repository (ADR 0006): set
  // BOOKAPP_HARD_BOOKS to their folder to check them too.
  final hardBooks = Platform.environment['BOOKAPP_HARD_BOOKS'];
  test(
    'books from BOOKAPP_HARD_BOOKS split exactly',
    () {
      for (final file in Directory(hardBooks!).listSync().whereType<File>()) {
        final name = file.uri.pathSegments.last;
        expectBookSplits(
          parseBook(file.readAsBytesSync(), fileName: name).content,
          sizes: const [Size(360, 640)],
        );
      }
    },
    skip: hardBooks == null ? 'BOOKAPP_HARD_BOOKS is not set' : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Counts the text painted on it; other calls do nothing.
final class _CountingCanvas implements Canvas {
  int paragraphs = 0;

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) => paragraphs++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
