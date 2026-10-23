import 'dart:async';

import 'package:book_app/app/app.dart';
import 'package:book_app/app/font_licenses.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/layout/hyphenation.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final (storage, hyphenation) = await (
    openStorageOverrides(),
    Hyphenation.load(),
  ).wait;
  final container = ProviderContainer(
    overrides: [...storage, hyphenationProvider.overrideWithValue(hyphenation)],
  );
  // Listen before asking, so files that come meanwhile wait in the stream.
  container.read(incomingFilesProvider);
  final incoming = await container.read(hasInitialFilesProvider)();
  // One small query, so the reader is the first screen (no library flash).
  // Started with a file, the app opens that file instead (ADR 0005).
  final last = incoming
      ? null
      : await container.read(bookRepositoryProvider).lastOpened();
  // Before the first frame, so the first screen has the right colors.
  await container.read(readingSettingsProvider.notifier).restore();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: BookApp(reopenBookId: last?.id, splash: true),
    ),
  );
  unawaited(container.read(bookRepositoryProvider).removeLostFiles());
}
