import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:book_app/book/import/format_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real ZIP with these entries, in this order.
Uint8List zipOf(Map<String, String> entries) {
  final archive = Archive();
  entries.forEach(
    (name, data) => archive.addFile(ArchiveFile.string(name, data)),
  );
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  test('detects formats by content', () {
    final cases = <String, (Uint8List, DetectedFormat)>{
      'epub': (
        zipOf({
          'mimetype': 'application/epub+zip',
          'META-INF/container.xml': '<container/>',
        }),
        DetectedFormat.epub,
      ),
      'epub without mimetype first': (
        zipOf({'OEBPS/a.xhtml': '<html/>', 'META-INF/container.xml': '<c/>'}),
        DetectedFormat.epub,
      ),
      'epub zipped on Windows': (
        zipOf({r'META-INF\Container.xml': '<c/>', 'a.xhtml': '<html/>'}),
        DetectedFormat.epub,
      ),
      'mimetype alone is not epub': (
        zipOf({'mimetype': 'application/epub+zip'}),
        DetectedFormat.zip,
      ),
      'fb2.zip': (zipOf({'Book.FB2': '<?xml'}), DetectedFormat.zip),
      'local header only': (
        Uint8List.fromList([0x50, 0x4B, 3, 4, ...List.filled(40, 0)]),
        DetectedFormat.zip,
      ),
      'fb2 utf8': (
        utf8.encode('<?xml version="1.0"?>\n<FictionBook xmlns="x">'),
        DetectedFormat.fb2,
      ),
      'fb2 with prefix': (
        utf8.encode('<?xml?><fb:FictionBook xmlns:fb="x">'),
        DetectedFormat.fb2,
      ),
      'FictionBooks is not fb2': (
        utf8.encode('<FictionBooks>'),
        DetectedFormat.txt,
      ),
      'fb2 utf16': (
        Uint8List.fromList([
          0xFF, 0xFE, //
          for (final c in '<FictionBook>'.codeUnits) ...[c, 0],
        ]),
        DetectedFormat.fb2,
      ),
      'text': (utf8.encode('Глава 1\n\nТекст.'), DetectedFormat.txt),
      'empty': (Uint8List(0), DetectedFormat.txt),
      'short PK': (utf8.encode('PK'), DetectedFormat.txt),
    };
    cases.forEach((name, c) {
      expect(detectFormat(c.$1), c.$2, reason: name);
    });
  });

  test('fixture books are detected as their format', () {
    for (final f in Directory('test/fixtures').listSync(recursive: true)) {
      final path = f.path.replaceAll(r'\', '/');
      if (path.endsWith('.json') || f is! File) continue;
      final expected = path.endsWith('.fb2')
          ? DetectedFormat.fb2
          : path.endsWith('.zip')
          ? DetectedFormat.zip
          : path.endsWith('.epub')
          ? DetectedFormat.epub
          : DetectedFormat.txt;
      expect(detectFormat(f.readAsBytesSync()), expected, reason: path);
    }
  });
}
