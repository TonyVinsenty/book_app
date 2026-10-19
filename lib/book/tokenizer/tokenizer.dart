/// Splits a book into words (ADR 0004). The result defines `wordIndex`
/// shared by reading, layout and speed reading: any change of the rules
/// must bump [tokenizerVersion] (saved positions move by their anchors).
library;

import 'dart:typed_data';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/chars.dart';
import 'package:book_app/book/tokenizer/token.dart';

const tokenizerVersion = 1;

BookTokens tokenize(BookContent content) {
  final out = _Builder();
  for (var s = 0; s < content.sections.length; s++) {
    var sectionStart = true;
    final blocks = content.sections[s].blocks;
    for (var b = 0; b < blocks.length; b++) {
      final block = blocks[b];
      if (block is! TextBlock) continue;
      final added = _tokenizeBlock(block.text, s, b, out, sectionStart);
      if (added > 0) sectionStart = false;
    }
  }
  return out.build(content);
}

/// Fixation letter (ORP) of [word] as a UTF-16 offset: counted over letters
/// only (no punctuation, hyphens or marks); 1 letter → 1st, 2–5 → 2nd,
/// 6–9 → 3rd, 10–13 → 4th, 14+ → 5th.
int orpIndex(String word) => _orp(word, 0, word.length);

int _orp(String text, int s, int e) {
  var count = 0;
  var first = -1;
  for (var i = s; i < e; i++) {
    if (isLetterAt(text, i)) {
      if (first < 0) first = i;
      count++;
    }
  }
  if (first < 0) return 0;
  final nth = count <= 1
      ? 0
      : count <= 5
      ? 1
      : count <= 9
      ? 2
      : count <= 13
      ? 3
      : 4;
  var seen = 0;
  for (var i = first; i < e; i++) {
    if (isLetterAt(text, i) && seen++ == nth) return i - s;
  }
  return first - s;
}

// ---------------------------------------------------------------------------

/// Tokens of one block, appended to [out]; returns how many were added.
int _tokenizeBlock(
  String text,
  int section,
  int block,
  _Builder out,
  bool sectionStart,
) {
  final starts = <int>[];
  final ends = <int>[];
  final dashes = <bool>[];
  int? pendingStart;
  var pendingEnd = 0;
  var pendingDash = false;
  var straightQuotes = 0;

  void pend(int s, int e, {bool dash = false}) {
    pendingStart ??= s;
    pendingEnd = e;
    pendingDash = pendingDash || dash;
  }

  void glueBack(int e, {bool dash = false}) {
    ends[ends.length - 1] = e;
    if (dash) dashes[dashes.length - 1] = true;
  }

  var i = 0;
  while (i < text.length) {
    if (isSeparator(text.codeUnitAt(i))) {
      i++;
      continue;
    }
    final s = i;
    while (i < text.length && !isSeparator(text.codeUnitAt(i))) {
      i++;
    }
    final e = i;
    var chunk = _classify(text, s, e);
    if (chunk == _Chunk.straightQuote) {
      // Free-standing `"`: odd ones open a quote, even ones close it.
      chunk = straightQuotes.isEven ? _Chunk.opening : _Chunk.punct;
      straightQuotes++;
    }
    switch (chunk) {
      case _Chunk.dash:
        // Dialog dash at a paragraph or sentence start, or after a colon,
        // goes to the next word, otherwise to the previous one.
        if (pendingStart != null ||
            starts.isEmpty ||
            _endsSentencePunct(text, starts.last, ends.last) ||
            _lastCharBeforeTail(text, starts.last, ends.last) == 0x3A) {
          pend(s, e, dash: true);
        } else {
          glueBack(e, dash: true);
        }
      case _Chunk.opening:
        pend(s, e);
      case _Chunk.punct:
      case _Chunk.straightQuote:
        if (pendingStart != null || starts.isEmpty) {
          pend(s, e);
        } else {
          glueBack(e);
        }
      case _Chunk.word:
        starts.add(pendingStart ?? s);
        ends.add(e);
        dashes.add(pendingDash);
        pendingStart = null;
        pendingDash = false;
    }
  }
  if (pendingStart case final ps?) {
    if (starts.isEmpty) {
      starts.add(ps);
      ends.add(pendingEnd);
      dashes.add(pendingDash);
    } else {
      glueBack(pendingEnd, dash: pendingDash);
    }
  }

  var previousIsNumber = false;
  for (var k = 0; k < starts.length; k++) {
    final start = starts[k];
    final end = ends[k];
    var flags = 0;
    if (k == 0) flags |= TokenFlags.paragraphStart;
    if (k == 0 && sectionStart) flags |= TokenFlags.sectionStart;
    final last = k == starts.length - 1;
    final terminal = _endsSentencePunct(text, start, end);
    if (last ||
        (terminal &&
            !_isAbbreviation(text, start, end, afterNumber: previousIsNumber) &&
            !_startsLowerOrDigit(text, starts[k + 1], ends[k + 1]))) {
      flags |= TokenFlags.sentenceEnd;
    } else if (terminal
        ? _lastCharBeforeTail(text, start, end) != 0x2E
        : _clauses.contains(_lastCharBeforeTail(text, start, end))) {
      flags |= TokenFlags.clauseEnd;
    }
    if (dashes[k] ||
        isDash(text.codeUnitAt(start)) ||
        isDash(text.codeUnitAt(end - 1))) {
      flags |= TokenFlags.dash;
    }
    previousIsNumber = _isNumber(text, start, end);
    if (previousIsNumber) flags |= TokenFlags.isNumber;
    final orp = _orp(text, start, end);
    out.add(section, block, start, end, orp > 0xFFFF ? 0xFFFF : orp, flags);
  }
  return starts.length;
}

