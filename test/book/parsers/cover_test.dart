import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:book_app/book/model/book_cover.dart';
import 'package:book_app/book/parsers/epub_parser.dart';
import 'package:book_app/book/parsers/fb2_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// A PNG-looking picture: the signature, then [mark] repeated.
Uint8List png(int mark, [int length = 32]) => Uint8List(length)
  ..fillRange(0, length, mark)
  ..setRange(0, 8, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

Uint8List jpg(int mark) => Uint8List(32)
  ..fillRange(0, 32, mark)
  ..setRange(0, 3, const [0xFF, 0xD8, 0xFF]);

// ---------------------------------------------------------------- FB2

Uint8List fb2({
  String coverpage = '',
  Map<String, String> binaries = const {},
  bool cut = false,
}) {
  final xml =
      '<?xml version="1.0" encoding="utf-8"?>'
      '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" '
      'xmlns:l="http://www.w3.org/1999/xlink">'
      '<description><title-info><book-title>Книга</book-title>'
      '$coverpage</title-info></description>'
      '<body><section><p>Раз два три.</p></section></body>'
      '${[for (final MapEntry(:key, :value) in binaries.entries) '<binary id="$key" content-type="image/png">$value</binary>'].join()}'
      '${cut ? '' : '</FictionBook>'}';
  return utf8.encode(cut ? xml.substring(0, xml.length - 10) : xml);
}

String coverpage(String href, {String attr = 'l:href'}) =>
    '<coverpage><image $attr="$href"/></coverpage>';

BookCover? fb2Cover(Uint8List bytes) => parseFb2WithCover(bytes, title: 'x').$2;

// ---------------------------------------------------------------- EPUB

const _container =
    '<?xml version="1.0"?><container><rootfiles>'
    '<rootfile full-path="OEBPS/content.opf" '
    'media-type="application/oebps-package+xml"/></rootfiles></container>';

/// An EPUB with the OPF in `OEBPS/`: [items] are extra manifest lines,
/// [files] archive entries (paths from the root), [firstPage] the body of
/// the first spine file.
Uint8List epub({
  String metadata = '',
  String items = '',
  Map<String, List<int>> files = const {},
  String firstPage = '<p>Текст первой страницы книги.</p>',
}) {
  final opf =
      '<package><metadata>$metadata</metadata><manifest>'
      '<item id="p1" href="text/p1.xhtml" media-type="application/xhtml+xml"/>'
      '<item id="p2" href="text/p2.xhtml" media-type="application/xhtml+xml"/>'
      '$items</manifest><spine><itemref idref="p1"/><itemref idref="p2"/>'
      '</spine></package>';
  final archive = Archive()
    ..addFile(ArchiveFile.string('mimetype', 'application/epub+zip'))
    ..addFile(ArchiveFile.string('META-INF/container.xml', _container))
    ..addFile(ArchiveFile.string('OEBPS/content.opf', opf))
    ..addFile(
      ArchiveFile.string(
        'OEBPS/text/p1.xhtml',
        '<html><body>$firstPage</body></html>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'OEBPS/text/p2.xhtml',
        '<html><body><p>Раз два три.</p></body></html>',
      ),
    );
  for (final MapEntry(:key, :value) in files.entries) {
    archive.addFile(ArchiveFile.bytes(key, value));
  }
  return ZipEncoder().encodeBytes(archive);
}

String picture(String id, String href, {String props = ''}) =>
    '<item id="$id" href="$href" media-type="image/png"'
    '${props.isEmpty ? '' : ' properties="$props"'}/>';

BookCover? epubCover(Uint8List bytes) =>
    parseEpubWithCover(bytes, title: 'x').$2;

void main() {
  group('FB2', () {
    test('the coverpage picture is taken from its binary', () {
      final book = fb2(
        coverpage: coverpage('#cover.png'),
        binaries: {
          'other.png': base64.encode(png(1)),
          'cover.png': base64.encode(png(2)),
        },
      );

      final cover = fb2Cover(book)!;
      expect(cover.extension, 'png');
      expect(cover.bytes, png(2));
    });

    test('the type comes from the bytes; base64 with breaks, no padding', () {
      final data = base64.encode(jpg(3));
      final wrapped = '\n  ${data.substring(0, 10)}\n  ${data.substring(10)}\n'
          .replaceAll('=', '');
      final book = fb2(
        coverpage: coverpage('#c', attr: 'xlink:href'),
        binaries: {'c': wrapped},
      );

      final cover = fb2Cover(book)!;
      expect(cover.extension, 'jpg');
      expect(cover.bytes, jpg(3));
    });

    test('no usable cover → none, the text is still read', () {
      final cases = {
        'no coverpage': fb2(binaries: {'cover.png': base64.encode(png(1))}),
        'no such binary': fb2(
          coverpage: coverpage('#missing'),
          binaries: {'cover.png': base64.encode(png(1))},
        ),
        'broken base64': fb2(
          coverpage: coverpage('#c'),
          binaries: {'c': '%%%not base64%%%'},
        ),
        'not a picture': fb2(
          coverpage: coverpage('#c'),
          binaries: {'c': base64.encode(utf8.encode('<svg></svg>'))},
        ),
        'cut inside the binary': fb2(
          coverpage: coverpage('#c'),
          binaries: {'c': base64.encode(png(1, 600))},
          cut: true,
        ),
      };
      for (final MapEntry(key: name, value: bytes) in cases.entries) {
        final (content, cover) = parseFb2WithCover(bytes, title: 'x');
        expect(cover, isNull, reason: name);
        expect(content.sections, hasLength(1), reason: name);
      }
    });

    test('a picture bigger than the limit is not a cover', () {
      final book = fb2(
        coverpage: coverpage('#c'),
        binaries: {'c': base64.encode(png(1, maxCoverBytes + 1))},
      );

      expect(fb2Cover(book), isNull);
    });
  });

  group('EPUB', () {
    test('the EPUB 3 cover-image comes first', () {
      final book = epub(
        metadata: '<meta name="cover" content="m"/>',
        items:
            picture('m', 'img/meta.png') +
            picture('c', 'img/main.png', props: 'cover-image'),
        files: {'OEBPS/img/meta.png': png(1), 'OEBPS/img/main.png': png(2)},
      );

      expect(epubCover(book)!.bytes, png(2));
    });

    test('then the EPUB 2 meta cover: by id, or by path', () {
      final byId = epub(
        metadata: '<meta name="cover" content="pic"/>',
        items: picture('pic', '../Images/a%20b.png'),
        files: {'Images/a b.png': png(1)},
      );
      final byPath = epub(
        metadata: '<meta content="img/x.png" name="cover"/>',
        items: picture('x', 'img/x.png'),
        files: {'OEBPS/img/x.png': png(2)},
      );

      expect(epubCover(byId)!.bytes, png(1));
      expect(epubCover(byPath)!.bytes, png(2));
    });

    test('then a picture with "cover" in its id or name', () {
      final byName = epub(
        items: picture('i1', 'img/plate.png') + picture('i2', 'img/Cover.png'),
        files: {'OEBPS/img/plate.png': png(1), 'OEBPS/img/Cover.png': png(2)},
      );
      final byId = epub(
        items: picture('my-cover', 'img/1.png'),
        files: {'OEBPS/img/1.png': png(3)},
      );

      expect(epubCover(byName)!.bytes, png(2));
      expect(epubCover(byId)!.bytes, png(3));
    });

    test('a back cover is not taken for the cover by its name', () {
      final book = epub(
        items: [
          picture('i1', 'img/back_cover.png'),
          picture('i2', 'img/backcover.png'),
          picture('i3', 'img/bookcover.png'),
        ].join(),
        files: {
          'OEBPS/img/back_cover.png': png(1),
          'OEBPS/img/backcover.png': png(2),
          'OEBPS/img/bookcover.png': png(3),
        },
      );

      expect(epubCover(book)!.bytes, png(3));
    });

    test('a missing or unusable candidate falls through to the next', () {
      final book = epub(
        items: [
          picture('c', 'img/gone.png', props: 'cover-image'),
          '<item id="s" href="img/cover.svg" media-type="image/svg+xml"/>',
          picture('j', 'img/cover-big.png'),
          picture('k', 'img/cover.png'),
        ].join(),
        files: {
          'OEBPS/img/cover.svg': utf8.encode('<svg/>'),
          'OEBPS/img/cover-big.png': png(1, maxCoverBytes + 1),
          'OEBPS/img/cover.png': png(4),
        },
      );

      expect(epubCover(book)!.bytes, png(4));
    });

    test('then the first picture of a first page without text', () {
      final img = epub(
        firstPage: '<div><img alt="Обложка" src="../img/p.png"/></div>',
        items: picture('i', 'img/p.png'),
        files: {'OEBPS/img/p.png': png(5)},
      );
      final svg = epub(
        firstPage:
            '<svg xmlns:xlink="http://www.w3.org/1999/xlink">'
            '<image width="600" xlink:href="../img/p.png"/></svg>',
        items: picture('i', 'img/p.png'),
        files: {'OEBPS/img/p.png': png(6)},
      );

      expect(epubCover(img)!.bytes, png(5));
      expect(epubCover(svg)!.bytes, png(6));
    });

    test('the first page: entities decoded; comments, data-src skipped', () {
      final book = epub(
        firstPage:
            '<!-- <img src="../img/old.png"/> -->'
            '<img data-src="../img/lazy.png" src="../img/a&amp;b.png"/>',
        items: [
          picture('i1', 'img/old.png'),
          picture('i2', 'img/lazy.png'),
          picture('i3', 'img/a&amp;b.png'),
        ].join(),
        files: {
          'OEBPS/img/old.png': png(1),
          'OEBPS/img/lazy.png': png(2),
          'OEBPS/img/a&b.png': png(3),
        },
      );

      expect(epubCover(book)!.bytes, png(3));
    });

    test('a picture on a first page with text is not a cover', () {
      final book = epub(
        firstPage:
            '<p>${'Глава первая, в которой много текста. ' * 5}</p>'
            '<img src="../img/p.png"/>',
        items: picture('i', 'img/p.png'),
        files: {'OEBPS/img/p.png': png(5)},
      );

      expect(epubCover(book), isNull);
    });

    test('no pictures → no cover', () {
      expect(epubCover(epub()), isNull);
    });
  });
}
