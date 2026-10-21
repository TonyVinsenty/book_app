import 'package:book_app/book/import/book_importer.dart' show fileNameOf;
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_repository.dart';
import 'package:book_app/data/folders/folder_scan.dart';
import 'package:book_app/data/import_queue.dart';

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
    // closed midway takes the rest next time.
    await Future.wait([
      for (final entry in plan.toImport)
        _queue
            .addLater(
              fileNameOf(entry.key),
              () => source.copy(entry.key),
              touch: false,
            )
            .then((_) => _folders.remember(folder.id, entry)),
    ]);
    await _folders.markScanned(folder.id, tooBig: plan.tooBig);
  }
}
