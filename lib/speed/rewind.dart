import 'package:book_app/book/tokenizer/book_tokens.dart';

/// Where "back" goes from [word] (ADR 0004 п. 9): the start of its sentence,
/// or of the previous one while still in the first two words, so repeated
/// taps keep going back.
int sentenceBack(BookTokens tokens, int word) {
  final start = tokens.sentenceStartOf(word);
  if (word - start >= 2 || start == 0) return start;
  return tokens.sentenceStartOf(start - 1);
}
