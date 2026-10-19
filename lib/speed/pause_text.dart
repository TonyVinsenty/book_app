import 'dart:math' as math;

import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/token.dart';

/// Text shown above the word on pause (ADR 0004 п. 7): up to [maxWords]
/// words before [word] in its chapter, each paragraph on its own line. Ends
/// with the space or line break before [word]; cut mid-paragraph, it starts
/// with "…".
String textBefore(BookTokens tokens, int word, {int maxWords = 60}) {
  final chapter = tokens.firstWordOfSection(tokens.sectionOf(word));
  final first = math.max(chapter, word - maxWords);
  final out = StringBuffer();
  if (first < word && tokens.flagsOf(first) & TokenFlags.paragraphStart == 0) {
    out.write('… ');
  }
  for (var i = first; i < word; i++) {
    out
      ..write(tokens.textOf(i))
      ..write(
        tokens.flagsOf(i + 1) & TokenFlags.paragraphStart != 0 ? '\n' : ' ',
      );
  }
  return out.toString();
}
