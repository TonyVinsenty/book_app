import 'dart:ui';

import 'package:book_app/app/app_locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const supported = [Locale('en'), Locale('ru')];

  test('the first phone language the app has', () {
    expect(
      resolveAppLocale([const Locale('ru', 'RU')], supported).languageCode,
      'ru',
    );
    expect(
      resolveAppLocale([const Locale('en', 'GB')], supported).languageCode,
      'en',
    );
    expect(
      resolveAppLocale([
        const Locale('de'),
        const Locale('ru'),
        const Locale('en'),
      ], supported).languageCode,
      'ru',
    );
  });

  test('the phone region is kept for dates and times', () {
    expect(
      resolveAppLocale([const Locale('en', 'GB')], supported),
      const Locale('en', 'GB'),
    );
  });

  test('other languages and none get English', () {
    expect(
      resolveAppLocale([const Locale('de')], supported).languageCode,
      'en',
    );
    expect(resolveAppLocale(null, supported).languageCode, 'en');
    expect(resolveAppLocale([], supported.reversed).languageCode, 'en');
  });
}
