import 'package:book_app/book/import/book_importer.dart'
    show ImportAdded, ImportDuplicate, fileNameOf;
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_repository.dart';
import 'package:book_app/data/folders/folder_scan.dart';
import 'package:book_app/data/import_queue.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Takes new books from folders into the library (ADR 0007): quietly — no
/// book opens and a duplicate keeps its place in the list.
final class FolderScanner {
  FolderScanner(this._folders, this._queue);

  final FolderRepository _folders;
  final ImportQueue _queue;
  var _busy = false;

  bool get busy => _busy;

  /// Scans [folders] one after another; false, doing nothing, while a scan
  /// is still on.
  Future<bool> scanAll(Iterable<(FolderRow, FolderSource)> folders) async {
    if (_busy) return false;
    _busy = true;
    try {
      for (final (folder, source) in folders) {
        await _scan(folder, source);
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
    // go to the folder's collection first, so that is redone too.
    await Future.wait([
      for (final entry in plan.toImport)
        _queue
            .addLater(
              entry.name ?? fileNameOf(entry.key),
              () => source.copy(entry.key),
              touch: false,
            )
            .then((results) async {
              await _folders.collect(folder.id, [
                for (final result in results)
                  if (result
                      case ImportAdded(:final book) ||
                          ImportDuplicate(:final book))
                    book.id,
              ]);
              await _folders.remember(folder.id, entry);
            }),
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

/// Scans all folders of the library; false while a scan is on.
typedef ScanFolders = Future<bool> Function();

/// The own folder always; picked folders where the platform can list them
/// (Android and iOS), the ones with no access too: a scan that
/// works gives the access back. Tests override it.
final scanFoldersProvider = Provider<ScanFolders>(
  (ref) => () async {
    final scanner = ref.read(folderScannerProvider);
    if (scanner.busy) return false;
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
