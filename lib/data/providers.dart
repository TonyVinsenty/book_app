import 'dart:io';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/data/book_opener.dart';
import 'package:book_app/data/book_pages.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/book_share.dart';
import 'package:book_app/data/collection_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/db/open_app_database.dart';
import 'package:book_app/data/folders/folder_repository.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/data/speed_settings.dart';
import 'package:book_app/data/stats_repository.dart';
import 'package:book_app/layout/hyphenation.dart';
import 'package:book_app/platform/share_channel.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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

final speedSettingsProvider = Provider<SpeedSettings>(
  (ref) => SpeedSettings(ref.watch(settingsRepositoryProvider)),
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

/// Reading statistics by day (ADR 0009).
final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.watch(appDatabaseProvider)),
);

/// Folders the library takes books from (ADR 0007).
final folderRepositoryProvider = Provider<FolderRepository>(
  (ref) => FolderRepository(ref.watch(appDatabaseProvider)),
);

/// The own folder first, then picked ones oldest first.
final foldersProvider = StreamProvider<List<FolderRow>>(
  (ref) => ref.watch(folderRepositoryProvider).watchFolders(),
);

/// A book prepared for the reader screen, by book id. A failure is final
/// (missing or broken files), so Riverpod's automatic retry is off.
final openedBookProvider = FutureProvider.autoDispose.family<OpenedBook, int>(
  (ref, id) => BookOpener(ref.watch(bookRepositoryProvider)).open(id),
  retry: (_, _) => null,
);

/// The book the reader was last closed on, for "К книге" in the library
/// (owner, 2026-10-21); null until a book is closed in this run.
final leftBookProvider = NotifierProvider<LeftBook, int?>(LeftBook.new);

class LeftBook extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? bookId) => state = bookId;
}

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
  final temp = await getTemporaryDirectory();
  return [
    appDatabaseProvider.overrideWithValue(db),
    contentStoreProvider.overrideWithValue(store),
    ownFolderProvider.overrideWithValue(await _ownFolder()),
    folderCopiesProvider.overrideWithValue(
      Directory('${temp.path}${Platform.pathSeparator}folder_scan'),
    ),
    // Android: the cache's `share/`, the only folder its FileProvider gives.
    shareCopiesProvider.overrideWithValue(
      Directory('${temp.path}${Platform.pathSeparator}share'),
    ),
  ];
}

/// iOS: `Documents`, shown in Files as "On My iPhone → BookApp" (with the
/// Info.plist keys, ADR 0007); Android: `files/Books` in the app's external
/// folder, reachable by cable from a computer and by `adb push`.
Future<Directory?> _ownFolder() async {
  if (Platform.isIOS) {
    final documents = await getApplicationDocumentsDirectory();
    await showInFiles(documents);
    return documents;
  }
  if (Platform.isAndroid) {
    final external = await getExternalStorageDirectory();
    if (external == null) return null;
    return Directory('${external.path}/Books').create(recursive: true);
  }
  return null;
}

/// The app's own folder of books; null where there is none (tests).
final ownFolderProvider = Provider<Directory?>((ref) => null);

/// Where folder files are copied for the import queue.
final folderCopiesProvider = Provider<Directory>(
  (ref) => Directory('${Directory.systemTemp.path}/folder_scan'),
);

/// Where a shared book is copied under its readable name.
final shareCopiesProvider = Provider<Directory>(
  (ref) => Directory('${Directory.systemTemp.path}/share'),
);

/// The system share sheet; tests override it to see the calls.
final shareFileProvider = Provider<ShareFile>((ref) => shareFile);

final bookSharerProvider = Provider<BookSharer>(
  (ref) => BookSharer(
    ref.watch(bookRepositoryProvider),
    ref.watch(shareCopiesProvider),
    ref.watch(shareFileProvider),
  ),
);

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

/// Files hides an app's folder while it is empty, so an empty one gets a
/// `Books` folder to put books in (the scan looks into subfolders).
@visibleForTesting
Future<void> showInFiles(Directory documents) async {
  try {
    final visible = documents.listSync().any(
      (entity) =>
          !entity.path.split(Platform.pathSeparator).last.startsWith('.'),
    );
    if (!visible) {
      await Directory('${documents.path}/Books').create(recursive: true);
    }
  } on FileSystemException {
    // The folder just stays hidden until a book is put in through "Open in".
  }
}
