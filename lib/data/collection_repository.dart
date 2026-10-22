import 'package:book_app/data/db/app_database.dart';
import 'package:drift/drift.dart';

/// Why a collection name was not taken.
enum CollectionNameError { empty, taken }

final class CollectionNameException implements Exception {
  const CollectionNameException(this.error);

  final CollectionNameError error;

  @override
  String toString() => 'CollectionNameException(${error.name})';
}

/// The owner's collections and the books in them (ADR 0005 addendum 2).
/// Deleting a book or a collection removes its links by itself (cascade).
final class CollectionRepository {
  CollectionRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// All collections, oldest first (the screen sorts them for show).
  Stream<List<CollectionRow>> watchCollections() => (_db.select(
    _db.collections,
  )..orderBy([(c) => OrderingTerm.asc(c.id)])).watch();

  /// Every book-in-collection link.
  Stream<List<BookCollectionRow>> watchLinks() =>
      _db.select(_db.bookCollections).watch();

  /// A new collection with [bookIds] in it, written at once; throws
  /// [CollectionNameException].
  Future<CollectionRow> create(String name, {Set<int> bookIds = const {}}) =>
      _db.transaction(() async {
        final clean = await checkName(name);
        final created = await _db
            .into(_db.collections)
            .insertReturning(
              CollectionsCompanion.insert(name: clean, createdAt: _now()),
            );
        await _putBooks(created.id, bookIds);
        return created;
      });

  /// The collection with this name (in any case), made if there is none;
  /// throws [CollectionNameException] for an empty name.
  Future<CollectionRow> named(String name) => _db.transaction(() async {
    final key = name.trim().toLowerCase();
    final all = await _db.select(_db.collections).get();
    return all.where((c) => c.name.toLowerCase() == key).firstOrNull ??
        await create(name);
  });

  /// Throws [CollectionNameException]; the same name in other case is fine.
  Future<void> rename(int id, String name) => _db.transaction(() async {
    final clean = await checkName(name, except: id);
    await (_db.update(_db.collections)..where((c) => c.id.equals(id))).write(
      CollectionsCompanion(name: Value(clean)),
    );
  });

  /// The books stay in the library.
  Future<void> delete(int id) =>
      (_db.delete(_db.collections)..where((c) => c.id.equals(id))).go();

  Future<void> addBook(int collectionId, int bookId) => _db
      .into(_db.bookCollections)
      .insert(
        BookCollectionsCompanion.insert(
          bookId: bookId,
          collectionId: collectionId,
          addedAt: _now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> removeBook(int collectionId, int bookId) =>
      (_db.delete(_db.bookCollections)..where(
            (l) =>
                l.collectionId.equals(collectionId) & l.bookId.equals(bookId),
          ))
          .go();

  /// Exactly [bookIds] in the collection ("Добавить книги" with checkmarks);
  /// books that stay keep the time they were added.
  Future<void> setBooks(int collectionId, Set<int> bookIds) => _db.transaction(
    () async {
      await (_db.delete(_db.bookCollections)..where(
            (l) =>
                l.collectionId.equals(collectionId) & l.bookId.isNotIn(bookIds),
          ))
          .go();
      await _putBooks(collectionId, bookIds);
    },
  );

  Future<void> _putBooks(int collectionId, Set<int> bookIds) async {
    for (final id in bookIds) {
      await addBook(collectionId, id);
    }
  }

  /// The trimmed name, or throws [CollectionNameException]; [except] is the
  /// collection being renamed.
  Future<String> checkName(String name, {int? except}) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const CollectionNameException(CollectionNameError.empty);
    }
    final key = clean.toLowerCase();
    final all = await _db.select(_db.collections).get();
    if (all.any((c) => c.id != except && c.name.toLowerCase() == key)) {
      throw const CollectionNameException(CollectionNameError.taken);
    }
    return clean;
  }
}
