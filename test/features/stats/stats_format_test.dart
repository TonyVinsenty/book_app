import 'package:book_app/features/stats/stats_format.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ru'));

  for (final (seconds, expected) in [
    (0, '0 мин'),
    (-5, '0 мин'),
    (20, '< 1 мин'),
    (60, '1 мин'),
    (89, '1 мин'),
    (90, '2 мин'),
    (59 * 60 + 40, '1 ч'),
    (3 * 3600 + 40 * 60, '3 ч 40 мин'),
  ]) {
    test('$seconds s', () {
      expect(formatDuration(l10n, Duration(seconds: seconds)), expected);
    });
  }
}
