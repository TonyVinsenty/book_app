import 'dart:io';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/data/book_opener.dart';
import 'package:book_app/data/book_pages.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/collection_repository.dart';
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

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => CollectionRepository(ref.watch(appDatabaseProvider)),
);

/// The owner's collections, oldest first.
final collectionsProvider = StreamProvider<List<CollectionRow>>(
  (ref) => ref.watch(collectionRepositoryProvider).watchCollections(),
);

/// Which book is in which collection.
final collectionLinksProvider = StreamProvider<List<BookCollectionRow>>(
  (ref) => ref.watch(collectionRepositoryProvider).watchLinks(),
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

/// The page the reader laid out last (`reader.lastLayout`), for the book
/// page.
final lastLayoutProvider = StreamProvider<LastLayout?>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.readerLastLayout)
      .map(LastLayout.decode),
);

/// Hyphenation patterns, loaded in `main()`; null (tests) — no hyphens.
final hyphenationProvider = Provider<Hyphenation?>((ref) => null);
