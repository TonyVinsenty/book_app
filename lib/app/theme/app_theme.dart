import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:flutter/material.dart';

/// Reading colors for widgets: `context.readingColors`.
@immutable
class ReadingTheme extends ThemeExtension<ReadingTheme> {
  const ReadingTheme(this.colors);

  final ReadingColors colors;

  @override
  ReadingTheme copyWith({ReadingColors? colors}) =>
      ReadingTheme(colors ?? this.colors);

  @override
  ReadingTheme lerp(ReadingTheme? other, double t) =>
      other == null ? this : ReadingTheme(colors.lerp(other.colors, t));
}

extension ReadingThemeContext on BuildContext {
  ReadingColors get readingColors =>
      Theme.of(this).extension<ReadingTheme>()!.colors;
}

/// App theme for a palette: the whole interface takes the palette's colors.
ThemeData buildAppTheme(ReadingPalette palette, {required bool night}) {
  final c = palette.colors(night: night);
  final scheme = ColorScheme(
    brightness: night ? Brightness.dark : Brightness.light,
    primary: c.accent,
    onPrimary: c.background,
    secondary: c.accent,
    onSecondary: c.background,
    tertiary: c.orp,
    onTertiary: c.background,
    error: c.orp,
    onError: c.background,
    surface: c.background,
    onSurface: c.text,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerLowest: c.background,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surface,
    surfaceContainerHighest: c.surface,
    outline: c.textSecondary,
    outlineVariant: c.surface,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    // The top bar keeps the page color when content scrolls under it (the
    // iPhone's bouncing scroll made the tint flash on every pull).
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    fontFamily: AppFonts.ui,
    extensions: [ReadingTheme(c)],
  );
}
