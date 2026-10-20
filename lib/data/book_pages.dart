import 'dart:convert';
import 'dart:math' as math;

import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/layout/hyphenation.dart';
import 'package:book_app/layout/page_cache.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The look of the book text for [settings]: the reader and the book page
/// build the same page style, so they find the same saved pages (ADR 0005,
/// addendum 3). The system text scale only picks the default size (ADR
/// 0003, addendum 2 п. 2).
PageStyle pageStyleOf(
  ReadingSettings settings, {
  required TextScaler system,
  required Color color,
  Hyphenation? hyphenation,
}) => PageStyle(
  fontFamily: settings.font.family,
  fontSize: settings.fontSizeFor(system),
  lineHeight: settings.lineHeight,
  color: color,
  align: switch (settings.align) {
    BookAlign.left => TextAlign.left,
    BookAlign.justify => TextAlign.justify,
  },
  hyphenation: settings.hyphenate ? hyphenation : null,
);

/// The page the reader laid out last (setting `reader.lastLayout`): its
/// size, look ([styleKeyOf]) and words per page of the last book split to
/// the end with that look, if any.
@immutable
final class LastLayout {
  const LastLayout({
    required this.pageSize,
    required this.styleKey,
    this.wordsPerPage,
  });

  final Size pageSize;
  final String styleKey;
  final double? wordsPerPage;

  /// The same page and look, with the words per page of a book just split
  /// to the end ([wordsPerPage] non-null), or else kept from [before] when
  /// it had the same look.
  factory LastLayout.update(
    LastLayout? before, {
    required Size pageSize,
    required String styleKey,
    double? wordsPerPage,
  }) => LastLayout(
    pageSize: pageSize,
    styleKey: styleKey,
    wordsPerPage:
        wordsPerPage ??
        (before?.styleKey == styleKey ? before?.wordsPerPage : null),
  );

  String encode() => jsonEncode({
    'w': pageSize.width,
    'h': pageSize.height,
    'style': styleKey,
    'wpp': ?wordsPerPage,
  });

  /// Null for a missing or broken value.
  static LastLayout? decode(String? value) {
    if (value == null) return null;
    try {
      final json = jsonDecode(value);
      if (json
          case {'w': final num w, 'h': final num h, 'style': final String style}
          when w > 0 && h > 0) {
        final wpp = json['wpp'];
        return LastLayout(
          pageSize: Size(w.toDouble(), h.toDouble()),
          styleKey: style,
          wordsPerPage: wpp is num && wpp > 0 ? wpp.toDouble() : null,
        );
      }
    } on FormatException {
      // Broken: as if none.
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is LastLayout &&
      other.pageSize == pageSize &&
      other.styleKey == styleKey &&
      other.wordsPerPage == wordsPerPage;

  @override
  int get hashCode => Object.hash(pageSize, styleKey, wordsPerPage);
}

/// Pages of a book: all of them and the one with the reading place (from
/// 1); not [exact] — an estimate, shown with «≈».
typedef BookPages = ({int total, int current, bool exact});

/// Pages of a book of [words] words read up to [positionWord], for [style]
/// on a page of [pageSize] (ADR 0005, addendum 3). Every chapter in the
/// saved split ([cached]) — exact, the same numbers as «стр. N / M» in the
/// reader; otherwise an estimate from the words per page of [last] (if its
/// look is this one) or from the page and font size.
BookPages bookPagesOf({
  required int words,
  required int positionWord,
  required PageStyle style,
  required Size pageSize,
  ChapterPages? cached,
  LastLayout? last,
}) {
  if (words <= 0) return (total: 0, current: 0, exact: true);
  if (cached != null && cached.every((c) => c != null)) {
    final firstWords = [for (final chapter in cached) ...chapter!];
    if (firstWords.isNotEmpty) {
      return (
        total: firstWords.length,
        current: math.max(1, _pagesFrom(firstWords, positionWord)),
        exact: true,
      );
    }
  }
  final wordsPerPage =
      last != null &&
          last.styleKey == styleKeyOf(style: style, pageSize: pageSize)
      ? last.wordsPerPage
      : null;
  final total = math.max(
    1,
    (words / math.max(wordsPerPage ?? _roughWordsPerPage(style, pageSize), 1))
        .round(),
  );
  final read = positionWord.clamp(0, words) / words;
  return (
    total: total,
    current: math.min(total, (read * total).floor() + 1),
    exact: false,
  );
}

/// How many pages start at or before [word]: the reader's page with it is
/// the last of them (a page without words shares the next one's start).
int _pagesFrom(List<int> firstWords, int word) {
  var lo = 0;
  var hi = firstWords.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (firstWords[mid] <= word) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Words per page from the characters per page `BookPagination` guesses
/// before any chapter is split, at about 6 characters a word with its space.
double _roughWordsPerPage(PageStyle style, Size pageSize) {
  final em = style.textScaler.scale(style.fontSize);
  final perLine = pageSize.width / (em * 0.5);
  return perLine * (pageSize.height / style.bodyLine) / 6;
}
