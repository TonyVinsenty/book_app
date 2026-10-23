import 'package:book_app/app/app_locale.dart';
import 'package:book_app/app/folder_scans.dart';
import 'package:book_app/app/incoming_books.dart';
import 'package:book_app/app/launch_splash.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget: localization, theme, the first screen and books coming
/// from other apps and folders.
class BookApp extends ConsumerStatefulWidget {
  const BookApp({super.key, this.reopenBookId, this.splash = false});

  /// The book to open on start, over the library ("back" leads there).
  final int? reopenBookId;

  /// Shows the launch animation ([LaunchSplash]); off in tests.
  final bool splash;

  @override
  ConsumerState<BookApp> createState() => _BookAppState();
}

class _BookAppState extends ConsumerState<BookApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  static Route<void> _libraryRoute() =>
      MaterialPageRoute<void>(builder: (_) => const LibraryScreen());

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readingSettingsProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      builder: (context, child) {
        final app = FolderScans(
          child: IncomingBooks(navigatorKey: _navigatorKey, child: child!),
        );
        return widget.splash ? LaunchSplash(child: app) : app;
      },
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: settings.language.locale,
      localeListResolutionCallback: resolveAppLocale,
      // The whole app takes the reading palette (ADR 0003, addendum 2).
      theme: buildAppTheme(settings.palette, night: false),
      darkTheme: buildAppTheme(settings.palette, night: true),
      themeMode: switch (settings.night) {
        NightMode.system => ThemeMode.system,
        NightMode.day => ThemeMode.light,
        NightMode.night => ThemeMode.dark,
      },
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
