import 'package:flutter/services.dart';

/// Hands a file to the system share sheet (11а.6): `MainActivity.kt`
/// (FileProvider + ACTION_SEND) and `AppDelegate.swift`
/// (UIActivityViewController). Android shares only files in the cache's
/// `share/` folder (`res/xml/share_paths.xml`).
const shareChannelName = 'com.tonyvinsenty.bookapp/share';
const shareFileMethod = 'shareFile';

/// Shows the share sheet for the file at [path] of type [mime]; done once
/// the sheet is shown, not when the file is sent.
typedef ShareFile = Future<void> Function(String path, String mime);

const _channel = MethodChannel(shareChannelName);

Future<void> shareFile(String path, String mime) =>
    _channel.invokeMethod<void>(shareFileMethod, {'path': path, 'mime': mime});
