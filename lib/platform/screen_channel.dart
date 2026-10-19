import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps the screen on while a book is open (ADR 0004 «Изменения»):
/// `MainActivity.kt` and `AppDelegate.swift`. Both systems drop it by
/// themselves when the app goes to the background.
const screenChannelName = 'com.tonyvinsenty.bookapp/screen';
const setKeepOnMethod = 'setKeepOn';

typedef KeepScreenOn = Future<void> Function(bool on);

const _channel = MethodChannel(screenChannelName);

Future<void> _keepScreenOn(bool on) async {
  try {
    await _channel.invokeMethod<void>(setKeepOnMethod, on);
  } on MissingPluginException {
    // No native side (tests, other platforms): the screen just dims.
  }
}

/// Tests override it to see the calls.
final keepScreenOnProvider = Provider<KeepScreenOn>((ref) => _keepScreenOn);
