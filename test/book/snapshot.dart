import 'dart:convert';
import 'dart:io';

import 'package:book_app/book/model/book_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compares [content] with the saved snapshot `<fixture>.json`. Run with
/// `UPDATE_SNAPSHOTS=1` to (re)write snapshots, then review the diff.
void expectSnapshot(BookContent content, String fixturePath) {
  final actual =
      '${const JsonEncoder.withIndent('  ').convert(content.toJson())}\n';
  final file = File('$fixturePath.json');
  if (Platform.environment['UPDATE_SNAPSHOTS'] == '1') {
    file.writeAsStringSync(actual);
    return;
  }
  expect(
    file.existsSync(),
    isTrue,
    reason: 'No snapshot $fixturePath.json; run with UPDATE_SNAPSHOTS=1',
  );
  expect(
    actual,
    file.readAsStringSync().replaceAll('\r\n', '\n'),
    reason: 'Snapshot $fixturePath.json differs; rerun with UPDATE_SNAPSHOTS=1',
  );
}
