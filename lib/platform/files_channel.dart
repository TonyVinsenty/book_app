import 'dart:async';
import 'dart:io';

import 'package:book_app/data/folders/folder_repository.dart';
import 'package:book_app/data/folders/folder_scan.dart';
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

/// Folders (ADR 0007): pick one, list its book files, copy some of them,
/// give the access back.
const pickFolderMethod = 'pickFolder';
const listFolderMethod = 'listFolder';
const copyFolderFilesMethod = 'copyFolderFiles';
const releaseFolderMethod = 'releaseFolder';

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

/// Platforms whose native side has the folder methods.
final _canPickFolders = Platform.isAndroid || Platform.isIOS;

Future<PickedFolder?> _pickFolder() async {
  final answer = await _channel.invokeMapMethod<String, String>(
    pickFolderMethod,
  );
  if (answer == null) return null;
  return (ref: answer['ref']!, name: answer['name'] ?? '');
}

/// Any failure means no access: the permission or the folder is gone.
Future<FolderListing> _listFolder(String ref) async {
  final Map<String, Object?>? answer;
  try {
    answer = await _channel.invokeMapMethod<String, Object?>(
      listFolderMethod,
      ref,
    );
  } on PlatformException {
    throw const FolderLostException();
  }
  final files = (answer?['files'] as List<Object?>?) ?? const [];
  return (
    files: [
      for (final file in files.cast<Map<Object?, Object?>>())
        FolderEntry(
          key: file['key']! as String,
          name: file['name'] as String?,
          size: (file['size'] as int?) ?? 0,
          modified: (file['modified'] as int?) ?? 0,
        ),
    ],
    ref: answer?['ref'] as String?,
  );
}

Future<List<String>> _copyFolderFiles(String ref, List<String> keys) async {
  final paths = await _channel.invokeListMethod<String>(copyFolderFilesMethod, {
    'ref': ref,
    'keys': keys,
  });
  return paths ?? const [];
}

Future<void> _releaseFolder(String ref) async {
  try {
    await _channel.invokeMethod<void>(releaseFolderMethod, ref);
  } on PlatformException {
    // The access is gone already.
  }
}

/// Null where the platform can't pick folders: "Подключить папку" is
/// hidden. Tests override it.
final pickFolderProvider = Provider<PickFolder?>(
  (ref) => _canPickFolders ? _pickFolder : null,
);

/// Null where picked folders can't be read: they aren't scanned.
final listFolderProvider = Provider<ListFolder?>(
  (ref) => _canPickFolders ? _listFolder : null,
);

final copyFolderFilesProvider = Provider<CopyFolderFiles>(
  (ref) => _copyFolderFiles,
);

final releaseFolderProvider = Provider<ReleaseFolder>(
  (ref) => _canPickFolders ? _releaseFolder : (_) async {},
);

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
