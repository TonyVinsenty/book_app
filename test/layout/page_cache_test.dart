import 'dart:io';

import 'package:book_app/layout/hyphenation.dart';
import 'package:book_app/layout/page_cache.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = PageStyle(fontFamily: 'Literata', color: Color(0xFF000000));
  const size = Size(320, 520);
  late Directory temp;
  late PageCache cache;
  late DateTime clock;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('pages_');
    clock = DateTime(2026, 10, 20);
    cache = PageCache(
      Directory('${temp.path}/pages'),
      now: () => clock = clock.add(const Duration(minutes: 1)),
    );
  });
  tearDown(() => temp.deleteSync(recursive: true));

  String keyOf(PageStyle style, [Size pageSize = size, int parser = 1]) =>
      layoutKeyOf(style: style, pageSize: pageSize, parserVersion: parser);

  const chapters = <List<int>?>[
    [0, 120, 250],
    null,
    [],
    [400, 520],
  ];
  ChapterPages? load(String key) => cache.load(key, sections: 4, words: 600);

  test('the key changes with every layout setting, not with the color', () {
    final key = keyOf(style);
    final others = {
      keyOf(const PageStyle(fontFamily: 'Lora', color: Color(0xFF000000))),
      keyOf(
        const PageStyle(
          fontFamily: 'Literata',
          fontSize: 19,
          color: Color(0xFF000000),
        ),
      ),
      keyOf(
        const PageStyle(
          fontFamily: 'Literata',
          lineHeight: 1.7,
          color: Color(0xFF000000),
        ),
      ),
      keyOf(
        const PageStyle(
          fontFamily: 'Literata',
          align: TextAlign.justify,
          color: Color(0xFF000000),
        ),
      ),
      keyOf(style, const Size(300, 520)),
      keyOf(style, const Size(320, 500)),
      keyOf(style, size, 2),
      keyOf(
        PageStyle(
          fontFamily: 'Literata',
          color: const Color(0xFF000000),
          hyphenation: Hyphenation(
            russian: Hyphenator.fromTex('', leftMin: 2, rightMin: 2),
            english: Hyphenator.fromTex('', leftMin: 2, rightMin: 3),
          ),
        ),
      ),
    };
    expect(others, hasLength(8));
    expect(others, isNot(contains(key)));
    expect(
      keyOf(const PageStyle(fontFamily: 'Literata', color: Color(0xFFFFFFFF))),
      key,
    );
    expect(keyOf(style, const Size(320.04, 520)), key, reason: 'rounded');
  });

  test('a deleted book folder is not made again', () {
    final gone = PageCache(Directory('${temp.path}/deleted/pages'));
    gone.save(keyOf(style), chapters);
    expect(Directory('${temp.path}/deleted').existsSync(), isFalse);
  });

  test('a saved split comes back for its key only', () {
    final key = keyOf(style);
    cache.save(key, chapters);
    expect(load(key), chapters);
    expect(load(keyOf(style, size, 2)), isNull);
    expect(cache.load(key, sections: 3, words: 600), isNull, reason: 'book');
  });

  test('pages without words come back too', () {
    // A separator-only page shares the next page's start; at the book's end
    // it starts at the word count.
    final key = keyOf(style);
    final withEmpty = <List<int>?>[
      [0, 100, 100],
      null,
      [],
      [400, 600],
    ];
    cache.save(key, withEmpty);
    expect(load(key), withEmpty);
  });

  test('a broken file is ignored and removed', () {
    final key = keyOf(style);
    for (final text in [
      'not json',
      '{"key": "other", "chapters": [[0], null, [], [400]]}',
      '{"key": "$key", "chapters": [[5, 3], null, [], [400]]}',
      '{"key": "$key", "chapters": [[0], null, [], [900]]}',
      '{"key": "$key", "chapters": [[0], "x", [], [400]]}',
    ]) {
      final file = cache.fileOf(key)
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
      expect(load(key), isNull, reason: text);
      expect(file.existsSync(), isFalse, reason: text);
    }
  });

  test('the style key is the same for every parser version', () {
    final key = styleKeyOf(style: style, pageSize: size);
    expect(key, isNot(keyOf(style)));
    expect(keyOf(style, size, 1), isNot(keyOf(style, size, 2)));
    expect(key, isNot(styleKeyOf(style: style, pageSize: const Size(300, 520))));
    expect(key, isNot(styleKeyOf(style: _sized(19), pageSize: size)));
  });

  test('peek: any chapter count, not marked as used, broken file kept', () {
    final key = keyOf(style);
    expect(cache.peek(key, words: 600), isNull);
    cache.save(key, chapters);
    final file = cache.fileOf(key);
    final saved = file.lastModifiedSync();
    expect(cache.peek(key, words: 600), chapters);
    expect(file.lastModifiedSync(), saved);
    expect(cache.peek(key, words: 500), isNull, reason: 'another book');
    expect(cache.peek(keyOf(style, size, 2), words: 600), isNull);
    file.writeAsStringSync('not json');
    expect(cache.peek(key, words: 600), isNull);
    expect(file.existsSync(), isTrue, reason: 'left to the reader');
  });

  test('only the three last used splits are kept', () {
    final keys = [for (var s = 14; s < 18; s++) keyOf(_sized(s.toDouble()))];
    cache.save(keys[0], chapters);
    cache.save(keys[1], chapters);
    cache.save(keys[2], chapters);
    expect(load(keys[0]), isNotNull, reason: 'used again');
    cache.save(keys[3], chapters);
    expect(cache.dir.listSync(), hasLength(3));
    expect(load(keys[1]), isNull, reason: 'the oldest one is gone');
    expect(load(keys[0]), isNotNull);
    expect(load(keys[2]), isNotNull);
    expect(load(keys[3]), isNotNull);
  });
}

PageStyle _sized(double size) => PageStyle(
  fontFamily: 'Literata',
  fontSize: size,
  color: const Color(0xFF000000),
);
