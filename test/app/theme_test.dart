import 'dart:io';
import 'dart:math';

import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  test('four palettes, each with day and night', () {
    expect(ReadingPalette.values, hasLength(4));
  });

  for (final palette in ReadingPalette.values) {
    for (final night in [false, true]) {
      final name = '${palette.name} ${night ? 'night' : 'day'}';
      final c = palette.colors(night: night);

      test('$name: book text is easy to read', () {
        // WCAG AAA for body text, AA for secondary text.
        expect(contrast(c.text, c.background), greaterThanOrEqualTo(7));
        expect(
          contrast(c.textSecondary, c.background),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('$name: night is dark and day is light', () {
        final lum = c.background.computeLuminance();
        expect(night ? lum < 0.05 : lum > 0.7, isTrue);
      });

      test('$name: theme exposes reading colors', () {
        final theme = buildAppTheme(palette, night: night);
        expect(theme.extension<ReadingTheme>()!.colors, same(c));
        expect(theme.scaffoldBackgroundColor, c.background);
        expect(theme.colorScheme.onSurface, c.text);
      });
    }
  }

  test('every font family is declared in pubspec.yaml with its files', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final families = [...BookFont.values.map((f) => f.family), AppFonts.ui];
    for (final family in families) {
      expect(pubspec, contains('- family: $family\n'), reason: family);
    }
    final assets = RegExp(r'asset: (assets/fonts/\S+\.ttf)')
        .allMatches(pubspec)
        .map((m) => m.group(1)!);
    expect(assets, hasLength(BookFont.values.length * 4 + 3));
    for (final path in assets) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
