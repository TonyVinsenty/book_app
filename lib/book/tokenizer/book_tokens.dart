import 'dart:typed_data';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:book_app/book/tokenizer/chars.dart';
import 'package:book_app/book/tokenizer/token.dart';

/// All words of a book in reading order, stored compactly (about 20 bytes
/// per word: a 500k-word book takes ~10 MB). Built by `tokenize`.
final class BookTokens {
  BookTokens.internal({
    required this.content,
    required Int32List sections,
    required this._blocks,
    required this._starts,
    required this._ends,
    required this._orps,
    required Uint8List flags,
  }) : _sections = sections,
       _flags = flags,
       _sectionFirstWord = _buildSectionFirstWord(
         sections,
         content.sections.length,
       ),
       _sentenceStarts = _buildSentenceStarts(flags),
       _chapterOf = _buildChapters(content);

  final BookContent content;
  final Int32List _sections;
  final Int32List _blocks;
  final Int32List _starts;
  final Int32List _ends;
  final Uint16List _orps;
  final Uint8List _flags;

  /// `[s]` = first word of section `s` or later; one extra entry = [length].
  final Int32List _sectionFirstWord;
  final Int32List _sentenceStarts;

  /// `[s]` = the whole chapter section `s` is part of (an index in the
  /// book as stored, before `splitLongSections`).
  final Int32List _chapterOf;

  int get length => _starts.length;
  bool get isEmpty => length == 0;

  Token operator [](int i) {
    RangeError.checkValidIndex(i, this);
    return Token(
      index: i,
      sectionIndex: _sections[i],
      blockIndex: _blocks[i],
      charStart: _starts[i],
      charEnd: _ends[i],
      text: textOf(i),
      orp: _orps[i],
      flags: _flags[i],
    );
  }

  String textOf(int i) => _blockText(i).substring(_starts[i], _ends[i]);

  String _blockText(int i) =>
      (content.sections[_sections[i]].blocks[_blocks[i]] as TextBlock).text;

  /// Offset of the first letter of word [i], after glued dashes and quotes:
  /// the anchor stays on the word even if the gluing rules change.
  int _wordStart(int i) {
    final text = _blockText(i);
    for (var j = _starts[i]; j < _ends[i]; j++) {
      if (isWordCharAt(text, j)) return j;
    }
    return _starts[i];
  }

  int flagsOf(int i) => _flags[i];

  int sectionOf(int i) => _sections[i];

  /// First word of [sectionIndex]; equals the first word of the next
  /// non-empty section (or [length]) when the section has no words.
  int firstWordOfSection(int sectionIndex) =>
      _sectionFirstWord[sectionIndex.clamp(0, _sectionFirstWord.length - 1)];

  /// Number of the chapter section [sectionIndex] belongs to, from 1: the
  /// parts of a long chapter share it.
  int chapterNumberOf(int sectionIndex) =>
      _chapterOf[sectionIndex.clamp(0, _chapterOf.length - 1)] + 1;

  /// First word of the whole chapter [sectionIndex] is part of.
  int firstWordOfChapter(int sectionIndex) {
    var s = sectionIndex.clamp(0, content.sections.length - 1);
    while (s > 0 && content.sections[s].continued) {
      s--;
    }
    return firstWordOfSection(s);
  }

  /// Start of the sentence that contains [wordIndex].
  int sentenceStartOf(int wordIndex) {
    var lo = 0;
    var hi = _sentenceStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_sentenceStarts[mid] <= wordIndex) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return _sentenceStarts.isEmpty ? 0 : _sentenceStarts[lo];
  }

  /// Word at [anchor]: the one containing it, else the next one; clamped to
  /// the last word. 0 for an empty book.
  int indexAt(TextAnchor anchor) {
    var lo = 0;
    var hi = length;
    // First word whose end is after the anchor (ordered by section, block,
    // offset).
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_endsBefore(mid, anchor)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo < length ? lo : (length == 0 ? 0 : length - 1);
  }

  bool _endsBefore(int i, TextAnchor a) {
    final section = _chapterOf[_sections[i]];
    if (section != a.sectionIndex) return section < a.sectionIndex;
    final block = _blockInChapter(i);
    if (block != a.blockIndex) return block < a.blockIndex;
    return _ends[i] <= a.charOffset;
  }

  /// Block of word [i] in its whole chapter.
  int _blockInChapter(int i) =>
      content.sections[_sections[i]].firstBlock + _blocks[i];

  ReadingPosition positionOf(int wordIndex) {
    if (isEmpty) return ReadingPosition.start;
    final i = wordIndex.clamp(0, length - 1);
    return ReadingPosition(
      wordIndex: i,
      // Against the whole chapter: anchors do not depend on its parts.
      anchor: TextAnchor(
        sectionIndex: _chapterOf[_sections[i]],
        blockIndex: _blockInChapter(i),
        charOffset: _wordStart(i),
      ),
    );
  }

  /// Word index for a saved [position]. Its [ReadingPosition.wordIndex] is
  /// trusted only while it still points at the anchored word; otherwise
  /// (new tokenizer or parser) the anchor decides.
  int resolve(ReadingPosition position) {
    if (isEmpty) return 0;
    final i = position.wordIndex;
    if (i >= 0 && i < length && positionOf(i).anchor == position.anchor) {
      return i;
    }
    return indexAt(position.anchor);
  }

  static Int32List _buildSectionFirstWord(Int32List sections, int count) {
    final result = Int32List(count + 1);
    var word = 0;
    for (var s = 0; s <= count; s++) {
      while (word < sections.length && sections[word] < s) {
        word++;
      }
      result[s] = word;
    }
    return result;
  }

  static Int32List _buildChapters(BookContent content) {
    final result = Int32List(content.sections.length);
    var chapter = -1;
    for (final (s, section) in content.sections.indexed) {
      if (!section.continued || chapter < 0) chapter++;
      result[s] = chapter;
    }
    return result;
  }

  static Int32List _buildSentenceStarts(Uint8List flags) {
    if (flags.isEmpty) return Int32List(0);
    var count = 1;
    for (var i = 0; i < flags.length - 1; i++) {
      if (flags[i] & TokenFlags.sentenceEnd != 0) count++;
    }
    final result = Int32List(count);
    var k = 1;
    for (var i = 0; i < flags.length - 1; i++) {
      if (flags[i] & TokenFlags.sentenceEnd != 0) result[k++] = i + 1;
    }
    return result;
  }
}
