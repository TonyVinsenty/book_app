import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Root widget: localization, theme and the first screen.
class BookApp extends StatelessWidget {
  const BookApp({super.key, this.reopenBookId});

  /// The book to open on start, over the library ("back" leads there).
  final int? reopenBookId;

  static Route<void> _libraryRoute() =>
      MaterialPageRoute<void>(builder: (_) => const LibraryScreen());

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Until reading settings exist (stage 8): Paper, night follows the system.
      theme: buildAppTheme(ReadingPalette.paper, night: false),
      darkTheme: buildAppTheme(ReadingPalette.paper, night: true),
      // No named routes: screens are pushed directly. The library is the
      // root; on start the last book may already lie over it.
      onGenerateRoute: (_) => _libraryRoute(),
      onGenerateInitialRoutes: (_) => [
        _libraryRoute(),
        if (reopenBookId case final id?)
          MaterialPageRoute<void>(
            builder: (_) => ReaderScreen(bookId: id, reopened: true),
          ),
      ],
    );
  }
}
