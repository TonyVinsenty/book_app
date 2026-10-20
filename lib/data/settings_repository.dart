import 'package:book_app/data/db/app_database.dart';
import 'package:drift/drift.dart';

/// Key → text settings (ADR 0001: one store, no `shared_preferences`).
final class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$AppSettingsTable, SettingRow> _byKey(String key) =>
      _db.select(_db.appSettings)..where((s) => s.key.equals(key));

  Future<String?> get(String key) async =>
      (await _byKey(key).getSingleOrNull())?.value;

  /// All values whose keys start with [prefix].
  Future<Map<String, String>> getAll(String prefix) async {
    final rows = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.like('$prefix%'))).get();
    return {for (final row in rows) row.key: row.value};
  }

  /// Current value, then each change of it (drift re-runs the query on any
  /// settings write, so repeats are dropped).
  Stream<String?> watch(String key) =>
      _byKey(key)
          .watch()
          .map((rows) => rows.isEmpty ? null : rows.single.value)
          .distinct();

  /// Current values of [keys] (missing ones left out), then each change of
  /// them.
  Stream<Map<String, String>> watchKeys(List<String> keys) =>
      (_db.select(_db.appSettings)..where((s) => s.key.isIn(keys)))
          .watch()
          .map((rows) => {for (final row in rows) row.key: row.value})
          .distinct(_sameMap);

  static bool _sameMap(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  /// Sets the values given and removes those given as null, all at once.
  Future<void> setAll(Map<String, String?> values) => _db.transaction(() async {
    for (final MapEntry(:key, :value) in values.entries) {
      await (value == null ? remove(key) : set(key, value));
    }
  });

  Future<void> set(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );

  Future<void> remove(String key) =>
      (_db.delete(_db.appSettings)..where((s) => s.key.equals(key))).go();
}

/// Keys of the settings store.
abstract final class SettingKeys {
  /// Speed reading pace, words per minute.
  static const speedWpm = 'speed.wpm';

  /// Before statuses (stage 9.10): the library shelf shown, `all`,
  /// `reading`, `finished` or `c:<collection id>`; read once into
  /// [libraryStatus] / [libraryCollection] and removed.
  static const libraryShelf = 'library.shelf';

  /// Library filter: a `BookStatus` name; none — any status.
  static const libraryStatus = 'library.status';

  /// Library filter: a collection id; none — all books.
  static const libraryCollection = 'library.collection';

  /// Library order, a `LibrarySort` name.
  static const librarySort = 'library.sort';

  /// Library look, a `LibraryLayout` name.
  static const libraryLayout = 'library.layout';

  /// The page the reader laid out last, a `LastLayout` (for the page count
  /// on the book page).
  static const readerLastLayout = 'reader.lastLayout';
}
