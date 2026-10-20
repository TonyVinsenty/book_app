import 'dart:io';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/data/book_opener.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/db/open_app_database.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/layout/hyphenation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:path_provider/path_provider.dart';

/// Opened storage; set once in `main()` (tests: memory database, temp dir).
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final contentStoreProvider = Provider<ContentStore>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(contentStoreProvider),
  ),
);

final bookImporterProvider = Provider<BookImporter>(
  (ref) => BookImporter(ref.watch(bookRepositoryProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

/// The library list, recently opened first.
final booksProvider = StreamProvider<List<BookRow>>(
  (ref) => ref.watch(bookRepositoryProvider).watchBooks(),
);

/// A book prepared for the reader screen, by book id. A failure is final
/// (missing or broken files), so Riverpod's automatic retry is off.
final openedBookProvider = FutureProvider.autoDispose.family<OpenedBook, int>(
  (ref, id) => BookOpener(ref.watch(bookRepositoryProvider)).open(id),
  retry: (_, _) => null,
);

/// Opens the database and the book files in the app support directory
/// (hidden from the user; on iOS it may not exist yet). Needs a running
/// Flutter engine (`path_provider`).
Future<List<Override>> openStorageOverrides() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  final db = await openAppDatabaseIn(dir);
  final store = ContentStore(
    Directory('${dir.path}${Platform.pathSeparator}books'),
  );
  return [
    appDatabaseProvider.overrideWithValue(db),
    contentStoreProvider.overrideWithValue(store),
  ];
}

/// Hyphenation patterns, loaded in `main()`; null (tests) — no hyphens.
final hyphenationProvider = Provider<Hyphenation?>((ref) => null);
