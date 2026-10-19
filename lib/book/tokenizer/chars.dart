/// Character classes shared by the tokenizer and word lookups.
library;

/// `—` em dash, `–` en dash, `‒` figure dash, `―` horizontal bar.
bool isDash(int c) => c == 0x2014 || c == 0x2013 || c == 0x2012 || c == 0x2015;

/// Word separators: whitespace except no-break spaces (U+00A0, U+2007,
/// U+202F), which keep `1 000 000` and `т. е.` together.
bool isSeparator(int c) =>
    c == 0x20 ||
    (c >= 0x09 && c <= 0x0D) ||
    c == 0x85 ||
    c == 0x1680 ||
    (c >= 0x2000 && c <= 0x200B && c != 0x2007) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0x205F ||
    c == 0x3000 ||
    c == 0xFEFF;

bool isLowSurrogate(int c) => c >= 0xDC00 && c <= 0xDFFF;

final _wordChar = RegExp(r'[\p{L}\p{N}\p{M}]', unicode: true);
final _mark = RegExp(r'\p{M}', unicode: true);

/// Letter, digit or combining mark (stress marks inside Russian words).
/// Fast paths cover ASCII, Latin, Cyrillic and common punctuation; the rest
/// goes to a Unicode regexp.
bool isWordCharAt(String s, int i) {
  final c = s.codeUnitAt(i);
  if (c < 0x80) {
    return (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5A) ||
        (c >= 0x61 && c <= 0x7A);
  }
  if (c >= 0x0400 && c <= 0x052F) return true; // Cyrillic
  if (c >= 0xC0 && c <= 0x24F) return c != 0xD7 && c != 0xF7; // Latin
  if (c >= 0x0300 && c <= 0x036F) return true; // combining marks
  if (c >= 0x2000 && c <= 0x206F) return false; // dashes, quotes, spaces, …
  if (c == 0xA0 || c == 0xAB || c == 0xBB) return false; // NBSP « »
  if (isLowSurrogate(c)) return i > 0 && isWordCharAt(s, i - 1);
  if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
    return _wordChar.hasMatch(s.substring(i, i + 2));
  }
  return _wordChar.hasMatch(String.fromCharCode(c));
}

bool isMarkAt(String s, int i) {
  final c = s.codeUnitAt(i);
  if (c < 0x300) return false;
  if (c <= 0x036F) return true;
  if (c >= 0x0400 && c <= 0x052F) return c >= 0x0483 && c <= 0x0489;
  if (c < 0x0483) return false;
  return _mark.hasMatch(String.fromCharCode(c));
}

/// A counted letter for the fixation point: a word char that is not a
/// combining mark or the second half of a surrogate pair.
bool isLetterAt(String s, int i) =>
    isWordCharAt(s, i) && !isLowSurrogate(s.codeUnitAt(i)) && !isMarkAt(s, i);
