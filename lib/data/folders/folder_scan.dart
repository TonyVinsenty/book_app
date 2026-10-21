import 'dart:io';

import 'package:book_app/book/import/book_importer.dart' show fileNameOf;
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_repository.dart';

/// Books taken from one folder at most; the rest wait (ADR 0007).
const maxFolderBooks = 5000;

/// Bigger files are not imported, only remembered.
const maxFolderFileSize = 300 * 1024 * 1024;

/// Subfolder levels looked into below the folder itself.
const maxFolderDepth = 8;

/// What one scan does with a folder.
final class ScanPlan {
  const ScanPlan({
    required this.toImport,
    required this.tooLarge,
    required this.forgotten,
    required this.tooBig,
  });

  /// New or changed files, by key.
  final List<FolderEntry> toImport;

  /// New or changed files over [maxFolderFileSize]: remembered, not taken.
  final List<FolderEntry> tooLarge;

  /// Remembered files that are gone.
  final List<String> forgotten;

  /// More than [maxFolderBooks] files: only the first ones are looked at.
  final bool tooBig;
}

/// Compares a folder listing with the files seen before. A file is new or
/// changed when it is not known or its size or time differ; an unknown
/// time (0) compares by size only.
ScanPlan planScan(
  List<FolderEntry> entries,
  Map<String, FolderFileRow> known, {
  int maxFiles = maxFolderBooks,
  int maxSize = maxFolderFileSize,
}) {
  final sorted = [...entries]..sort((a, b) => a.key.compareTo(b.key));
  final keys = {for (final e in sorted) e.key};
  final toImport = <FolderEntry>[];
  final tooLarge = <FolderEntry>[];
  for (final e in sorted.take(maxFiles)) {
    final seen = known[e.key];
    final changed =
        seen == null ||
        seen.size != e.size ||
        (e.modified != 0 && seen.modified != 0 && seen.modified != e.modified);
    if (!changed) continue;
    (e.size > maxSize ? tooLarge : toImport).add(e);
  }
  return ScanPlan(
    toImport: toImport,
    tooLarge: tooLarge,
    forgotten: [
      for (final key in known.keys)
        if (!keys.contains(key)) key,
    ],
    tooBig: sorted.length > maxFiles,
  );
}

/// No access to the folder any more (permission gone, folder deleted).
final class FolderLostException implements Exception {
  const FolderLostException();
}

/// Where the books of a folder come from: the file system or the platform.
abstract interface class FolderSource {
  /// Book files of the folder, subfolders included. Throws
  /// [FolderLostException].
  Future<List<FolderEntry>> list();

  /// Copies the file [key] where the import queue may delete it; returns
  /// the copy's path.
  Future<String> copy(String key);
}

/// A folder listing from the platform; [ref] — a renewed handle (an iOS
/// bookmark gone stale), to keep instead of the old one.
typedef FolderListing = ({List<FolderEntry> files, String? ref});

/// Lists a picked folder; throws [FolderLostException].
typedef ListFolder = Future<FolderListing> Function(String ref);

/// Copies files of a picked folder where the import queue may delete them;
/// a file that couldn't be copied comes as a path with nothing there.
typedef CopyFolderFiles = Future<List<String>> Function(
  String ref,
  List<String> keys,
);

/// A folder the owner picked, read by the platform (Android: the storage
/// access framework; iOS: a bookmark).
final class ChannelFolderSource implements FolderSource {
  ChannelFolderSource(
    this._ref, {
    required this._list,
    required this._copy,
    required this.onRef,
  });

  String _ref;
  final ListFolder _list;
  final CopyFolderFiles _copy;

  /// Keeps a renewed handle.
  final Future<void> Function(String ref) onRef;

  @override
  Future<List<FolderEntry>> list() async {
    final listing = await _list(_ref);
    final renewed = listing.ref;
    if (renewed != null && renewed != _ref) {
      _ref = renewed;
      await onRef(renewed);
    }
    return listing.files;
  }

  @override
  Future<String> copy(String key) async => (await _copy(_ref, [key])).single;
}

/// Whether the file name looks like a book the importer takes; the format
/// itself is told by the content.
bool isBookFileName(String name) {
  final lower = name.toLowerCase();
  return const [
    '.fb2',
    '.epub',
    '.txt',
    '.zip',
  ].any((ext) => lower.endsWith(ext) && lower.length > ext.length);
}

/// A folder the app reads itself: the own folder (iOS `Documents`, Android
/// `files/Books`). Skips hidden files and folders (`.Trash`) and the iOS
/// `Inbox` of "Open in" copies.
final class LocalFolderSource implements FolderSource {
  LocalFolderSource(this.root, {required this.copies});

  final Directory root;

  /// Where copies for the queue go: one at a time, under their own names
  /// (the name is the title of a book without one).
  final Directory copies;

  @override
  Future<List<FolderEntry>> list() async {
    if (!root.existsSync()) return const [];
    final entries = <FolderEntry>[];
    Future<void> walk(Directory dir, String prefix, int depth) async {
      await for (final entity in dir.list(followLinks: false)) {
        final name = fileNameOf(entity.path);
        if (name.startsWith('.')) continue;
        if (entity is Directory) {
          if (depth == 0 && name == 'Inbox') continue;
          if (depth < maxFolderDepth) {
            await walk(entity, '$prefix$name/', depth + 1);
          }
        } else if (entity is File && isBookFileName(name)) {
          final stat = entity.statSync();
          entries.add(
            FolderEntry(
              key: '$prefix$name',
              size: stat.size,
              modified: stat.modified.millisecondsSinceEpoch,
            ),
          );
        }
      }
    }

    try {
      await walk(root, '', 0);
    } on FileSystemException {
      throw const FolderLostException();
    }
    return entries;
  }

  @override
  Future<String> copy(String key) async {
    await copies.create(recursive: true);
    final name = key.split('/').last;
    final copy = await File('${root.path}/$key').copy('${copies.path}/$name');
    return copy.path;
  }
}
