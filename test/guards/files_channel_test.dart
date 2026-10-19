import 'dart:io';

import 'package:book_app/platform/files_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// ADR 0005: channel and method names must match in Dart and native code;
/// Info.plist declares the book types iOS should hand to the app.
void main() {
  test('MainActivity.kt uses the Dart channel and method names', () {
    final kotlin = File(
      'android/app/src/main/kotlin/com/tonyvinsenty/bookapp/MainActivity.kt',
    ).readAsStringSync();
    expect(kotlin, contains('"$filesChannelName"'));
    expect(kotlin, contains('"$pickBooksMethod"'));
  });

  test('AppDelegate.swift uses the Dart channel and method names', () {
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(swift, contains('"$filesChannelName"'));
    expect(swift, contains('"$pickBooksMethod"'));
  });

  group('Info.plist', () {
    final plist = _plistDict(File('ios/Runner/Info.plist'));

    test('declares the FB2 type by extension', () {
      final types = plist['UTImportedTypeDeclarations'] as List<Object?>;
      final fb2 = types.cast<Map<String, Object?>>().singleWhere(
        (t) => t['UTTypeIdentifier'] == _fb2Type,
      );
      final tags = fb2['UTTypeTagSpecification']! as Map<String, Object?>;
      expect(tags['public.filename-extension'], contains('fb2'));
    });

    test('opens FB2 and plain text as copies', () {
      final docs = plist['CFBundleDocumentTypes'] as List<Object?>;
      final contentTypes = [
        for (final d in docs.cast<Map<String, Object?>>())
          ...(d['LSItemContentTypes']! as List<Object?>),
      ];
      expect(contentTypes, containsAll([_fb2Type, 'public.plain-text']));
      expect(plist['LSSupportsOpeningDocumentsInPlace'], isFalse);
    });
  });
}

const _fb2Type = 'com.tonyvinsenty.bookapp.fb2';

Map<String, Object?> _plistDict(File file) {
  final root = XmlDocument.parse(file.readAsStringSync()).rootElement;
  return _plistValue(root.childElements.single)! as Map<String, Object?>;
}

Object? _plistValue(XmlElement e) => switch (e.name.local) {
  'dict' => {
    for (final (key, value) in _pairs(e.childElements.toList()))
      key.innerText: _plistValue(value),
  },
  'array' => [for (final c in e.childElements) _plistValue(c)],
  'true' => true,
  'false' => false,
  _ => e.innerText,
};

Iterable<(XmlElement, XmlElement)> _pairs(List<XmlElement> items) sync* {
  for (var i = 0; i + 1 < items.length; i += 2) {
    yield (items[i], items[i + 1]);
  }
}
