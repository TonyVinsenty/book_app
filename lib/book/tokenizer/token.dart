/// Bit flags of a [Token].
abstract final class TokenFlags {
  /// Ends with `. ! ? …` and is not an abbreviation or initial; the last
  /// word of every text block too.
  static const sentenceEnd = 1;

  /// Ends with `, ; :` (or `? ! …` inside a sentence).
  static const clauseEnd = 2;

  /// Has a free-standing dash glued to it (`— Привет`, `слово —`).
  static const dash = 4;
  static const paragraphStart = 8;
  static const sectionStart = 16;
  static const isNumber = 32;
}

/// One word with its glued punctuation (ADR 0004). Created on demand from
/// [BookTokens]; its place in the book is [index] (`wordIndex`).
final class Token {
  const Token({
    required this.index,
    required this.sectionIndex,
    required this.blockIndex,
    required this.charStart,
    required this.charEnd,
    required this.text,
    required this.orp,
    required this.flags,
  });

  final int index;
  final int sectionIndex;

  /// Index of the text block inside its section.
  final int blockIndex;

  /// `text == block.text.substring(charStart, charEnd)` without the note
  /// labels inside.
  final int charStart;
  final int charEnd;
  final String text;

  /// UTF-16 offset of the fixation letter inside [text].
  final int orp;
  final int flags;

  bool get sentenceEnd => flags & TokenFlags.sentenceEnd != 0;
  bool get clauseEnd => flags & TokenFlags.clauseEnd != 0;
  bool get dash => flags & TokenFlags.dash != 0;
  bool get paragraphStart => flags & TokenFlags.paragraphStart != 0;
  bool get sectionStart => flags & TokenFlags.sectionStart != 0;
  bool get isNumber => flags & TokenFlags.isNumber != 0;

  @override
  String toString() => 'Token($index, "$text")';
}
