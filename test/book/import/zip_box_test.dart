import 'dart:io';

import 'package:archive/archive.dart';
import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/book/import/zip_box.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// An entry that only claims [size]: the limits look at the declared size.
  ArchiveFile claiming(String name, int size) =>
      ArchiveFile.string(name, 'x')..size = size;

  List<String> names(Archive a) => [for (final f in boxedBooks(a)) f.name];

  test('books in a box: by extension, in archive order', () {
    final archive = Archive()
      ..addFile(ArchiveFile.directory('dir/'))
      ..addFile(ArchiveFile.string('dir/b.FB2', 'x'))
      ..addFile(ArchiveFile.string('a.txt', 'x'))
      ..addFile(ArchiveFile.string('c.epub', 'x'))
      ..addFile(ArchiveFile.string('inner.zip', 'x'))
      ..addFile(ArchiveFile.string('cover.jpg', 'x'))
      ..addFile(ArchiveFile.string('__MACOSX/dir/._b.fb2', 'x'))
      ..addFile(ArchiveFile.string('._a.txt', 'x'));

    expect(names(archive), ['dir/b.FB2', 'a.txt', 'c.epub']);
  });

  test('size limits against zip bombs', () {
    final archive = Archive()
      ..addFile(claiming('huge.fb2', maxBoxedBookSize + 1))
      ..addFile(claiming('a.fb2', maxBoxedBookSize))
      ..addFile(claiming('b.fb2', maxBoxedBookSize))
      ..addFile(claiming('c.fb2', maxBoxedBookSize))
      ..addFile(claiming('d.fb2', 1));

    expect(names(archive), ['a.fb2', 'b.fb2', 'c.fb2']);

    expect(
      names(
        Archive()
          ..addFile(claiming('a.fb2', maxBoxedBookSize))
          ..addFile(claiming('b.fb2', maxBoxedBookSize))
          ..addFile(claiming('c.fb2', maxBoxedBookSize - 1))
          ..addFile(claiming('d.fb2', 2))
          ..addFile(claiming('e.fb2', 1)),
      ),
      ['a.fb2', 'b.fb2', 'c.fb2', 'e.fb2'],
    );
  });

  group('unpackBox', () {
    late Directory temp;
    setUp(() => temp = Directory.systemTemp.createTempSync('box_'));
    tearDown(() => temp.deleteSync(recursive: true));

    String zip(Archive archive) {
      final path = '${temp.path}/in.zip';
      File(path).writeAsBytesSync(ZipEncoder().encodeBytes(archive));
      return path;
    }

    test('names from the archive cannot leave the folder', () {
      final path = zip(
        Archive()..addFile(ArchiveFile.string('../../evil.txt', 'текст')),
      );

      final out = unpackBox(path, '${temp.path}/out')!;

      expect(out, ['${temp.path}/out/0/evil.txt']);
      expect(File(out.single).readAsStringSync(), 'текст');
      expect(File('${temp.path}/evil.txt').existsSync(), isFalse);
    });

    test('not a box: plain files and EPUB', () {
      final txt = File('${temp.path}/a.txt')..writeAsStringSync('PK text');
      final epub = zip(
        Archive()..addFile(ArchiveFile.string('META-INF/container.xml', '')),
      );

      expect(unpackBox(txt.path, '${temp.path}/o1'), isNull);
      expect(unpackBox(epub, '${temp.path}/o2'), isNull);
      expect(Directory('${temp.path}/o2').existsSync(), isFalse);
    });

    test('several books each get their own folder', () {
      final path = zip(
        Archive()
          ..addFile(ArchiveFile.string('x/book.txt', 'один'))
          ..addFile(ArchiveFile.string('y/book.txt', 'два')),
      );

      final out = unpackBox(path, '${temp.path}/out')!;

      expect(
        [for (final p in out) File(p).readAsStringSync()],
        ['один', 'два'],
      );
    });

    test('a box without books is unsupported', () {
      final path = zip(Archive()..addFile(ArchiveFile.string('a.png', 'x')));

      expect(
        () => unpackBox(path, '${temp.path}/out'),
        throwsA(
          isA<ImportException>().having(
            (e) => e.error,
            'error',
            ImportError.unsupportedFormat,
          ),
        ),
      );
    });
  });
}
