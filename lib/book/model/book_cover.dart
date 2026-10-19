/// The cover picture of a book (ADR 0005, addition 1): stored as is in
/// `books/<id>/cover.<ext>`, never in the model.
library;

import 'dart:typed_data';

/// A bigger picture is not taken as a cover.
const maxCoverBytes = 5 * 1024 * 1024;

final class BookCover {
  const BookCover(this.bytes, this.extension);

  final Uint8List bytes;

  /// `jpg`, `png`, `gif` or `webp`, by the bytes, not by the file name.
  final String extension;
}

/// A cover from picture [bytes]; null when they are too big or not a
/// JPEG, PNG, GIF or WebP.
BookCover? coverFromBytes(Uint8List bytes) {
  if (bytes.length > maxCoverBytes) return null;
  final extension = _pictureType(bytes);
  return extension == null ? null : BookCover(bytes, extension);
}

String? _pictureType(Uint8List b) {
  bool at(int offset, List<int> sign) {
    if (b.length < offset + sign.length) return false;
    for (var i = 0; i < sign.length; i++) {
      if (b[offset + i] != sign[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'png';
  }
  if (at(0, 'GIF8'.codeUnits)) return 'gif';
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'webp';
  return null;
}
