import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/layout/hyphenation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Look of the book text on a page (ADR 0003, addendum 2). Any change but
/// [color] means a new layout (see [sameLayoutAs]).
@immutable
final class PageStyle {
  const PageStyle({
    required this.fontFamily,
    this.fontSize = 18,
    this.lineHeight = 1.45,
    required this.color,
    this.textScaler = TextScaler.noScaling,
    this.align = TextAlign.left,
    this.hyphenation,
    this.noteColor,
  });

  final String fontFamily;
  final double fontSize;

  /// Line height as a multiple of the font size.
  final double lineHeight;
  final Color color;
  final TextScaler textScaler;

  /// Alignment of ordinary paragraphs: left or justify.
  final TextAlign align;

  /// Breaks words of paragraphs at line ends; null — whole words only.
  final Hyphenation? hyphenation;

  /// Footnote labels (ADR 0008 п. 8); [color] if null. Not a layout change.
  final Color? noteColor;

  Color get activeLabel => noteColor ?? color;

  /// A label whose note the book does not have.
  Color get inactiveLabel => color.withValues(alpha: 0.4);

  /// Height of one body line on the page.
  double get bodyLine => textScaler.scale(fontSize) * lineHeight;

  TextStyle get body => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    height: lineHeight,
    color: color,
  );

  /// Same line height for every body line, whatever the inline markup.
  StrutStyle get bodyStrut => StrutStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    height: lineHeight,
    forceStrutHeight: true,
  );

  /// Text style of a heading of [level] (1 — chapter title).
  TextStyle heading(int level) => body.copyWith(
    fontSize: fontSize * (level <= 1 ? 1.35 : 1.15),
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  TextStyle paragraph(ParagraphStyle style) => switch (style) {
    ParagraphStyle.normal ||
    ParagraphStyle.quote ||
    ParagraphStyle.poem => body,
    ParagraphStyle.epigraph => body.copyWith(
      fontSize: fontSize * 0.9,
      fontStyle: FontStyle.italic,
    ),
    ParagraphStyle.subtitle => body.copyWith(fontWeight: FontWeight.w700),
    ParagraphStyle.note => body.copyWith(fontSize: fontSize * 0.85),
  };

  /// Same page breaks: everything but the color is equal.
  bool sameLayoutAs(PageStyle other) =>
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.textScaler == textScaler &&
      other.align == align &&
      identical(other.hyphenation, hyphenation);

  @override
  bool operator ==(Object other) =>
      other is PageStyle &&
      sameLayoutAs(other) &&
      other.color == color &&
      other.noteColor == noteColor;

  @override
  int get hashCode => Object.hash(
    fontFamily,
    fontSize,
    lineHeight,
    color,
    textScaler,
    align,
    hyphenation,
    noteColor,
  );
}
