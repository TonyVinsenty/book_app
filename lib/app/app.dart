import 'package:book_app/app/incoming_books.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Root widget: localization, theme, the first screen and books coming
/// from other apps.
class BookApp extends StatefulWidget {
  const BookApp({super.key, this.reopenBookId});

  /// The book to open on start, over the library ("back" leads there).
  final int? reopenBookId;

  @override
  State<BookApp> createState() => _BookAppState();
}

class _BookAppState extends State<BookApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  static Route<void> _libraryRoute() =>
      MaterialPageRoute<void>(builder: (_) => const LibraryScreen());

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      builder: (context, child) =>
          IncomingBooks(navigatorKey: _navigatorKey, child: child!),
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
        if (widget.reopenBookId case final id?)
          MaterialPageRoute<void>(
            builder: (_) => ReaderScreen(bookId: id, reopened: true),
          ),
      ],
    );
  }
}
