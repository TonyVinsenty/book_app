import 'dart:typed_data';

import 'package:book_app/book/model/book_image.dart';
import 'package:flutter_test/flutter_test.dart';

/// Little-endian bytes of [value].
List<int> le(int value, int length) => [
  for (var i = 0; i < length; i++) value >> (8 * i) & 0xFF,
];

List<int> be(int value, int length) => le(value, length).reversed.toList();

Uint8List png(int width, int height) => Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ...be(13, 4), ...'IHDR'.codeUnits, ...be(width, 4), ...be(height, 4),
  8, 6, 0, 0, 0, //
  ...pngEnd,
]);

/// APP1 with one IFD entry: the orientation.
List<int> exif(int orientation, List<int> Function(int, int) n) => [
  0xFF, 0xE1, ...be(34, 2), ...'Exif'.codeUnits, 0, 0, //
  ...(identical(n, be) ? 'MM' : 'II').codeUnits, ...n(42, 2), ...n(8, 4),
  ...n(1, 2), ...n(0x0112, 2), ...n(3, 2), ...n(1, 4), ...n(orientation, 2),
  0, 0, ...n(0, 4),
];

const pngEnd = [0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82];

/// APP0, EXIF with [orientation] if given, a DQT and then the frame
/// header.
Uint8List jpeg(
  int width,
  int height, {
  int sof = 0xC0,
  int? orientation,
  bool motorola = false,
}) => Uint8List.fromList([
  0xFF, 0xD8, //
  0xFF, 0xE0, ...be(16, 2), ...'JFIF'.codeUnits, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0,
  if (orientation != null) ...exif(orientation, motorola ? be : le),
  0xFF, 0xFF, // fill
  0xFF, 0xDB, ...be(3, 2), 0,
  0xFF, sof, ...be(17, 2), 8, ...be(height, 2), ...be(width, 2), 3,
  ...List.filled(9, 0),
  0xFF, 0xD9,
]);

