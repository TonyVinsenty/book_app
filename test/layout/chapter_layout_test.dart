import 'dart:io';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/layout/chapter_layout.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sample_book.dart';

const _sizes = [Size(320, 520), Size(200, 260), Size(700, 380)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PageStyle style({double fontSize = 18}) => PageStyle(
    fontFamily: 'Literata',
    fontSize: fontSize,
    color: const Color(0xFF000000),
  );

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

  void expectBookSplits(BookContent content, {List<Size> sizes = _sizes}) {
    final tokens = tokenize(content);
    for (final size in sizes) {
      for (var s = 0; s < content.sections.length; s++) {
        final layout = build(tokens, s, size, style());
        expectExactSplit(tokens, layout);
        expectWordsTouchable(layout);
        layout.dispose();
      }
    }
  }

  test('a generated book splits exactly at several page sizes', () {
    expectBookSplits(sampleBook());
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
    ].whereType<File>().where((f) => !f.path.endsWith('.json'));
    expect(files, isNotEmpty);
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      expectBookSplits(
        parseBook(file.readAsBytesSync(), fileName: name).content,
      );
    }
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
