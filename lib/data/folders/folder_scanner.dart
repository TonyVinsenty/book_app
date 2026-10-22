import 'dart:io';

import 'package:book_app/book/import/book_importer.dart'
    show ImportAdded, ImportDuplicate, fileNameOf;
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_repository.dart';
import 'package:book_app/data/folders/folder_scan.dart';
import 'package:book_app/data/import_queue.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Takes new books from folders into the library (ADR 0007): quietly — no
/// book opens and a duplicate keeps its place in the list.
final class FolderScanner {
  FolderScanner(this._folders, this._queue);

  final FolderRepository _folders;
  final ImportQueue _queue;
  var _busy = false;
  Iterable<(FolderRow, FolderSource)>? _next;

  bool get busy => _busy;

  /// Scans [folders] one after another. While a scan is on, returns false
  /// and keeps [folders] to scan right after it (the latest call wins), so
  /// a folder connected meanwhile isn't missed.
  Future<bool> scanAll(Iterable<(FolderRow, FolderSource)> folders) async {
    if (_busy) {
      _next = folders;
      return false;
    }
    _busy = true;
    try {
      Iterable<(FolderRow, FolderSource)>? batch = folders;
      while (batch != null) {
        _next = null;
        for (final (folder, source) in batch) {
          try {
            await _scan(folder, source);
          } on Object catch (error, stack) {
            // A folder disconnected midway, an odd answer from the
            // platform: the other folders still go.
            FlutterError.reportError(
              FlutterErrorDetails(exception: error, stack: stack),
            );
          }
        }
        batch = _next;
      }
      return true;
    } finally {
      _busy = false;
    }
  }

  Future<void> _scan(FolderRow folder, FolderSource source) async {
    final List<FolderEntry> entries;
    try {
      entries = await source.list();
    } on FolderLostException {
      await _folders.markLost(folder.id);
      return;
    }
    final plan = planScan(entries, await _folders.knownFiles(folder.id));
    await _folders.forget(folder.id, plan.forgotten);
    for (final entry in plan.tooLarge) {
      await _folders.remember(folder.id, entry);
    }
    // Each file is remembered once it has a result, whatever it is: an app
    // closed midway takes the rest next time. Added books and duplicates
    // go to the folder's collection first, so that is redone too. A file
    // that couldn't be copied (access gone for a moment) isn't remembered:
    // it is tried again next time.
    await Future.wait([
      for (final entry in plan.toImport)
        () async {
          var copied = false;
          final results = await _queue.addLater(
            entry.name ?? fileNameOf(entry.key),
            () async {
              final path = await source.copy(entry.key);
              copied = File(path).existsSync();
              return path;
            },
            touch: false,
          );
          if (!copied) return;
          await _folders.collect(folder.id, [
            for (final result in results)
              if (result
                  case ImportAdded(:final book) || ImportDuplicate(:final book))
                book.id,
          ]);
          await _folders.remember(folder.id, entry);
        }(),
    ]);
    await _folders.markScanned(folder.id, tooBig: plan.tooBig);
  }
}

final folderScannerProvider = Provider<FolderScanner>(
  (ref) => FolderScanner(
    ref.watch(folderRepositoryProvider),
    ref.watch(importQueueProvider.notifier),
  ),
);

/// Scans all folders of the library; false while a scan is on (it is then
/// done again right after).
typedef ScanFolders = Future<bool> Function();

/// The own folder always; picked folders where the platform can list them
/// (Android and iOS), the ones with no access too: a scan that
/// works gives the access back. Tests override it.
final scanFoldersProvider = Provider<ScanFolders>(
  (ref) => () async {
    final scanner = ref.read(folderScannerProvider);
    final repo = ref.read(folderRepositoryProvider);
    final own = ref.read(ownFolderProvider);
    if (own != null) await repo.ensureOwn();
    final copies = ref.read(folderCopiesProvider);
    final list = ref.read(listFolderProvider);
    final copyFiles = ref.read(copyFolderFilesProvider);
    return scanner.scanAll([
      for (final folder in await repo.folders())
        if (folder.kind == FolderKind.own) ...[
          if (own != null) (folder, LocalFolderSource(own, copies: copies)),
        ] else if (folder.ref case final handle? when list != null)
          (
            folder,
            ChannelFolderSource(
              handle,
              list: list,
              copy: copyFiles,
              onRef: (renewed) => repo.setRef(folder.id, renewed),
            ),
          ),
    ]);
  },
);
