import 'dart:io';

import 'package:book_app/data/db/app_database.dart';
import 'package:drift/native.dart';

const appDatabaseFileName = 'library.sqlite';

/// Opens (creating if needed) the database file in [directory], which must
/// exist. The connection is opened here, not on the first screen query, and
/// queries run in a background isolate.
Future<AppDatabase> openAppDatabaseIn(Directory directory) async {
  if (!directory.existsSync()) {
    throw FileSystemException(
      'Database directory does not exist',
      directory.path,
    );
  }
  final file = File(
    '${directory.path}${Platform.pathSeparator}$appDatabaseFileName',
  );
  final database = AppDatabase(NativeDatabase.createInBackground(file));
  try {
    await database.customSelect('SELECT 1').get();
  } catch (_) {
    // Keep the original error even if closing fails too.
    try {
      await database.close();
    } catch (_) {}
    rethrow;
  }
  return database;
}
