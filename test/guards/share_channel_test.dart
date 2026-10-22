import 'dart:io';

import 'package:book_app/platform/share_channel.dart';
import 'package:flutter_test/flutter_test.dart';

/// 11а.6: the share channel and method names must match in Dart and native
/// code, and Android's FileProvider must give the folder Dart copies into.
void main() {
  test('MainActivity.kt uses the Dart channel and method names', () {
    final kotlin = File(
      'android/app/src/main/kotlin/com/tonyvinsenty/bookapp/MainActivity.kt',
    ).readAsStringSync();
    expect(kotlin, contains('"$shareChannelName"'));
    expect(kotlin, contains('"$shareFileMethod"'));
    expect(kotlin, contains(r'"$packageName.share"'));
  });

  test('the manifest declares the FileProvider for the share folder', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains(r'android:authorities="${applicationId}.share"'));
    expect(manifest, contains('@xml/share_paths'));
    final paths = File('android/app/src/main/res/xml/share_paths.xml')
        .readAsStringSync();
    expect(paths, contains('<cache-path name="share" path="share/" />'));
  });

  test('AppDelegate.swift uses the Dart channel and method names', () {
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(swift, contains('"$shareChannelName"'));
    expect(swift, contains('"$shareFileMethod"'));
    expect(swift, contains('UIActivityViewController'));
    expect(swift, contains('popoverPresentationController'));
  });
}
