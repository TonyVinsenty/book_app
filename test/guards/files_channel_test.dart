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
    expect(kotlin, contains('"$hasInitialFilesMethod"'));
    expect(kotlin, contains('"$onIncomingFilesMethod"'));
  });

  group('AndroidManifest.xml', () {
    const android = 'http://schemas.android.com/apk/res/android';
    final activity = XmlDocument.parse(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
    ).findAllElements('activity').single;

    List<String> values(XmlElement filter, String tag, String attribute) => [
      for (final e in filter.findElements(tag))
        ?e.getAttribute(attribute, namespaceUri: android),
    ];

    XmlElement filterFor(String action) => activity
        .findElements('intent-filter')
        .singleWhere((f) => values(f, 'action', 'name').contains(action));

    test('one copy of the app takes every file (singleTask)', () {
      expect(
        activity.getAttribute('launchMode', namespaceUri: android),
        'singleTask',
      );
    });

    test('"Open with" takes book types, plain text included', () {
      final view = filterFor('android.intent.action.VIEW');
      expect(values(view, 'category', 'name'), [
        'android.intent.category.DEFAULT',
      ]);
      expect(values(view, 'data', 'scheme'), ['content']);
      expect(
        values(view, 'data', 'mimeType'),
        unorderedEquals([
          ..._bookTypes,
          'text/plain',
          'application/octet-stream',
        ]),
      );
    });

    test('"Share" takes book types, but not plain text', () {
      final send = filterFor('android.intent.action.SEND');
      expect(
        values(send, 'action', 'name'),
        contains('android.intent.action.SEND_MULTIPLE'),
      );
      expect(
        values(send, 'data', 'mimeType'),
        unorderedEquals([..._bookTypes, 'application/octet-stream']),
      );
    });
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

const _bookTypes = [
  'application/epub+zip',
  'application/x-fictionbook+xml',
  'application/x-fictionbook',
  'application/zip',
  'application/x-zip-compressed',
];

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
