import 'dart:typed_data';

import 'package:book_app/book/model/book_cover.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List bytesOf(List<int> head, [int length = 64]) =>
    Uint8List(length)..setRange(0, head.length, head);

void main() {
  test('the picture type comes from the bytes', () {
    final cases = {
      'jpg': [0xFF, 0xD8, 0xFF, 0xE0],
      'png': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      'gif': 'GIF89a'.codeUnits,
      'webp': [...'RIFF'.codeUnits, 1, 2, 3, 4, ...'WEBP'.codeUnits],
    };
    for (final MapEntry(key: type, value: head) in cases.entries) {
      final cover = coverFromBytes(bytesOf(head));
      expect(cover?.extension, type, reason: type);
      expect(cover!.bytes, hasLength(64));
    }
  });

  test('not a picture, a cut signature or too big → no cover', () {
    expect(coverFromBytes(Uint8List(0)), isNull);
    expect(coverFromBytes(bytesOf('<svg'.codeUnits)), isNull);
    expect(coverFromBytes(bytesOf('BM'.codeUnits)), isNull, reason: 'BMP');
    expect(coverFromBytes(Uint8List.fromList([0x89, 0x50, 0x4E])), isNull);
    expect(coverFromBytes(bytesOf('RIFF'.codeUnits)), isNull, reason: 'WAV');
    expect(
      coverFromBytes(bytesOf([0xFF, 0xD8, 0xFF], maxCoverBytes)),
      isNotNull,
    );
    expect(
      coverFromBytes(bytesOf([0xFF, 0xD8, 0xFF], maxCoverBytes + 1)),
      isNull,
    );
  });
}
