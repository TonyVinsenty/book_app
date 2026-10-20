import 'dart:typed_data';

import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/chars.dart';
import 'package:book_app/book/tokenizer/token.dart';

/// Splits the words into phrases of 2–3 for the phrase mode (ADR 0004,
/// addendum for stage 10 п. 3). Greedy, one section at a time, when first
/// asked; a phrase never crosses a sentence, a clause, a dash, a paragraph
/// or a section, so a sentence always starts a phrase.
final class PhraseSteps {
  PhraseSteps(this.tokens, {this.maxChars = defaultMaxChars})
    : assert(maxChars > 0);

  /// About the width of the RSVP screen in letters (the screen passes its
  /// own, within 12–24).
  static const defaultMaxChars = 18;

  /// At most this many words in a phrase.
  static const maxWords = 3;

  final BookTokens tokens;

  /// Letters and spaces of a phrase; a longer word is a phrase of its own.
  final int maxChars;

  /// Section → first words of its phrases.
  final Map<int, Int32List> _sections = {};

  /// The first word of the phrase [word] is in.
  int startOf(int word) {
    final starts = _startsOf(tokens.sectionOf(word));
    return starts[_indexIn(starts, word)];
  }

  /// The word after the phrase [word] is in.
  int endOf(int word) {
    final section = tokens.sectionOf(word);
    final starts = _startsOf(section);
    final i = _indexIn(starts, word) + 1;
    return i < starts.length
        ? starts[i]
        : tokens.firstWordOfSection(section + 1);
  }

  /// Index of the last start not after [word].
  static int _indexIn(Int32List starts, int word) {
    var lo = 0;
    var hi = starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= word) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  Int32List _startsOf(int section) => _sections[section] ??= _split(section);

  Int32List _split(int section) {
    final first = tokens.firstWordOfSection(section);
    final end = tokens.firstWordOfSection(section + 1);
    final starts = <int>[];
    var start = first;
    while (start < end) {
      starts.add(start);
      var last = start;
      var chars = tokens.textOf(start).length;
      var boundary = false;
      while (last - start + 1 < maxWords) {
        if (_endsPhrase(last) || last + 1 >= end || _startsPhrase(last + 1)) {
          boundary = true;
          break;
        }
        final more = chars + 1 + tokens.textOf(last + 1).length;
        if (more > maxChars) break;
        last++;
        chars = more;
      }
      // A service word goes with the word after it, if both fit.
      if (!boundary && last + 1 < end && !_startsPhrase(last + 1)) {
        while (last > start &&
            _sticky(last) &&
            tokens.textOf(last).length + 1 + tokens.textOf(last + 1).length <=
                maxChars) {
          last--;
        }
      }
      start = last + 1;
    }
    return Int32List.fromList(starts);
  }

  bool _endsPhrase(int i) {
    final flags = tokens.flagsOf(i);
    if (flags & (TokenFlags.sentenceEnd | TokenFlags.clauseEnd) != 0) {
      return true;
    }
    return flags & TokenFlags.dash != 0 && !_leadingDash(i);
  }

  bool _startsPhrase(int i) {
    final flags = tokens.flagsOf(i);
    return flags & (TokenFlags.paragraphStart | TokenFlags.sectionStart) != 0 ||
        flags & TokenFlags.dash != 0 && _leadingDash(i);
  }

  bool _leadingDash(int i) {
    final c = tokens.textOf(i).codeUnitAt(0);
    return isDash(c) || c == 0x2D;
  }

  /// A short service word or a number: not the last word of a phrase.
  bool _sticky(int i) {
    final flags = tokens.flagsOf(i);
    if (flags &
            (TokenFlags.sentenceEnd | TokenFlags.clauseEnd | TokenFlags.dash) !=
        0) {
      return false;
    }
    return flags & TokenFlags.isNumber != 0 ||
        _serviceWords.contains(tokens.textOf(i).toLowerCase());
  }

  static const _serviceWords = {
    // Russian
    'в', 'во', 'на', 'и', 'не', 'с', 'со', 'к', 'ко', 'по', 'за', 'от',
    'из', 'у', 'о', 'об', 'а', 'но', 'для', 'до', 'при', 'без',
    // English
    'a', 'an', 'the', 'of', 'to', 'in', 'and', 'on', 'at', 'for', 'with',
    'is',
  };
}
