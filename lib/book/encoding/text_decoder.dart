/// Turns book bytes into text, guessing the encoding (ADR 0001): BOM →
/// UTF-16 without BOM → strict UTF-8 → declared encoding → Windows-1251 or
/// KOI8-R, whichever gives more frequent lowercase Russian letters.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:book_app/book/encoding/code_pages.dart';

enum TextEncoding { utf8, utf16le, utf16be, windows1251, koi8r }

final class DecodedText {
  const DecodedText(this.text, this.encoding);

  final String text;
  final TextEncoding encoding;
}

/// The bytes are not text (a binary file or a format we do not know).
final class NotTextException implements Exception {
  const NotTextException();

  @override
  String toString() => 'NotTextException';
}

/// Encoding from a name like `windows-1251` or `KOI8-R` (FB2 `encoding=`).
TextEncoding? encodingByName(String name) =>
    switch (name.trim().toLowerCase().replaceAll('_', '-')) {
      'utf-8' || 'utf8' => TextEncoding.utf8,
      'utf-16' || 'utf-16le' => TextEncoding.utf16le,
      'utf-16be' => TextEncoding.utf16be,
      'windows-1251' ||
      'cp1251' ||
      'cp-1251' ||
      'win-1251' => TextEncoding.windows1251,
      'koi8-r' || 'koi8r' || 'koi8' => TextEncoding.koi8r,
      _ => null,
    };

DecodedText decodeText(Uint8List bytes, {TextEncoding? declared}) {
  final decoded = _decode(bytes, declared);
  if (!_looksLikeText(decoded.text)) throw const NotTextException();
  return decoded;
}

DecodedText _decode(Uint8List bytes, TextEncoding? declared) {
  if (_startsWith(bytes, const [0xEF, 0xBB, 0xBF])) {
    return DecodedText(
      utf8.decode(Uint8List.sublistView(bytes, 3), allowMalformed: true),
      TextEncoding.utf8,
    );
  }
  if (_startsWith(bytes, const [0xFF, 0xFE])) {
    return DecodedText(_utf16(bytes, 2, little: true), TextEncoding.utf16le);
  }
  if (_startsWith(bytes, const [0xFE, 0xFF])) {
    return DecodedText(_utf16(bytes, 2, little: false), TextEncoding.utf16be);
  }
  // Before UTF-8: UTF-16 of Russian text is also valid (if odd) UTF-8.
  if (_utf16Guess(bytes) case final utf16?) {
    return DecodedText(_decodeAs(bytes, utf16), utf16);
  }
  // Valid UTF-8 beats a declaration: old FB2 files often lie about it.
  try {
    return DecodedText(utf8.decode(bytes), TextEncoding.utf8);
  } on FormatException {
    // not strict UTF-8
  }
  if (_mostlyUtf8(bytes) case final text?) {
    return DecodedText(text, TextEncoding.utf8);
  }
  if (declared != null && declared != TextEncoding.utf8) {
    return DecodedText(_decodeAs(bytes, declared), declared);
  }
  final sample = Uint8List.sublistView(
    bytes,
    0,
    bytes.length < _sampleSize ? bytes.length : _sampleSize,
  );
  final cp1251 = _russianScore(_singleByte(sample, windows1251High));
  final koi8 = _russianScore(_singleByte(sample, koi8rHigh));
  final encoding = koi8 > cp1251
      ? TextEncoding.koi8r
      : TextEncoding.windows1251;
  return DecodedText(_decodeAs(bytes, encoding), encoding);
}

const _sampleSize = 64 * 1024;

/// UTF-8 with a few broken bytes (a cut last char, one stray byte): the
/// text is still UTF-8. A single-byte Russian text read as UTF-8 is almost
/// all replacement signs instead.
String? _mostlyUtf8(Uint8List bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  var broken = 0;
  var good = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 0xFFFD) {
      broken++;
    } else if (c >= 0x80) {
      good++;
    }
  }
  return broken <= 3 + good ~/ 1000 && good >= 20 * broken ? text : null;
}

String _decodeAs(Uint8List bytes, TextEncoding encoding) => switch (encoding) {
  TextEncoding.utf8 => utf8.decode(bytes, allowMalformed: true),
  TextEncoding.utf16le => _utf16(bytes, 0, little: true),
  TextEncoding.utf16be => _utf16(bytes, 0, little: false),
  TextEncoding.windows1251 => _singleByte(bytes, windows1251High),
  TextEncoding.koi8r => _singleByte(bytes, koi8rHigh),
};

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

String _singleByte(Uint8List bytes, String high) {
  final units = Uint16List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    units[i] = b < 0x80 ? b : high.codeUnitAt(b - 0x80);
  }
  return String.fromCharCodes(units);
}

String _utf16(Uint8List bytes, int offset, {required bool little}) {
  final count = (bytes.length - offset) >> 1;
  final units = Uint16List(count);
  for (var i = 0; i < count; i++) {
    final a = bytes[offset + 2 * i];
    final b = bytes[offset + 2 * i + 1];
    units[i] = little ? a | (b << 8) : (a << 8) | b;
  }
  return String.fromCharCodes(units);
}

/// UTF-16 without BOM: every other byte is mostly zero (Latin text) or
/// 0x04 (Cyrillic).
TextEncoding? _utf16Guess(Uint8List bytes) {
  final n = (bytes.length < _sampleSize ? bytes.length : _sampleSize) & ~1;
  if (n < 4) return null;
  var oddHigh = 0;
  var evenHigh = 0;
  for (var i = 0; i < n; i += 2) {
    if (bytes[i + 1] == 0 || bytes[i + 1] == 0x04) oddHigh++;
    if (bytes[i] == 0 || bytes[i] == 0x04) evenHigh++;
  }
  final pairs = n >> 1;
  if (oddHigh > pairs * 0.6 && evenHigh < pairs * 0.1) {
    return TextEncoding.utf16le;
  }
  if (evenHigh > pairs * 0.6 && oddHigh < pairs * 0.1) {
    return TextEncoding.utf16be;
  }
  return null;
}

/// Frequent lowercase Russian letters. A wrong code page turns Russian text
/// mostly into capitals or box-drawing signs, so this count drops.
int _russianScore(String text) {
  var score = 0;
  for (var i = 0; i < text.length; i++) {
    if (_frequent.contains(text.codeUnitAt(i))) score++;
  }
  return score;
}

final _frequent = 'оеаинтсрвл'.codeUnits.toSet();

/// No more than 1% control chars or replacement signs.
bool _looksLikeText(String text) {
  if (text.isEmpty) return true;
  var bad = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if ((c < 0x20 && c != 0x09 && c != 0x0A && c != 0x0D && c != 0x0C) ||
        c == 0xFFFD) {
      bad++;
    }
  }
  return bad <= text.length / 100;
}
