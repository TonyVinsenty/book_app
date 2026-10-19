/// Book format by the file content, not by its name (ADR 0005).
library;

import 'dart:convert';
import 'dart:typed_data';

enum DetectedFormat {
  txt,
  fb2,
  fb2zip,
  epub,

  /// A ZIP archive that is neither EPUB nor a packed FB2.
  zip,
}

/// How far into the file the root tag is looked for (prolog, comments).
const _headLength = 4096;

/// `<FictionBook`, also with a namespace prefix (`<fb:FictionBook`).
final _fictionBookTag = RegExp(r'<([\w.-]+:)?FictionBook\b');

DetectedFormat detectFormat(Uint8List bytes) {
  if (_isZip(bytes)) {
    if (_isEpub(bytes)) return DetectedFormat.epub;
    if (_firstEntryName(bytes).toLowerCase().endsWith('.fb2')) {
      return DetectedFormat.fb2zip;
    }
    return DetectedFormat.zip;
  }
  if (_mentionsFictionBook(bytes)) return DetectedFormat.fb2;
  return DetectedFormat.txt;
}

bool _isZip(Uint8List b) =>
    b.length >= 30 && b[0] == 0x50 && b[1] == 0x4B && b[2] == 3 && b[3] == 4;

/// EPUB starts with an uncompressed `mimetype` entry.
bool _isEpub(Uint8List b) =>
    _firstEntryName(b) == 'mimetype' &&
    latin1
        .decode(b.sublist(30, b.length.clamp(0, 128)))
        .contains('application/epub+zip');

/// The file name of the first local ZIP header.
String _firstEntryName(Uint8List b) {
  final nameLength = b[26] | (b[27] << 8);
  final end = 30 + nameLength;
  if (end > b.length) return '';
  return latin1.decode(b.sublist(30, end));
}

/// The root tag is ASCII in UTF-8 and single-byte encodings; UTF-16 files
/// get every second byte dropped first.
bool _mentionsFictionBook(Uint8List b) {
  final head = b.sublist(0, b.length.clamp(0, _headLength));
  final ascii = String.fromCharCodes(head.where((c) => c != 0));
  return _fictionBookTag.hasMatch(ascii);
}
