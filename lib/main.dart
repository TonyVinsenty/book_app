import 'package:book_app/app/app.dart';
import 'package:book_app/app/font_licenses.dart';
import 'package:book_app/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final container = ProviderContainer(overrides: await openStorageOverrides());
  // One small query, so the reader is the first screen (no library flash).
  final last = await container.read(bookRepositoryProvider).lastOpened();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: BookApp(reopenBookId: last?.id),
    ),
  );
}