enum _Chunk { dash, opening, straightQuote, punct, word }

_Chunk _classify(String text, int s, int e) {
  var allDash = true;
  var allOpening = true;
  var allStraight = true;
  for (var i = s; i < e; i++) {
    if (isWordCharAt(text, i)) return _Chunk.word;
    final c = text.codeUnitAt(i);
    if (!isDash(c) && c != 0x2D) allDash = false; // `-` typed as a dash
    if (!_openers.contains(c)) allOpening = false;
    if (c != 0x22) allStraight = false;
  }
  if (allDash) return _Chunk.dash;
  if (allOpening) return _Chunk.opening;
  if (allStraight) return _Chunk.straightQuote;
  return _Chunk.punct;
}

/// Index after the last char of `text[s, e)` that is not a closing quote,
/// bracket, dash or space.
int _trimTail(String text, int s, int e) {
  var j = e;
  while (j > s) {
    final c = text.codeUnitAt(j - 1);
    if (_closers.contains(c) ||
        isDash(c) ||
        c == 0x2D ||
        isSeparator(c) ||
        c == 0xA0 ||
        c == 0x2007 ||
        c == 0x202F) {
      j--;
    } else {
      break;
    }
  }
  return j;
}

/// Last char before closing quotes, brackets and glued dashes; -1 if none.
int _lastCharBeforeTail(String text, int s, int e) {
  final j = _trimTail(text, s, e);
  return j > s ? text.codeUnitAt(j - 1) : -1;
}

bool _endsSentencePunct(String text, int s, int e) =>
    _terminals.contains(_lastCharBeforeTail(text, s, e));

/// Abbreviations that are never followed by a sentence end (`ул. Ленина`,
/// `Mr. Smith`). Others (`т. д.`, `др.`) end a sentence only before a
/// capital letter, see [_startsLowerOrDigit].
const _abbreviations = {
  'ул.', 'им.', 'пр.', 'проф.', 'акад.', 'св.', 'тов.', 'гр.', //
  'mr.', 'mrs.', 'ms.', 'dr.', 'st.', 'prof.', 'vs.', 'e.g.', 'i.e.',
};

/// `г.` is «город» (`г. Москва`) unless it follows a number (`1799 г.`).
const _yearAbbreviations = {'г.', 'гг.'};

