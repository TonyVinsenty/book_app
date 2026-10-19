import 'dart:io';

import 'package:book_app/platform/files_channel.dart';
import 'package:flutter_test/flutter_test.dart';

/// ADR 0005: channel and method names must match in Dart and native code.
void main() {
  test('MainActivity.kt uses the Dart channel and method names', () {
    final kotlin = File(
      'android/app/src/main/kotlin/com/tonyvinsenty/bookapp/MainActivity.kt',
    ).readAsStringSync();
    expect(kotlin, contains('"$filesChannelName"'));
    expect(kotlin, contains('"$pickBooksMethod"'));
  });
}
