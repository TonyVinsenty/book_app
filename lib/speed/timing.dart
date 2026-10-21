import 'dart:math' as math;
import 'dart:typed_data';

import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/chars.dart';
import 'package:book_app/book/tokenizer/token.dart';

/// How long each word is shown in speed reading (ADR 0004 п. 4).
abstract interface class WordTiming {
  Duration durationOf(int wordIndex);
}

/// Every word for the same time: `60000 / wpm` ms.
final class ConstantPace implements WordTiming {
  const ConstantPace(this.wordsPerMinute) : assert(wordsPerMinute > 0);

  final int wordsPerMinute;

  @override
  Duration durationOf(int wordIndex) =>
      Duration(microseconds: Duration.microsecondsPerMinute ~/ wordsPerMinute);
}

/// Speed limits and step of the − / + buttons, words per minute.
abstract final class SpeedLimits {
  static const min = 100;
  static const max = 1000;
  static const step = 25;
  static const initial = 300;

  static int clamp(int wpm) => wpm.clamp(min, max);
}

/// Smart pace multipliers (ADR 0004 п. 4); starting values, tuned by the
/// owner on the phone (stage 6.7).
abstract final class PaceRules {
  static const sentenceEnd = 2.2;
  static const clauseEnd = 1.5;
  static const dash = 1.3;
  static const paragraphStart = 1.6;
  static const number = 1.3;

  /// First word of a page in the guide: the eye goes back to the top
  /// (ADR 0004, addendum for stage 10 п. 7).
  static const pageStart = 1.8;

  /// Longer words: +[longPerLetter] per letter over [longFrom], up to [longMax].
  static const longFrom = 8;
  static const longPerLetter = 0.05;
  static const longMax = 1.8;

  /// Words of at most [shortUpTo] letters.
  static const shortUpTo = 3;
  static const short = 0.9;

  /// Multiplier of a word with these [flags] and [letters]. One pause for
  /// punctuation (the strongest), times the paragraph, number and length
  /// factors.
  static double of(int flags, int letters) {
    var m = flags & TokenFlags.sentenceEnd != 0
        ? sentenceEnd
        : flags & TokenFlags.clauseEnd != 0
        ? clauseEnd
        : flags & TokenFlags.dash != 0
        ? dash
        : 1.0;
    if (flags & TokenFlags.paragraphStart != 0) m *= paragraphStart;
    if (flags & TokenFlags.isNumber != 0) m *= number;
    if (letters > longFrom) {
      m *= math.min(1 + longPerLetter * (letters - longFrom), longMax);
    } else if (letters <= shortUpTo) {
      m *= short;
    }
    return m;
  }
}

/// Words get [PaceRules] multipliers, scaled so that a chapter still takes
/// `words / wpm` minutes: the shown speed is the average one (ADR 0004
/// «Изменения»). Multipliers are computed once per chapter, when first asked.
final class SmartPace implements WordTiming {
  SmartPace(this.tokens, this.wordsPerMinute)
    : assert(wordsPerMinute > 0),
      _chapters = {};

  /// Same tokens, another speed; keeps the computed chapters.
  SmartPace withSpeed(int wpm) => SmartPace._(tokens, wpm, _chapters);

  SmartPace._(this.tokens, this.wordsPerMinute, this._chapters);

  final BookTokens tokens;
  final int wordsPerMinute;
  final Map<int, _Chapter> _chapters;

  @override
  Duration durationOf(int wordIndex) {
    final chapter = _chapterOf(wordIndex);
    final scale = chapter.multipliers[wordIndex - chapter.first] / chapter.mean;
    return Duration(
      microseconds: (Duration.microsecondsPerMinute * scale / wordsPerMinute)
          .round(),
    );
  }

  _Chapter _chapterOf(int wordIndex) {
    final section = tokens.sectionOf(wordIndex);
    return _chapters[section] ??= _Chapter.build(tokens, section);
  }
}

final class _Chapter {
  _Chapter(this.first, this.multipliers, this.mean);

  factory _Chapter.build(BookTokens tokens, int section) {
    final first = tokens.firstWordOfSection(section);
    final end = tokens.firstWordOfSection(section + 1);
    final multipliers = Float64List(end - first);
    var sum = 0.0;
    for (var i = first; i < end; i++) {
      final text = tokens.textOf(i);
      var letters = 0;
      for (var c = 0; c < text.length; c++) {
        if (isLetterAt(text, c)) letters++;
      }
      sum += multipliers[i - first] = PaceRules.of(tokens.flagsOf(i), letters);
    }
    return _Chapter(first, multipliers, sum / multipliers.length);
  }

  final int first;
  final Float64List multipliers;
  final double mean;
}
