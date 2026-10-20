import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Soft hyphen: a place where a line may break, shown as «-» only there.
const softHyphen = '­';

/// Liang's hyphenation for one language from a TeX patterns file (the
/// `hyph-utf8` format: `\patterns{…}` and optional `\hyphenation{…}`).
final class Hyphenator {
  Hyphenator.fromTex(
    String tex, {
    required this.leftMin,
    required this.rightMin,
  }) {
    final source = tex.replaceAll(RegExp('%[^\n]*'), '');
    for (final pattern in _group(source, 'patterns')) {
      final letters = pattern.replaceAll(RegExp('[0-9]'), '');
      final values = List.filled(letters.length + 1, 0);
      var i = 0;
      for (final char in pattern.split('')) {
        final digit = int.tryParse(char);
        if (digit != null) {
          values[i] = digit;
        } else {
          i++;
        }
      }
      _patterns[letters] = values;
      _longest = math.max(_longest, letters.length);
    }
    for (final word in _group(source, 'hyphenation')) {
      final points = <int>[];
      var i = 0;
      for (final char in word.split('')) {
        if (char == '-') {
          points.add(i);
        } else {
          i++;
        }
      }
      _exceptions[word.replaceAll('-', '')] = points;
    }
  }

  /// Fewest letters before and after a break.
  final int leftMin;
  final int rightMin;

  final _patterns = <String, List<int>>{};
  final _exceptions = <String, List<int>>{};
  var _longest = 0;

  static Iterable<String> _group(String source, String name) {
    final start = source.indexOf('\\$name{');
    if (start < 0) return const [];
    final from = start + name.length + 2;
    final end = source.indexOf('}', from);
    return source
        .substring(from, end < 0 ? source.length : end)
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty);
  }

  /// Places inside the lower-case [word] where it may break: `i` means
  /// between `word[i - 1]` and `word[i]`.
  List<int> breaks(String word) {
    if (word.length < leftMin + rightMin) return const [];
    if (_exceptions[word] case final points?) {
      return [
        for (final i in points)
          if (i >= leftMin && i <= word.length - rightMin) i,
      ];
    }
    final dotted = '.$word.';
    final values = List.filled(dotted.length + 1, 0);
    for (var i = 0; i < dotted.length; i++) {
      final last = math.min(dotted.length, i + _longest);
      for (var j = i + 1; j <= last; j++) {
        final pattern = _patterns[dotted.substring(i, j)];
        if (pattern == null) continue;
        for (var k = 0; k < pattern.length; k++) {
          values[i + k] = math.max(values[i + k], pattern[k]);
        }
      }
    }
    // values[i + 1] is between word[i - 1] and word[i].
    return [
      for (var i = leftMin; i <= word.length - rightMin; i++)
        if (values[i + 1].isOdd) i,
    ];
  }
}

/// Where Russian and English words of a text may break (ROADMAP 8.8б).
/// Other words, words in capitals and words with marks inside are left
/// whole.
final class Hyphenation {
  Hyphenation({required this.russian, required this.english});

  /// Reads the bundled patterns (`assets/hyphenation/`, TeX `hyph-utf8`,
  /// unchanged). They are parsed in another isolate: tens of milliseconds
  /// that would hold up the app's start.
  static Future<Hyphenation> load([AssetBundle? bundle]) async {
    final assets = bundle ?? rootBundle;
    final (ru, en) = await (
      assets.loadString('assets/hyphenation/hyph-ru.tex'),
      assets.loadString('assets/hyphenation/hyph-en-us.tex'),
    ).wait;
    return Isolate.run(
      () => Hyphenation(
        russian: Hyphenator.fromTex(ru, leftMin: 2, rightMin: 2),
        english: Hyphenator.fromTex(en, leftMin: 2, rightMin: 3),
      ),
    );
  }

  /// Licenses of the patterns, for the license page: name → asset.
  static const licenses = {
    'Russian hyphenation patterns': 'assets/hyphenation/hyph-ru.tex',
    'English hyphenation patterns': 'assets/hyphenation/hyph-en-us.tex',
  };

  final Hyphenator russian;
  final Hyphenator english;

  static final _word = RegExp(r'[\p{L}\p{M}]+', unicode: true);
  static final _russian = RegExp(r'^[а-яё]+$');
  static final _english = RegExp(r'^[a-z]+$');

  /// Words repeat a lot: their breaks are kept, up to [_cacheSize] words.
  final _cache = <String, List<int>>{};
  static const _cacheSize = 20000;

  /// Offsets in [text] where a soft hyphen may go (before that character),
  /// ascending. The last word stays whole: a piece of it alone on the last
  /// line looks bad.
  List<int> breaksOf(String text) {
    final result = <int>[];
    final words = _word.allMatches(text).toList();
    if (words.isNotEmpty) words.removeLast();
    for (final match in words) {
      final word = match[0]!;
      if (word.length < 4) continue;
      for (final i in _breaksOfWord(word)) {
        result.add(match.start + i);
      }
    }
    return result;
  }

  List<int> _breaksOfWord(String word) {
    if (_cache[word] case final cached?) return cached;
    if (_cache.length >= _cacheSize) _cache.clear();
    return _cache[word] = _compute(word);
  }

  List<int> _compute(String word) {
    final lower = word.toLowerCase();
    // Capitals (abbreviations) and odd case changes stay whole.
    if (lower.length != word.length ||
        word.substring(1) != lower.substring(1)) {
      return const [];
    }
    if (_russian.hasMatch(lower)) return russian.breaks(lower);
    if (_english.hasMatch(lower)) return english.breaks(lower);
    return const [];
  }
}