void main() {
  group('picture header', () {
    final cases = <String, (Uint8List, String, int, int)>{
      'PNG': (png(640, 480), 'png', 640, 480),
      'JPEG baseline': (jpeg(800, 600), 'jpg', 800, 600),
      'JPEG progressive': (jpeg(1024, 33, sof: 0xC2), 'jpg', 1024, 33),
      'JPEG turned by EXIF': (jpeg(800, 600, orientation: 6), 'jpg', 600, 800),
      'JPEG turned by EXIF (Motorola)': (
        jpeg(800, 600, orientation: 8, motorola: true),
        'jpg',
        600,
        800,
      ),
      'JPEG upright by EXIF': (jpeg(800, 600, orientation: 3), 'jpg', 800, 600),
      'GIF': (
        Uint8List.fromList([
          ...'GIF89a'.codeUnits,
          ...le(320, 2),
          ...le(200, 2),
        ]),
        'gif',
        320,
        200,
      ),
      'WebP lossy': (
        Uint8List.fromList([
          ...'RIFF'.codeUnits, ...le(100, 4), ...'WEBPVP8 '.codeUnits, //
          ...le(80, 4), 0, 0, 0, 0x9D, 0x01, 0x2A, ...le(500, 2), ...le(300, 2),
        ]),
        'webp',
        500,
        300,
      ),
      'WebP lossless': (
        Uint8List.fromList([
          ...'RIFF'.codeUnits, ...le(100, 4), ...'WEBPVP8L'.codeUnits, //
          ...le(80, 4), 0x2F, ...le((400 - 1) | (250 - 1) << 14, 4),
        ]),
        'webp',
        400,
        250,
      ),
      'WebP extended': (
        Uint8List.fromList([
          ...'RIFF'.codeUnits, ...le(100, 4), ...'WEBPVP8X'.codeUnits, //
          ...le(10, 4), 0, 0, 0, 0, ...le(4000 - 1, 3), ...le(3000 - 1, 3),
        ]),
        'webp',
        4000,
        3000,
      ),
      'BMP top-down': (
        Uint8List.fromList([
          ...'BM'.codeUnits, ...List.filled(12, 0), ...le(40, 4), //
          ...le(120, 4), ...le(-90, 4),
        ]),
        'bmp',
        120,
        90,
      ),
      'BMP old header': (
        Uint8List.fromList([
          ...'BM'.codeUnits, ...List.filled(12, 0), ...le(12, 4), //
          ...le(64, 2), ...le(32, 2),
        ]),
        'bmp',
        64,
        32,
      ),
    };
    cases.forEach((name, c) {
      test(name, () {
        final (bytes, ext, width, height) = c;
        final header = readPictureHeader(bytes)!;
        expect(
          [header.extension, header.width, header.height],
          [ext, width, height],
        );
      });
    });

    test('broken or unknown data → null', () {
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList('<svg/>'.codeUnits),
        Uint8List.sublistView(png(10, 10), 0, 18), // cut
        Uint8List.sublistView(jpeg(10, 10), 0, 30), // cut before the frame
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDA, 0, 2]), // data, no frame
        png(0, 10),
      ]) {
        expect(readPictureHeader(bytes), isNull, reason: '$bytes');
      }
    });
  });

  group('book images', () {
    test('numbered in book order, the same key stored once', () {
      final sink = MemoryImageSink();
      final images = BookImages(sink);
      var loads = 0;
      Uint8List load(Uint8List b) {
        loads++;
        return b;
      }

      final a = images.add('a', () => load(png(100, 50)))!;
      final b = images.add('b', () => load(jpeg(20, 300)))!;
      final again = images.add('a', () => load(png(100, 50)));

      expect([a.assetId, a.width, a.height], ['1.png', 100, 50]);
      expect(b.assetId, '2.jpg');
      expect(again, same(a));
      expect(loads, 2);
      expect(sink.files.keys, ['1.png', '2.jpg']);
    });

    test('pictures over the limits are skipped', () {
      final sink = MemoryImageSink();
      final images = BookImages(sink);

      expect(images.add('missing', () => null), isNull);
      expect(
        images.add('svg', () => Uint8List.fromList('<svg>'.codeUnits)),
        isNull,
      );
      expect(images.add('spacer', () => png(15, 15)), isNull);
      expect(images.add('line', () => png(600, 2)), isNotNull);
      expect(images.add('huge', () => png(10000, 6000)), isNull);
      expect(
        images.add(
          'heavy',
          () => Uint8List(maxImageBytes + 1)..setAll(0, png(10, 20)),
        ),
        isNull,
      );
      expect(sink.files.keys, ['1.png']);
    });

    test('a picture cut short is skipped', () {
      final images = BookImages();
      final full = png(100, 50);
      final cut = Uint8List.sublistView(full, 0, full.length - pngEnd.length);
      expect(images.add('png', () => cut), isNull);
      final jpg = jpeg(100, 50);
      expect(
        images.add('jpg', () => Uint8List.sublistView(jpg, 0, jpg.length - 2)),
        isNull,
      );
      expect(images.add('whole', () => full), isNotNull);
    });

    test('a book keeps at most $maxBookImages pictures', () {
      final images = BookImages();
      for (var i = 0; i < maxBookImages; i++) {
        expect(images.add('$i', () => png(20, 20)), isNotNull);
      }
      expect(images.add('one more', () => png(20, 20)), isNull);
    });

    test('and at most ${maxBookImageBytes ~/ (1024 * 1024)} MB', () {
      final images = BookImages();
      Uint8List big() => Uint8List(maxImageBytes)
        ..setAll(0, png(100, 100))
        ..setAll(maxImageBytes - pngEnd.length, pngEnd);
      var added = 0;
      for (var i = 0; images.add('$i', big) != null; i++) {
        added++;
      }
      expect(added, maxBookImageBytes ~/ maxImageBytes);
      expect(images.add('small', () => png(20, 20)), isNull); // full
    });
  });
}
