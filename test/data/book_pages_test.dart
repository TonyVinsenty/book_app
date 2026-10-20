import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/data/book_pages.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/layout/hyphenation.dart';
import 'package:book_app/layout/page_cache.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const black = Color(0xFF000000);
  const style = PageStyle(fontFamily: 'Literata', color: black);
  const size = Size(320, 520);
  final styleKey = styleKeyOf(style: style, pageSize: size);

  BookPages pages({
    int words = 600,
    required int at,
    ChapterPages? cached,
    LastLayout? last,
  }) => bookPagesOf(
    words: words,
    positionWord: at,
    style: style,
    pageSize: size,
    cached: cached,
    last: last,
  );

  group('bookPagesOf', () {
    test('a full saved split: exact, the page with the place', () {
      const cached = <List<int>?>[
        [0, 120, 250],
        [],
        [400, 520],
      ];
      for (final (at, current) in [
        (0, 1),
        (119, 1),
        (120, 2),
        (399, 3),
        (400, 4),
        (599, 5),
      ]) {
        expect(pages(at: at, cached: cached), (
          total: 5,
          current: current,
          exact: true,
        ), reason: 'word $at');
      }
    });

    test('pages without words: the place is on the page with words', () {
      // Chapter 1 ends with a picture page that shares chapter 2's start;
      // the book ends with one more such page.
      const cached = <List<int>?>[
        [0, 100],
        [100, 300, 600],
      ];
      expect(pages(at: 100, cached: cached).current, 3);
      expect(pages(at: 99, cached: cached).current, 1);
      expect(pages(at: 599, cached: cached).current, 4);
      expect(pages(at: 0, cached: cached).total, 5);
    });

    test('a split not done is an estimate', () {
      const cached = <List<int>?>[
        [0, 120, 250],
        null,
      ];
      final last = LastLayout(
        pageSize: size,
        styleKey: styleKey,
        wordsPerPage: 150,
      );
      expect(pages(at: 300, cached: cached, last: last), (
        total: 4,
        current: 3,
        exact: false,
      ));
    });

    test('an estimate from the words per page of the same look', () {
      final last = LastLayout(
        pageSize: size,
        styleKey: styleKey,
        wordsPerPage: 250,
      );
      for (final (at, current) in [(0, 1), (249, 1), (500, 3), (1000, 4)]) {
        expect(pages(words: 1000, at: at, last: last), (
          total: 4,
          current: current,
          exact: false,
        ), reason: 'word $at');
      }
    });

    test('another look or none: a rough estimate from the page and font', () {
      // 18 px, 1.45 lines on 320 × 520: about 118 words a page.
      final other = LastLayout(
        pageSize: const Size(300, 520),
        styleKey: styleKeyOf(style: style, pageSize: const Size(300, 520)),
        wordsPerPage: 250,
      );
      for (final last in [null, other]) {
        final rough = pages(words: 11800, at: 5900, last: last);
        expect(rough.exact, isFalse);
        expect(rough.total, inInclusiveRange(95, 105));
        expect(rough.current, rough.total ~/ 2 + 1);
      }
      final larger = bookPagesOf(
        words: 11800,
        positionWord: 0,
        style: const PageStyle(
          fontFamily: 'Literata',
          fontSize: 24,
          color: black,
        ),
        pageSize: size,
      );
      expect(larger.total, greaterThan(pages(words: 11800, at: 0).total));
    });

    test('a book without words has no pages', () {
      expect(pages(words: 0, at: 0), (total: 0, current: 0, exact: true));
    });
  });

  group('LastLayout', () {
    test('comes back from its text; broken text is none', () {
      final layout = LastLayout(
        pageSize: const Size(312.5, 640),
        styleKey: styleKey,
        wordsPerPage: 183.4,
      );
      expect(LastLayout.decode(layout.encode()), layout);
      final noDensity = LastLayout(pageSize: size, styleKey: styleKey);
      expect(LastLayout.decode(noDensity.encode()), noDensity);
      for (final text in [
        null,
        '',
        'not json',
        '[]',
        '{"w": 0, "h": 520, "style": "x"}',
        '{"w": 320, "h": 520}',
        '{"w": "320", "h": 520, "style": "x"}',
      ]) {
        expect(LastLayout.decode(text), isNull, reason: text);
      }
      expect(
        LastLayout.decode('{"w": 320, "h": 520, "style": "x", "wpp": -1}'),
        LastLayout(pageSize: size, styleKey: 'x'),
      );
    });

    test('keeps the words per page for the same look only', () {
      final before = LastLayout(
        pageSize: size,
        styleKey: styleKey,
        wordsPerPage: 200,
      );
      expect(
        LastLayout.update(before, pageSize: size, styleKey: styleKey),
        before,
      );
      expect(
        LastLayout.update(
          before,
          pageSize: size,
          styleKey: styleKey,
          wordsPerPage: 210,
        ).wordsPerPage,
        210,
      );
      expect(
        LastLayout.update(
          before,
          pageSize: const Size(300, 520),
          styleKey: 'other',
        ).wordsPerPage,
        isNull,
      );
      expect(
        LastLayout.update(null, pageSize: size, styleKey: styleKey),
        LastLayout(pageSize: size, styleKey: styleKey),
      );
    });
  });

  test('pageStyleOf follows the reading settings', () {
    final hyphenation = Hyphenation(
      russian: Hyphenator.fromTex('', leftMin: 2, rightMin: 2),
      english: Hyphenator.fromTex('', leftMin: 2, rightMin: 3),
    );
    const settings = ReadingSettings(
      font: BookFont.lora,
      fontSize: 20,
      lineHeight: 1.6,
      align: BookAlign.justify,
    );
    final page = pageStyleOf(
      settings,
      system: const TextScaler.linear(2),
      color: black,
      hyphenation: hyphenation,
    );
    expect(page.fontFamily, BookFont.lora.family);
    expect(page.fontSize, 20, reason: 'the system scale is not applied');
    expect(page.textScaler, TextScaler.noScaling);
    expect(page.lineHeight, 1.6);
    expect(page.align, TextAlign.justify);
    expect(page.hyphenation, same(hyphenation));
    final plain = pageStyleOf(
      const ReadingSettings(hyphenate: false),
      system: TextScaler.noScaling,
      color: black,
      hyphenation: hyphenation,
    );
    expect(plain.hyphenation, isNull);
    expect(plain.align, TextAlign.left);
    expect(
      plain.fontSize,
      const ReadingSettings().fontSizeFor(TextScaler.noScaling),
    );
  });
}
