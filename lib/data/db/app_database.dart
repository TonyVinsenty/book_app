import 'dart:convert';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Books of the library: only what is listed, sorted and changed (ADR 0002).
/// The text lives in files (`ContentStore`), the folder name is [id].
@DataClassName('BookRow')
class Books extends Table {
  /// AUTOINCREMENT: ids of deleted books are never reused, so a stale folder
  /// can't be mistaken for a new book.
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get authors => text().map(const StringListConverter())();
  TextColumn get series => text().nullable()();
  IntColumn get seriesNumber => integer().nullable()();
  TextColumn get lang => text().nullable()();
  TextColumn get annotation => text().nullable()();
  TextColumn get sourceFormat => textEnum<SourceFormat>()();

  /// Original file name, shown in errors and details.
  TextColumn get sourceName => text()();
  IntColumn get sourceSize => integer()();

  /// SHA-256 of the source file (hex): the duplicate check.
  TextColumn get sourceHash => text().unique()();

  /// Version of the parser that built the stored content; older → reparse.
  IntColumn get parserVersion => integer()();
  IntColumn get wordCount => integer()();

  /// Reading position: word index plus its anchor (ADR 0002).
  IntColumn get positionWord => integer().withDefault(const Constant(0))();
  IntColumn get positionSection => integer().withDefault(const Constant(0))();
  IntColumn get positionBlock => integer().withDefault(const Constant(0))();
  IntColumn get positionChar => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get openedAt => dateTime().nullable()();
}

/// App settings as key → value text; typed access lives in the settings
/// code that owns each key.
@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Stores a list of strings as a JSON array.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) => [
    for (final s in jsonDecode(fromDb) as List<Object?>) s! as String,
  ];

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// App database. The executor is a parameter: a file in the app, memory in
/// tests (`NativeDatabase.memory()`).
@DriftDatabase(tables: [Books, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

extension BookRowPosition on BookRow {
  ReadingPosition get position => ReadingPosition(
    wordIndex: positionWord,
    anchor: TextAnchor(
      sectionIndex: positionSection,
      blockIndex: positionBlock,
      charOffset: positionChar,
    ),
  );

  /// Share read, 0..1.
  double get progress =>
      wordCount == 0 ? 0 : (positionWord / wordCount).clamp(0, 1).toDouble();
}
