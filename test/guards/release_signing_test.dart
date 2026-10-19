import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The release build must be signed only with the owner's key
/// (docs/how-to-android-release.md), never with the debug key.
void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  test('release signing reads the key from the environment variable', () {
    expect(gradle, contains('System.getenv("BOOKAPP_KEYSTORE_PROPERTIES")'));
    expect(gradle, contains('signingConfigs.getByName("release")'));
  });

  test('release build type never falls back to the debug key', () {
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
  });

  test('release build without the key stops with a message', () {
    expect(gradle, contains('throw GradleException('));
  });
}
