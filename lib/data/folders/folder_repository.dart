import 'package:book_app/data/db/app_database.dart';
import 'package:drift/drift.dart';

/// A file of a folder as the scan sees it.
final class FolderEntry {
  const FolderEntry({
    required this.key,
    required this.size,
    required this.modified,
    this.name,
  });

  final String key;
  final int size;

  /// The file's own name when the key isn't a path (Android document ids).
  final String? name;

  /// Milliseconds; 0 — unknown.
  final int modified;
}

/// The own folder can't be disconnected.
final class OwnFolderException implements Exception {
  const OwnFolderException();
}

/// Folders and the files already seen in them (ADR 0007).
final class FolderRepository {
  FolderRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// All folders: the own one first ('own' < 'picked'), then picked ones
  /// oldest first.
  Stream<List<FolderRow>> watchFolders() => _ordered().watch();

  Future<List<FolderRow>> folders() => _ordered().get();

  SimpleSelectStatement<$FoldersTable, FolderRow> _ordered() => _db.select(
    _db.folders,
  )..orderBy([(f) => OrderingTerm.asc(f.kind), (f) => OrderingTerm.asc(f.id)]);

  /// The own folder's row, made on first call.
  Future<FolderRow> ensureOwn() => _db.transaction(() async {
    final own = await (_db.select(
      _db.folders,
    )..where((f) => f.kind.equalsValue(FolderKind.own))).getSingleOrNull();
    if (own != null) return own;
    return _db
        .into(_db.folders)
        .insertReturning(
          FoldersCompanion.insert(
            kind: FolderKind.own,
            name: '',
            addedAt: _now(),
          ),
        );
  });

  /// A folder the owner picked; [collectionId] — where its books also go.
  Future<FolderRow> addPicked({
    required String ref,
    required String name,
    int? collectionId,
  }) => _db
      .into(_db.folders)
      .insertReturning(
        FoldersCompanion.insert(
          kind: FolderKind.picked,
          name: name,
          ref: Value(ref),
          addedAt: _now(),
          collectionId: Value(collectionId),
        ),
      );

  /// A new handle for the folder (picked again or a renewed bookmark); the
  /// access is back, the seen files are kept.
  Future<void> setRef(int id, String ref) =>
      (_db.update(_db.folders)..where((f) => f.id.equals(id))).write(
        FoldersCompanion(ref: Value(ref), lost: const Value(false)),
      );

  Future<void> markLost(int id) =>
      (_db.update(_db.folders)..where((f) => f.id.equals(id))).write(
        const FoldersCompanion(lost: Value(true)),
      );

  Future<void> setCollection(int id, int? collectionId) =>
      (_db.update(_db.folders)..where((f) => f.id.equals(id))).write(
        FoldersCompanion(collectionId: Value(collectionId)),
      );

  /// Puts books from the folder into its collection, if it still has one
  /// (deleting the collection unsets it); books deleted meanwhile are left
  /// out.
  Future<void> collect(int folderId, Iterable<int> bookIds) =>
      _db.transaction(() async {
        final folder = await (_db.select(
          _db.folders,
        )..where((f) => f.id.equals(folderId))).getSingleOrNull();
        final collectionId = folder?.collectionId;
        if (collectionId == null || bookIds.isEmpty) return;
        final books = await (_db.select(
          _db.books,
        )..where((b) => b.id.isIn(bookIds))).get();
        for (final book in books) {
          await _db
              .into(_db.bookCollections)
              .insert(
                BookCollectionsCompanion.insert(
                  bookId: book.id,
                  collectionId: collectionId,
                  addedAt: _now(),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      });

  /// After a scan: when, and whether the limit cut it short; the access is
  /// there again.
  Future<void> markScanned(int id, {bool tooBig = false}) =>
      (_db.update(_db.folders)..where((f) => f.id.equals(id))).write(
        FoldersCompanion(
          scannedAt: Value(_now()),
          tooBig: Value(tooBig),
          lost: const Value(false),
        ),
      );

  /// Disconnects a picked folder; its books stay, the seen files go
  /// (cascade). Throws [OwnFolderException] for the own folder.
  Future<void> remove(int id) => _db.transaction(() async {
    final row = await (_db.select(
      _db.folders,
    )..where((f) => f.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    if (row.kind == FolderKind.own) throw const OwnFolderException();
    await (_db.delete(_db.folders)..where((f) => f.id.equals(id))).go();
  });

  /// Files seen in the folder, by key.
  Future<Map<String, FolderFileRow>> knownFiles(int folderId) async {
    final rows = await (_db.select(
      _db.folderFiles,
    )..where((f) => f.folderId.equals(folderId))).get();
    return {for (final r in rows) r.key: r};
  }

  /// The file has had its import result: don't take it again unless it
  /// changes.
  Future<void> remember(int folderId, FolderEntry entry) => _db
      .into(_db.folderFiles)
      .insertOnConflictUpdate(
        FolderFilesCompanion.insert(
          folderId: folderId,
          key: entry.key,
          size: entry.size,
          modified: entry.modified,
          seenAt: _now(),
        ),
      );

  /// Files gone from the folder: if they come back, they are imported again.
  Future<void> forget(int folderId, Iterable<String> keys) async {
    final list = keys.toList();
    if (list.isEmpty) return;
    await (_db.delete(
      _db.folderFiles,
    )..where((f) => f.folderId.equals(folderId) & f.key.isIn(list))).go();
  }
}
