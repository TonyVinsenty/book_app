import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Native file access (ADR 0005): `MainActivity.kt` and `AppDelegate.swift`.
const filesChannelName = 'com.tonyvinsenty.bookapp/files';
const pickBooksMethod = 'pickBooks';

/// Dart → native: was the app started with files ("Open with", "Share")?
/// They follow through [onIncomingFilesMethod].
const hasInitialFilesMethod = 'hasInitialFiles';

/// Native → Dart: private copies of files from other apps. A file that
/// couldn't be copied comes as a path with nothing there.
const onIncomingFilesMethod = 'onIncomingFiles';

/// Lets the user choose book files; returns paths to private copies in the
/// cache folder (empty when cancelled). The caller deletes the copies.
typedef PickBooks = Future<List<String>> Function();

/// Whether the app was started with files; asked once, before the first
/// screen, and answered at once (the copies come later).
typedef HasInitialFiles = Future<bool> Function();

const _channel = MethodChannel(filesChannelName);

Future<List<String>> _pickBooks() async {
  final paths = await _channel.invokeListMethod<String>(pickBooksMethod);
  return paths ?? const [];
}

Future<bool> _hasInitialFiles() async {
  try {
    return await _channel.invokeMethod<bool>(hasInitialFilesMethod) ?? false;
  } on MissingPluginException {
    // A platform without the native side (tests, desktop).
    return false;
  } on PlatformException {
    return false;
  }
}

/// A folder the user chose: an opaque handle for the native side and the
/// name to show.
typedef PickedFolder = ({String ref, String name});

/// Lets the user choose a folder; null when cancelled.
typedef PickFolder = Future<PickedFolder?> Function();

/// Gives back the access to a disconnected folder.
typedef ReleaseFolder = Future<void> Function(String ref);

/// Null while the platform can't pick folders (Android — stage 11.5, iOS —
/// 11.7): "Подключить папку" is hidden. Tests override it.
final pickFolderProvider = Provider<PickFolder?>((ref) => null);

final releaseFolderProvider = Provider<ReleaseFolder>((ref) => (_) async {});

/// Tests override it with a fake.
final pickBooksProvider = Provider<PickBooks>((ref) => _pickBooks);

final hasInitialFilesProvider = Provider<HasInitialFiles>(
  (ref) => _hasInitialFiles,
);

/// Batches of files (private copies) that come while the app runs. The
/// stream buffers until its one listener comes, so nothing is lost while
/// the first screen builds. Tests override it.
final incomingFilesProvider = Provider<Stream<List<String>>>((ref) {
  final controller = StreamController<List<String>>();
  _channel.setMethodCallHandler((call) async {
    if (call.method != onIncomingFilesMethod) {
      throw MissingPluginException(call.method);
    }
    final paths = (call.arguments as List<Object?>).cast<String>();
    if (paths.isNotEmpty) controller.add(paths);
  });
  ref.onDispose(() {
    _channel.setMethodCallHandler(null);
    unawaited(controller.close());
  });
  return controller.stream;
});
