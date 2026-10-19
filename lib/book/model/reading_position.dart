/// Place in the text that survives re-tokenization: the start of a word
/// inside a text block (ADR 0002).
final class TextAnchor {
  const TextAnchor({
    required this.sectionIndex,
    required this.blockIndex,
    required this.charOffset,
  });

  final int sectionIndex;

  /// Index of the block inside its section.
  final int blockIndex;

  /// UTF-16 offset inside the block text.
  final int charOffset;

  @override
  bool operator ==(Object other) =>
      other is TextAnchor &&
      other.sectionIndex == sectionIndex &&
      other.blockIndex == blockIndex &&
      other.charOffset == charOffset;

  @override
  int get hashCode => Object.hash(sectionIndex, blockIndex, charOffset);

  @override
  String toString() => 'TextAnchor($sectionIndex, $blockIndex, $charOffset)';
}

/// Reading position, exact to the word: shared by normal reading and speed
/// reading. [wordIndex] is the main value; [anchor] restores it when the
/// tokenizer or parser changed.
final class ReadingPosition {
  const ReadingPosition({required this.wordIndex, required this.anchor});

  static const start = ReadingPosition(
    wordIndex: 0,
    anchor: TextAnchor(sectionIndex: 0, blockIndex: 0, charOffset: 0),
  );

  final int wordIndex;
  final TextAnchor anchor;

  @override
  bool operator ==(Object other) =>
      other is ReadingPosition &&
      other.wordIndex == wordIndex &&
      other.anchor == anchor;

  @override
  int get hashCode => Object.hash(wordIndex, anchor);

  @override
  String toString() => 'ReadingPosition($wordIndex, $anchor)';
}