/// Initials (`А. С.`); `Я.` is excluded — it is the common one-letter word.
final _initials = RegExp(r'^(?:[A-ZА-ЯЁ]\.)+$');

bool _isAbbreviation(String text, int s, int e, {required bool afterNumber}) {
  var a = s;
  while (a < e && !isWordCharAt(text, a)) {
    a++;
  }
  final core = text.substring(a, _trimTail(text, a, e));
  if (core == 'Я.') return false;
  final lower = core.toLowerCase();
  if (_yearAbbreviations.contains(lower)) return !afterNumber;
  return _initials.hasMatch(core) || _abbreviations.contains(lower);
}

bool _startsLowerOrDigit(String text, int s, int e) {
  for (var i = s; i < e; i++) {
    if (!isWordCharAt(text, i)) continue;
    final c = text.codeUnitAt(i);
    if (c >= 0x30 && c <= 0x39) return true;
    final ch = String.fromCharCode(c);
    return ch.toLowerCase() == ch && ch.toUpperCase() != ch;
  }
  return false;
}

final _numberCore = RegExp(r'^\d+(?:[.,:/\-–   ]\d+)*$');
final _roman = RegExp(
  r'^M{0,3}(?:CM|CD|D?C{0,3})(?:XC|XL|L?X{0,3})(?:IX|IV|V?I{0,3})$',
);

bool _isNumber(String text, int s, int e) {
  var a = s;
  var b = e;
  while (a < b && !isWordCharAt(text, a)) {
    a++;
  }
  if (a == b) return false;
  final c = text.codeUnitAt(a);
  final digit = c >= 0x30 && c <= 0x39;
  if (!digit && !_romanLetters.contains(c)) return false;
  while (b > a && !isWordCharAt(text, b - 1)) {
    b--;
  }
  final core = text.substring(a, b);
  return digit
      ? _numberCore.hasMatch(core)
      : core.length >= 2 && _roman.hasMatch(core);
}

// --- characters ------------------------------------------------------------

const _terminals = {0x2E, 0x21, 0x3F, 0x2026}; // . ! ? …
const _clauses = {0x2C, 0x3B, 0x3A}; // , ; :
const _romanLetters = {0x49, 0x56, 0x58, 0x4C, 0x43, 0x44, 0x4D}; // IVXLCDM
const _openers = {
  0xAB, 0x201E, 0x201C, 0x2018, 0x28, 0x5B, 0x7B, 0xBF, 0xA1, 0x2039, //
}; // « „ “ ‘ ( [ { ¿ ¡ ‹
const _closers = {
  0xBB, 0x201D, 0x2019, 0x22, 0x27, 0x29, 0x5D, 0x7D, 0x203A, //
}; // » ” ’ " ' ) ] } ›

// --- builder ---------------------------------------------------------------

final class _Builder {
  final _sections = _IntBuffer();
  final _blocks = _IntBuffer();
  final _starts = _IntBuffer();
  final _ends = _IntBuffer();
  final _orps = _IntBuffer();
  final _flags = _IntBuffer();

  void add(int section, int block, int start, int end, int orp, int flags) {
    _sections.add(section);
    _blocks.add(block);
    _starts.add(start);
    _ends.add(end);
    _orps.add(orp);
    _flags.add(flags);
  }

  BookTokens build(BookContent content) => BookTokens.internal(
    content: content,
    sections: _sections.toInt32(),
    blocks: _blocks.toInt32(),
    starts: _starts.toInt32(),
    ends: _ends.toInt32(),
    orps: Uint16List.fromList(_orps.view()),
    flags: Uint8List.fromList(_flags.view()),
  );
}

final class _IntBuffer {
  var _data = Int32List(1024);
  var _length = 0;

  void add(int v) {
    if (_length == _data.length) {
      _data = Int32List(_data.length * 2)..setAll(0, _data);
    }
    _data[_length++] = v;
  }

  Int32List view() => Int32List.sublistView(_data, 0, _length);
  Int32List toInt32() => Int32List.fromList(view());
}
