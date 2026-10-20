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

  /// Library shelf shown: `all`, `reading`, `finished` or `c:<collection id>`.
  static const libraryShelf = 'library.shelf';

  /// Library order, a `LibrarySort` name.
  static const librarySort = 'library.sort';

  /// Library look, a `LibraryLayout` name.
  static const libraryLayout = 'library.layout';
}
