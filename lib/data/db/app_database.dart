import 'dart:convert';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/stats_records.dart';
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

  /// Last add, open or repeated import: the library is sorted by it, so a
  /// new book and a duplicate come on top (schema v2).
  DateTimeColumn get touchedAt => dateTime()();

  /// Name of the cover picture in the book folder (`cover.jpg`), or null
  /// (schema v2).
  TextColumn get coverFile => text().nullable()();

  /// When the book was read to the end or marked read; null — not read.
  /// Cleared only by hand ("reading again"), not by reading from the start
  /// (schema v3, ADR 0005 addendum 2).
  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// "Queued" or "abandoned" set by hand; null — neither. Never set together
  /// with [finishedAt] (schema v4, ADR 0005 addendum 3).
  TextColumn get statusMark => textEnum<StatusMark>().nullable()();
}

/// A status the owner sets by hand; the others follow from the dates.
enum StatusMark { queued, abandoned }

/// The owner's own collections of books. Names are unique without case —
/// checked in `CollectionRepository` (SQLite `NOCASE` knows only Latin).
@DataClassName('CollectionRow')
class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// A book in a collection; goes away with either of them (schema v3).
@DataClassName('BookCollectionRow')
class BookCollections extends Table {
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get collectionId =>
      integer().references(Collections, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {bookId, collectionId};
}

/// Folders the library takes books from (schema v5, ADR 0007): the app's own
/// folder and folders the owner picked.
@DataClassName('FolderRow')
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => textEnum<FolderKind>()();
  TextColumn get name => text()();

  /// Opaque handle from the platform (Android tree URI, iOS bookmark);
  /// null for the own folder.
  TextColumn get ref => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get scannedAt => dateTime().nullable()();

  /// No access any more: books stay, the owner can pick the folder again.
  BoolColumn get lost => boolean().withDefault(const Constant(false))();

  /// The last scan found more books than the limit and took only some.
  BoolColumn get tooBig => boolean().withDefault(const Constant(false))();

  /// Books from the folder also go to this collection; null — nowhere.
  IntColumn get collectionId => integer().nullable().references(
    Collections,
    #id,
    onDelete: KeyAction.setNull,
  )();
}

enum FolderKind { own, picked }

/// Files of a folder already seen, so a deleted book does not come back and
/// a rescan imports only new or changed files (schema v5).
@DataClassName('FolderFileRow')
class FolderFiles extends Table {
  IntColumn get folderId =>
      integer().references(Folders, #id, onDelete: KeyAction.cascade)();

  /// Path inside the folder (or Android document id).
  TextColumn get key => text()();
  IntColumn get size => integer()();

  /// Change time in milliseconds; 0 — unknown, compare by size only.
  IntColumn get modified => integer()();
  DateTimeColumn get seenAt => dateTime()();

  @override
  Set<Column> get primaryKey => {folderId, key};
}

/// Reading by day, book, mode and part of the day: sums only, no single
/// pages (schema v6, ADR 0009 п. 2).
@DataClassName('ReadingDayRow')
class ReadingDays extends Table {
  /// `yyyymmdd`, see `dayKey`.
  IntColumn get day => integer()();

  /// No foreign key: minutes of a deleted book stay in the totals.
  IntColumn get bookId => integer()();
  TextColumn get mode => textEnum<ReadingMode>()();

  /// See `dayPartOf`.
  IntColumn get dayPart => integer()();
  IntColumn get activeMs => integer()();
  IntColumn get words => integer()();

  /// Only for `page`: pages by speed bucket, sparse JSON `{"23":4}`.
  TextColumn get pageSpeedHist => text()
      .map(const BucketCountsConverter())
      .withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {day, bookId, mode, dayPart};
}

/// Speed reading by day, mode and set pace (schema v6, ADR 0009 п. 4).
@DataClassName('PaceDayRow')
class PaceDays extends Table {
  IntColumn get day => integer()();
  TextColumn get mode => textEnum<SpeedMode>()();
  IntColumn get wpm => integer()();
  IntColumn get words => integer()();
  IntColumn get activeMs => integer()();
  IntColumn get backs => integer()();
  IntColumn get pauses => integer()();

  @override
  Set<Column> get primaryKey => {day, mode, wpm};
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

/// Stores counts by bucket as a JSON object with number keys.
class BucketCountsConverter extends TypeConverter<Map<int, int>, String> {
  const BucketCountsConverter();

  @override
  Map<int, int> fromSql(String fromDb) => {
    for (final MapEntry(:key, :value)
        in (jsonDecode(fromDb) as Map<String, Object?>).entries)
      int.parse(key): value! as int,
  };

  @override
  String toSql(Map<int, int> value) => jsonEncode({
    for (final MapEntry(:key, :value) in value.entries) '$key': value,
  });
}

/// App database. The executor is a parameter: a file in the app, memory in
/// tests (`NativeDatabase.memory()`).
@DriftDatabase(
  tables: [
    Books,
    AppSettings,
    Collections,
    BookCollections,
    Folders,
    FolderFiles,
    ReadingDays,
    PaceDays,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // A rebuilt table: SQLite can't add a NOT NULL column without a
        // default. The rebuild forgets ids of deleted books; they must not
        // come back.
        final lastId = await lastBookId();
        await m.alterTable(
          TableMigration(
            books,
            // The rebuild makes the current table, so later columns too.
            newColumns: [
              books.touchedAt,
              books.coverFile,
              books.finishedAt,
              books.statusMark,
            ],
            columnTransformer: {
              books.touchedAt: coalesce([books.openedAt, books.addedAt]),
            },
          ),
        );
        if (lastId != null) await _keepLastBookId(lastId);
      } else {
        if (from < 3) await m.addColumn(books, books.finishedAt);
        if (from < 4) await m.addColumn(books, books.statusMark);
      }
      if (from < 3) {
        await m.createTable(collections);
        await m.createTable(bookCollections);
        // Read to 98% before the mark existed: count it as read then.
        await customStatement(
          'UPDATE books SET finished_at = touched_at '
          'WHERE word_count > 0 AND position_word * 100 >= word_count * 98',
        );
      }
      if (from < 5) {
        await m.createTable(folders);
        await m.createTable(folderFiles);
      }
      if (from < 6) {
        await m.createTable(readingDays);
        await m.createTable(paceDays);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// The AUTOINCREMENT counter of `books`: the biggest id ever given.
  Future<int?> lastBookId() async {
    final row = await customSelect(
      "SELECT seq FROM sqlite_sequence WHERE name = 'books'",
    ).getSingleOrNull();
    return row?.read<int>('seq');
  }

  Future<void> _keepLastBookId(int id) async {
    final current = await lastBookId();
    if (current == null) {
      await customStatement(
        "INSERT INTO sqlite_sequence (name, seq) VALUES ('books', ?)",
        [id],
      );
    } else if (current < id) {
      await customStatement(
        "UPDATE sqlite_sequence SET seq = ? WHERE name = 'books'",
        [id],
      );
    }
  }
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
