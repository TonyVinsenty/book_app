import 'dart:convert';
import 'dart:typed_data';

import 'package:book_app/book/encoding/code_pages.dart';
import 'package:book_app/book/encoding/text_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List bytes(List<int> b) => Uint8List.fromList(b);

/// Encodes [text] with a code page table (test helper, inverse of decoding).
Uint8List encodeSingleByte(String text, String high) => bytes([
  for (final c in text.codeUnits)
    c < 0x80 ? c : 0x80 + high.indexOf(String.fromCharCode(c)),
]);

const russian =
    'Утро было тихим, и над рекой ещё стоял туман. Анна вышла на крыльцо.';

void main() {
  test('code page tables have 128 chars', () {
    expect(windows1251High.length, 128);
    expect(koi8rHigh.length, 128);
  });

  test('known bytes', () {
    // «Привет» in Windows-1251 and KOI8-R.
    expect(
      decodeText(bytes([0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2])).text,
      'Привет',
    );
    expect(
      decodeText(
        bytes([0xF0, 0xD2, 0xC9, 0xD7, 0xC5, 0xD4]),
        declared: TextEncoding.koi8r,
      ).text,
      'Привет',
    );
  });

  group('detection', () {
    final cases = <String, (Uint8List, TextEncoding)>{
      'ASCII': (bytes(ascii.encode('Hello, world')), TextEncoding.utf8),
      'UTF-8': (bytes(utf8.encode(russian)), TextEncoding.utf8),
      'UTF-8 with BOM': (
        bytes([0xEF, 0xBB, 0xBF, ...utf8.encode(russian)]),
        TextEncoding.utf8,
      ),
      'UTF-16 LE with BOM': (
        bytes([0xFF, 0xFE, ...utf16le(russian)]),
        TextEncoding.utf16le,
      ),
      'UTF-16 BE with BOM': (
        bytes([0xFE, 0xFF, ...utf16be(russian)]),
        TextEncoding.utf16be,
      ),
      'UTF-16 LE without BOM': (bytes(utf16le(russian)), TextEncoding.utf16le),
      'Windows-1251': (
        encodeSingleByte(russian, windows1251High),
        TextEncoding.windows1251,
      ),
      'KOI8-R': (encodeSingleByte(russian, koi8rHigh), TextEncoding.koi8r),
      'short Windows-1251': (
        encodeSingleByte('Да, это он.', windows1251High),
        TextEncoding.windows1251,
      ),
      'short KOI8-R': (
        encodeSingleByte('Да, это он.', koi8rHigh),
        TextEncoding.koi8r,
      ),
    };
    cases.forEach((name, c) {
      test(name, () {
        final (input, encoding) = c;
        final decoded = decodeText(input);
        expect(decoded.encoding, encoding);
        expect(
          decoded.text,
          contains(
            name == 'ASCII'
                ? 'world'
                : name.startsWith('short')
                ? 'это'
                : 'крыльцо',
          ),
        );
      });
    });
  });

  test('valid UTF-8 wins over a wrong declaration', () {
    final d = decodeText(
      bytes(utf8.encode(russian)),
      declared: TextEncoding.windows1251,
    );
    expect(d.encoding, TextEncoding.utf8);
    expect(d.text, russian);
  });

  test('UTF-8 with a broken byte or a cut last char is still UTF-8', () {
    final good = utf8.encode(List.filled(10, russian).join(' '));
    final stray = bytes([...good.take(20), 0xFF, ...good.skip(20)]);
    final cut = bytes(
      good.take(good.length - 1).toList()..addAll(utf8.encode('Ж').take(1)),
    );
    for (final input in [stray, cut]) {
      final d = decodeText(input);
      expect(d.encoding, TextEncoding.utf8);
      expect(d.text, contains('крыльцо'));
    }
  });

  test('declared encoding is used for non-UTF-8 bytes', () {
    // Ambiguous short text: the declaration decides.
    final d = decodeText(
      encodeSingleByte('ОК', koi8rHigh),
      declared: TextEncoding.koi8r,
    );
    expect(d.text, 'ОК');
  });

  test('binary files are not text', () {
    final binary = bytes([for (var i = 0; i < 2000; i++) (i * 37) % 256]);
    expect(() => decodeText(binary), throwsA(isA<NotTextException>()));
    expect(
      () => decodeText(bytes([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0, 0, 0])),
      throwsA(isA<NotTextException>()),
    );
  });

  test('empty file is empty text', () {
    expect(decodeText(bytes([])).text, '');
  });

  test('encoding names', () {
    expect(encodingByName('Windows-1251'), TextEncoding.windows1251);
    expect(encodingByName(' koi8-r '), TextEncoding.koi8r);
    expect(encodingByName('UTF-8'), TextEncoding.utf8);
    expect(encodingByName('iso-8859-5'), isNull);
  });
}

List<int> utf16le(String s) => [
  for (final c in s.codeUnits) ...[c & 0xFF, c >> 8],
];

List<int> utf16be(String s) => [
  for (final c in s.codeUnits) ...[c >> 8, c & 0xFF],
];
