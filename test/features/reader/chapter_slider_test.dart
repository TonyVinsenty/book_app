import 'package:book_app/features/reader/chapter_slider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chapter pages: in order, once each, none on the first page', () {
    final starts = [
      for (final v in [1, 1, 5, 12, 30]) (value: v, exact: true),
    ];
    final lines = [
      (title: 'Обложка', level: 0, sectionIndex: 0),
      (title: 'Глава 2', level: 0, sectionIndex: 3),
      (title: 'Глава 1', level: 0, sectionIndex: 2),
      (title: 'Часть главы 1', level: 1, sectionIndex: 2),
      (title: 'Пролог', level: 0, sectionIndex: 1),
      (title: 'Вне книги', level: 0, sectionIndex: 9),
    ];
    expect(chapterPages(lines, starts), [5, 12]);
  });

  test('snap: the nearest chapter start within reach, or none', () {
    const pages = [10, 20, 22];
    expect(snapToChapter(11.5, pages, 2), 10);
    expect(snapToChapter(21.4, pages, 2), 22);
    expect(snapToChapter(15, pages, 2), isNull);
    expect(snapToChapter(15, const [], 2), isNull);
  });
}
