/// Book format by the file content, not by its name (ADR 0005).
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:book_app/book/import/zip_box.dart';

enum DetectedFormat {
  txt,
  fb2,
  epub,

  /// Any other ZIP: a box of books (`zip_box.dart`), or a damaged archive.
  zip,
}

/// How far into the file the root tag is looked for (prolog, comments).
const _headLength = 4096;

/// `<FictionBook`, also with a namespace prefix (`<fb:FictionBook`).
final _fictionBookTag = RegExp(r'<([\w.-]+:)?FictionBook\b');

DetectedFormat detectFormat(Uint8List bytes) {
  if (startsLikeZip(bytes)) return _zipFormat(bytes);
  if (_mentionsFictionBook(bytes)) return DetectedFormat.fb2;
  return DetectedFormat.txt;
}

/// By the central directory, so the order of entries does not matter.
DetectedFormat _zipFormat(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    return isEpubArchive(archive) ? DetectedFormat.epub : DetectedFormat.zip;
  } on Object {
    return DetectedFormat.zip;
  }
}

/// The root tag is ASCII in UTF-8 and single-byte encodings; UTF-16 files
/// get every second byte dropped first.
bool _mentionsFictionBook(Uint8List b) {
  final head = b.sublist(0, b.length.clamp(0, _headLength));
  final ascii = String.fromCharCodes(head.where((c) => c != 0));
  return _fictionBookTag.hasMatch(ascii);
}
