import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Colors of one reading theme (day or night), from docs/design/concepts.html.
@immutable
class ReadingColors {
  const ReadingColors({
    required this.background,
    required this.text,
    required this.textSecondary,
    required this.surface,
    required this.accent,
    required this.orp,
    required this.highlight,
    required this.chartWord,
    required this.chartPhrase,
    required this.chartGuide,
  });

  /// Page background.
  final Color background;

  /// Book text.
  final Color text;

  /// Secondary text: chapter title, page numbers, hints.
  final Color textSecondary;

  /// Panels and cards drawn over the page.
  final Color surface;

  /// Buttons, slider, selected items.
  final Color accent;

  /// The highlighted letter in RSVP (optimal recognition point).
  final Color orp;

  /// Word highlight: leading highlight and the "last word" flash.
  final Color highlight;

  /// Statistics charts: speed reading by word, by phrase, the highlight
  /// (reading by eye is [accent]); ≥ 3:1 against [surface] (14.2, A15).
  final Color chartWord;
  final Color chartPhrase;
  final Color chartGuide;

  ReadingColors lerp(ReadingColors other, double t) => ReadingColors(
    background: Color.lerp(background, other.background, t)!,
    text: Color.lerp(text, other.text, t)!,
    textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    surface: Color.lerp(surface, other.surface, t)!,
    accent: Color.lerp(accent, other.accent, t)!,
    orp: Color.lerp(orp, other.orp, t)!,
    highlight: Color.lerp(highlight, other.highlight, t)!,
    chartWord: Color.lerp(chartWord, other.chartWord, t)!,
    chartPhrase: Color.lerp(chartPhrase, other.chartPhrase, t)!,
    chartGuide: Color.lerp(chartGuide, other.chartGuide, t)!,
  );
}

/// The four pastel palettes; each has a day and a night variant.
enum ReadingPalette {
  paper(
    day: ReadingColors(
      background: Color(0xFFF6F0E4),
      text: Color(0xFF3A332B),
      textSecondary: Color(0xFF665C4E),
      surface: Color(0xFFEBE2D0),
      accent: Color(0xFF8F6038),
      orp: Color(0xFFC2492F),
      highlight: Color(0xFFF3DFA2),
      chartWord: Color(0xFF3F7F5A),
      chartPhrase: Color(0xFF7B63B8),
      chartGuide: Color(0xFF4A6FA8),
    ),
    night: ReadingColors(
      background: Color(0xFF1F1B17),
      text: Color(0xFFE6DCCB),
      textSecondary: Color(0xFFA09484),
      surface: Color(0xFF2D2822),
      accent: Color(0xFFD0A070),
      orp: Color(0xFFFF8A6B),
      highlight: Color(0xFF5A4A25),
      chartWord: Color(0xFF5FA67B),
      chartPhrase: Color(0xFFA394DA),
      chartGuide: Color(0xFF7CA2DA),
    ),
  ),
  sage(
    day: ReadingColors(
      background: Color(0xFFEAF0E6),
      text: Color(0xFF2F3A31),
      textSecondary: Color(0xFF556458),
      surface: Color(0xFFDAE5D4),
      accent: Color(0xFF3F6B49),
      orp: Color(0xFFBF4A38),
      highlight: Color(0xFFCDE5B0),
      chartWord: Color(0xFF2A7C8C),
      chartPhrase: Color(0xFF7B63B8),
      chartGuide: Color(0xFF4A6FA8),
    ),
    night: ReadingColors(
      background: Color(0xFF182019),
      text: Color(0xFFDDE7DA),
      textSecondary: Color(0xFF8FA091),
      surface: Color(0xFF243026),
      accent: Color(0xFF8FB597),
      orp: Color(0xFFFF8F77),
      highlight: Color(0xFF3A5236),
      chartWord: Color(0xFF4FB0C0),
      chartPhrase: Color(0xFFA394DA),
      chartGuide: Color(0xFF7CA2DA),
    ),
  ),
  lavender(
    day: ReadingColors(
      background: Color(0xFFF0ECF6),
      text: Color(0xFF342F42),
      textSecondary: Color(0xFF5F5878),
      surface: Color(0xFFE2DAEE),
      accent: Color(0xFF66559A),
      orp: Color(0xFFBC4A3C),
      highlight: Color(0xFFDFD2F4),
      chartWord: Color(0xFF3F7F5A),
      chartPhrase: Color(0xFFB0517F),
      chartGuide: Color(0xFF4A6FA8),
    ),
    night: ReadingColors(
      background: Color(0xFF1C1925),
      text: Color(0xFFE4DFF0),
      textSecondary: Color(0xFF9D95B3),
      surface: Color(0xFF2A253C),
      accent: Color(0xFFA99BD3),
      orp: Color(0xFFFF8F7A),
      highlight: Color(0xFF4A3F6B),
      chartWord: Color(0xFF5FA67B),
      chartPhrase: Color(0xFFD68AB0),
      chartGuide: Color(0xFF7CA2DA),
    ),
  ),
  mist(
    day: ReadingColors(
      background: Color(0xFFE9EFF4),
      text: Color(0xFF2B3541),
      textSecondary: Color(0xFF515E6D),
      surface: Color(0xFFD8E3EC),
      accent: Color(0xFF3F6A8E),
      orp: Color(0xFFC4472F),
      highlight: Color(0xFFFBD9C4),
      chartWord: Color(0xFF3F7F5A),
      chartPhrase: Color(0xFF7B63B8),
      chartGuide: Color(0xFF8F6A1C),
    ),
    night: ReadingColors(
      background: Color(0xFF151C24),
      text: Color(0xFFDCE5EE),
      textSecondary: Color(0xFF8D9BAA),
      surface: Color(0xFF222D39),
      accent: Color(0xFF86AACB),
      orp: Color(0xFFFF9272),
      highlight: Color(0xFF5A4234),
      chartWord: Color(0xFF5FA67B),
      chartPhrase: Color(0xFFA394DA),
      chartGuide: Color(0xFFC9A24B),
    ),
  );

  const ReadingPalette({required this.day, required this.night});

  final ReadingColors day;
  final ReadingColors night;

  ReadingColors colors({required bool night}) => night ? this.night : day;
}
