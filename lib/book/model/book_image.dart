/// Pictures inside a book (ADR 0008): parsers hand each one to an
/// [ImageSink] (files `books/<id>/img/<n>.<ext>`), the model keeps only an
/// [ImageBlock] with its size, read from the file header without decoding.
library;

import 'dart:typed_data';

import 'package:book_app/book/model/book_content.dart';

/// A bigger picture is skipped.
const maxImageBytes = 20 * 1024 * 1024;

/// More pixels could crash the decoder on a phone.
const maxImagePixels = 50 * 1000 * 1000;

/// Pictures with both sides smaller are spacers.
const minImageSide = 16;

/// Per book.
const maxBookImages = 2000;
const maxBookImageBytes = 300 * 1024 * 1024;

/// Where the pictures of a book being parsed go.
abstract interface class ImageSink {
  void add(String assetId, Uint8List bytes);
}

/// Keeps the pictures in memory (tests).
final class MemoryImageSink implements ImageSink {
  final files = <String, Uint8List>{};

  @override
  void add(String assetId, Uint8List bytes) => files[assetId] = bytes;
}

/// Type and size of a picture, from its header.
final class PictureHeader {
  const PictureHeader(this.extension, this.width, this.height);

  /// `jpg`, `png`, `gif`, `webp` or `bmp`.
  final String extension;
  final int width;
  final int height;
}

/// The pictures of one book being parsed: numbers them in book order, skips
/// the ones over the limits and stores each picture once.
final class BookImages {
  BookImages([this._sink]);

  /// Null: blocks are made, files are not written.
  final ImageSink? _sink;
  final _byKey = <String, ImageBlock?>{};
  var _count = 0;
  var _bytes = 0;

  /// The block for the picture the book knows as [key] (a `binary` id, a
  /// file path); [load] gives its bytes the first time, null when there are
  /// none. Null when the picture is skipped.
  ImageBlock? add(String key, Uint8List? Function() load) =>
      _byKey.putIfAbsent(key, () {
        final bytes = load();
        if (bytes == null ||
            bytes.length > maxImageBytes ||
            _count >= maxBookImages ||
            _bytes + bytes.length > maxBookImageBytes) {
          return null;
        }
        final header = readPictureHeader(bytes);
        if (header == null ||
            !_isComplete(header.extension, bytes) ||
            header.width * header.height > maxImagePixels ||
            (header.width < minImageSide && header.height < minImageSide)) {
          return null;
        }
        final assetId = '${++_count}.${header.extension}';
        _bytes += bytes.length;
        _sink?.add(assetId, bytes);
        return ImageBlock(
          assetId: assetId,
          width: header.width,
          height: header.height,
        );
      });
}

/// Type and size of a JPEG, PNG, GIF, WebP or BMP picture; null for other
/// or broken data.
PictureHeader? readPictureHeader(Uint8List b) {
  bool at(int offset, List<int> sign) {
    if (b.length < offset + sign.length) return false;
    for (var i = 0; i < sign.length; i++) {
      if (b[offset + i] != sign[i]) return false;
    }
    return true;
  }

  final data = ByteData.sublistView(b);
  int u16(int o, [Endian e = Endian.little]) =>
      o + 2 <= b.length ? data.getUint16(o, e) : -1;
  int u24(int o) => o + 3 <= b.length ? u16(o) | b[o + 2] << 16 : -1;
  int i32(int o, [Endian e = Endian.little]) =>
      o + 4 <= b.length ? data.getInt32(o, e) : -1;

  PictureHeader? sized(String extension, int width, int height) =>
      width > 0 && height > 0 ? PictureHeader(extension, width, height) : null;

  if (at(0, const [0xFF, 0xD8])) return _jpeg(b, data);
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) &&
      at(12, 'IHDR'.codeUnits)) {
    return sized('png', i32(16, Endian.big), i32(20, Endian.big));
  }
  if (at(0, 'GIF87a'.codeUnits) || at(0, 'GIF89a'.codeUnits)) {
    return sized('gif', u16(6), u16(8));
  }
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) {
    if (at(12, 'VP8 '.codeUnits) && at(23, const [0x9D, 0x01, 0x2A])) {
      return sized('webp', u16(26) & 0x3FFF, u16(28) & 0x3FFF);
    }
    if (at(12, 'VP8L'.codeUnits) && at(20, const [0x2F])) {
      final bits = i32(21);
      return sized('webp', (bits & 0x3FFF) + 1, (bits >> 14 & 0x3FFF) + 1);
    }
    if (at(12, 'VP8X'.codeUnits) && b.length >= 30) {
      return sized('webp', u24(24) + 1, u24(27) + 1);
    }
    return null;
  }
  if (at(0, 'BM'.codeUnits)) {
    // Height is negative for top-down rows.
    return i32(14) == 12
        ? sized('bmp', u16(18), u16(20))
        : sized('bmp', i32(18), i32(22).abs());
  }
  return null;
}

/// False for a picture cut short (a broken download or base64): its end
/// marker is not near the end of the data.
bool _isComplete(String extension, Uint8List b) {
  bool near(List<int> sign, int within) {
    final from = b.length - within < 0 ? 0 : b.length - within;
    outer:
    for (var i = b.length - sign.length; i >= from; i--) {
      for (var j = 0; j < sign.length; j++) {
        if (b[i + j] != sign[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  return switch (extension) {
    'png' => near('IEND'.codeUnits, 1024),
    'jpg' => near(const [0xFF, 0xD9], 1024),
    'gif' => near(const [0x3B], 16),
    'webp' =>
      ByteData.sublistView(b).getUint32(4, Endian.little) + 8 <= b.length,
    _ => true,
  };
}

/// Size from the first frame header (SOF) before the image data.
PictureHeader? _jpeg(Uint8List b, ByteData data) {
  var i = 2;
  while (i + 4 <= b.length) {
    if (b[i] != 0xFF) return null;
    final marker = b[i + 1];
    if (marker == 0xFF) {
      i++; // fill byte
      continue;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2; // no length
      continue;
    }
    if (marker == 0xD9 || marker == 0xDA) return null; // end or data
    final length = data.getUint16(i + 2);
    final frame =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (frame) {
      if (i + 9 > b.length) return null;
      final height = data.getUint16(i + 5);
      final width = data.getUint16(i + 7);
      return width > 0 && height > 0
          ? PictureHeader('jpg', width, height)
          : null;
    }
    if (length < 2) return null;
    i += 2 + length;
  }
  return null;
}
