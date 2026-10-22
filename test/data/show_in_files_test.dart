import 'dart:io';

import 'package:book_app/data/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory documents;

  setUp(() => documents = Directory.systemTemp.createTempSync('documents_'));
  tearDown(() => documents.deleteSync(recursive: true));

  List<String> names() => [
    for (final entity in documents.listSync())
      entity.path.split(Platform.pathSeparator).last,
  ]..sort();

  test('an empty folder gets Books, so Files shows it', () async {
    await showInFiles(documents);
    expect(names(), ['Books']);
  });

  test('hidden files alone still count as empty', () async {
    File('${documents.path}/.Trash').writeAsStringSync('');
    await showInFiles(documents);
    expect(names(), ['.Trash', 'Books']);
  });

  test('a folder with books is left as it is', () async {
    File('${documents.path}/a.fb2').writeAsStringSync('x');
    await showInFiles(documents);
    expect(names(), ['a.fb2']);
  });
}
