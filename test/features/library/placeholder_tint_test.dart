import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final background = ReadingPalette.paper.day.background;

  test('a book without a cover keeps its color; books differ', () {
    expect(
      placeholderTint('Белые ночи', background),
      placeholderTint('Белые ночи', background),
    );
    final tints = {
      for (final title in [
        'Белые ночи',
        'Дьявол',
        'Палата № 6',
        'Шинель',
        'Нос',
        'Вий',
        'Ревизор',
      ])
        placeholderTint(title, background),
    };
    expect(tints.length, greaterThan(2));
  });
}
