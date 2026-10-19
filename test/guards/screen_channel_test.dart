import 'dart:io';

import 'package:book_app/platform/screen_channel.dart';
import 'package:flutter_test/flutter_test.dart';

/// ADR 0004 «Изменения»: the keep-screen-on channel and method names must
/// match in Dart and native code.
void main() {
  test('MainActivity.kt uses the Dart channel and method names', () {
    final kotlin = File(
      'android/app/src/main/kotlin/com/tonyvinsenty/bookapp/MainActivity.kt',
    ).readAsStringSync();
    expect(kotlin, contains('"$screenChannelName"'));
    expect(kotlin, contains('"$setKeepOnMethod"'));
    expect(kotlin, contains('FLAG_KEEP_SCREEN_ON'));
  });

  test('AppDelegate.swift uses the Dart channel and method names', () {
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(swift, contains('"$screenChannelName"'));
    expect(swift, contains('"$setKeepOnMethod"'));
    expect(swift, contains('isIdleTimerDisabled'));
  });
}
