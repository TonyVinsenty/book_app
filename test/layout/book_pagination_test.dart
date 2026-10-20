import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/layout/book_pagination.dart';
import 'package:book_app/layout/chapter_layout.dart';
import 'package:book_app/layout/page_cache.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sample_book.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const style = PageStyle(fontFamily: 'Literata', color: Color(0xFF000000));
  const size = Size(320, 520);
  late BookTokens tokens;
  late List<void Function()> queue;

  setUp(() {
    tokens = tokenize(sampleBook(sections: 5, paragraphs: 30));
    queue = [];
  });

  BookPagination start({Duration budget = Duration.zero}) => BookPagination(
    tokens: tokens,
    style: style,
    pageSize: size,
    schedule: queue.add,
    budget: budget,
  );

  /// Runs scheduled portions until none is left; returns how many ran.
  int runAll() {
    var portions = 0;
    while (queue.isNotEmpty) {
      queue.removeAt(0)();
      portions++;
    }
    return portions;
  }

  List<int> firstWordsOf(int section) {
    final layout = ChapterLayout.build(
      tokens: tokens,
      sectionIndex: section,
      style: style,
      pageSize: size,
    );
    final words = [for (final page in layout.pages) page.firstWord];
    layout.dispose();
    return words;
  }

  test('the whole book is split in small portions, as the reader would', () {
    final pagination = start();
    var notified = 0;
    pagination.addListener(() => notified++);
    expect(pagination.pageCount.exact, isFalse);
    expect(pagination.pageCount.value, greaterThan(0), reason: 'an estimate');

    final portions = runAll();
    expect(pagination.isComplete, isTrue);
    expect(portions, greaterThan(tokens.content.sections.length));
    var pages = 0;
    for (var s = 0; s < tokens.content.sections.length; s++) {
      expect(pagination.chapterPages(s), firstWordsOf(s), reason: 'chapter $s');
      expect(pagination.pagesBefore(s), (value: pages, exact: true));
      pages += pagination.chapterPages(s)!.length;
    }
    expect(pagination.pageCount, (value: pages, exact: true));
    expect(notified, greaterThan(0), reason: 'told when done');
  });

  test('chapters not split yet are estimated by their length', () {
    final pagination = start()..addChapter(0, firstWordsOf(0));
    // The book is five chapters of about the same length.
    final first = pagination.chapterPages(0)!.length;
    expect(pagination.pagesBefore(1), (value: first, exact: true));
    expect(pagination.pagesBefore(3).exact, isFalse);
    expect(pagination.pageCount.value, closeTo(first * 5, first * 2));
  });

  test('a book page is found in its chapter, estimated or not', () {
    final pagination = start()..addChapter(0, firstWordsOf(0));
    final first = pagination.chapterPages(0)!.length;
    expect(pagination.locate(0), (section: 0, page: 0, of: first, exact: true));
    expect(pagination.locate(first - 1), (
      section: 0,
      page: first - 1,
      of: first,
      exact: true,
    ));
    final next = pagination.locate(first);
    expect((next.section, next.page, next.exact), (1, 0, false));
    // Past the end: the last page.
    final total = pagination.pageCount.value;
    final last = pagination.locate(total + 10);
    expect(last.section, 4);
    expect(last.page, last.of - 1);
    expect(pagination.pagesBefore(4).value + last.page + 1, total);

    runAll();
    final later = pagination.locate(first);
    expect(later, (
      section: 1,
      page: 0,
      of: pagination.chapterPages(1)!.length,
      exact: true,
    ));
  });

  test('a chapter the reader laid out is not split again', () {
    final pagination = start();
    queue.removeAt(0)(); // a portion into chapter 0
    final words = firstWordsOf(0);
    pagination.addChapter(0, words);
    runAll();
    expect(pagination.chapterPages(0), same(words));
    expect(pagination.isComplete, isTrue);
  });

  test('a larger budget takes fewer portions', () {
    start(budget: const Duration(seconds: 10));
    expect(runAll(), 1);
  });

  test('after dispose a scheduled portion does nothing', () {
    final pagination = start();
    queue.removeAt(0)();
    final left = queue.length;
    pagination.dispose();
    queue.removeAt(0)();
    expect(left, 1);
    expect(queue, isEmpty, reason: 'nothing more is scheduled');
    expect(pagination.isComplete, isFalse);
  });

  group('saved pages', () {
    late List<ChapterPages> saved;

    BookPagination resume(ChapterPages? cached) => BookPagination(
      tokens: tokens,
      style: style,
      pageSize: size,
      schedule: queue.add,
      cached: cached,
      save: saved.add,
    );

    setUp(() => saved = []);

    test('a whole saved book is taken at once, without splitting', () {
      final cached = [for (var s = 0; s < 5; s++) firstWordsOf(s)];
      final pagination = resume(cached);
      expect(pagination.isComplete, isTrue);
      expect(queue, isEmpty);
      expect(pagination.pageCount.value, cached.expand((c) => c).length);
      pagination.dispose();
      expect(saved, isEmpty, reason: 'nothing new');
    });

    test('a half-done split goes on and is saved when the book is done', () {
      final pagination = resume([firstWordsOf(0), firstWordsOf(1)]..length = 5);
      expect(pagination.pagesBefore(2).exact, isTrue);
      expect(pagination.isComplete, isFalse);
      runAll();
      expect(saved, [
        [for (var s = 0; s < 5; s++) firstWordsOf(s)],
      ]);
      pagination.dispose();
      expect(saved, hasLength(1));
    });

    test('a saved chapter that differs is put right by the reader', () {
      final right = [for (var s = 0; s < 5; s++) firstWordsOf(s)];
      final wrong = [...right]..[2] = [right[2].first];
      final pagination = resume(wrong);
      final count = pagination.pageCount.value;
      pagination.addChapter(2, right[2]);
      expect(pagination.chapterPages(2), right[2]);
      expect(pagination.pageCount.value, count + right[2].length - 1);
      pagination.flush();
      expect(saved, [right]);
    });

    test('a layout left at once is not saved', () {
      final pagination = resume(null)..addChapter(0, firstWordsOf(0));
      pagination.dispose();
      expect(saved, isEmpty);
    });

    test('a saved split of another book is not used', () {
      final pagination = resume([firstWordsOf(0)]);
      expect(pagination.chapterPages(0), isNull);
      pagination.dispose();
    });
  });
}
