import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR 0006, 0009: `lib/book/`, `lib/speed/` and `lib/stats/` are pure Dart,
/// so they can run in isolates and be tested without widgets.
void main() {
  const pureDirs = ['lib/book', 'lib/speed', 'lib/stats'];
  final flutterImport = RegExp(r'''import\s+['"]package:flutter(_test)?/''');
  final dartUiImport = RegExp(r'''import\s+['"]dart:ui['"]''');

  for (final dir in pureDirs) {
    test('$dir does not import Flutter', () {
      final offenders = <String>[];
      for (final file in Directory(dir).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final text = file.readAsStringSync();
        if (flutterImport.hasMatch(text) || dartUiImport.hasMatch(text)) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty, reason: 'Flutter imports found in $dir');
    });
  }

  test('the guard regexps catch Flutter imports', () {
    expect(
      flutterImport.hasMatch("import 'package:flutter/material.dart';"),
      isTrue,
    );
    expect(dartUiImport.hasMatch("import 'dart:ui';"), isTrue);
    expect(flutterImport.hasMatch("import 'package:xml/xml.dart';"), isFalse);
  });
}
