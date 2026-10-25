import 'dart:async';

import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

/// The long-press menu of the app icon (17.7): "Библиотека", then up to
/// [maxBooks] books being read, the last opened first.
const maxBooks = 2;

const libraryShortcut = 'library';
const _bookPrefix = 'book:';

/// The system side of the menu; a stand-in in tests.
final quickActionsProvider = Provider<QuickActions>(
  (_) => const QuickActions(),
);

/// The books of the menu: being read, the last opened first.
List<BookRow> shortcutBooks(Iterable<BookRow> books) {
  final reading = books.where((b) => statusOf(b) == BookStatus.reading).toList()
    ..sort((a, b) => b.openedAt!.compareTo(a.openedAt!));
  return reading.take(maxBooks).toList();
}

/// The menu items: the library, then [shortcutBooks] of [books].
List<ShortcutItem> shortcutItems(
  AppLocalizations l10n,
  Iterable<BookRow> books,
) => [
  ShortcutItem(
    type: libraryShortcut,
    localizedTitle: l10n.shortcutLibrary,
    icon: 'shortcut_library',
  ),
  for (final book in shortcutBooks(books))
    ShortcutItem(
      type: '$_bookPrefix${book.id}',
      localizedTitle: book.title,
      icon: 'shortcut_book',
    ),
];

/// Keeps the menu up to date and opens what is picked in it: the library
/// (the screens over it close) or a book over the library.
class AppShortcuts extends ConsumerStatefulWidget {
  const AppShortcuts({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<AppShortcuts> createState() => _AppShortcutsState();
}

class _AppShortcutsState extends ConsumerState<AppShortcuts> {
  /// The items last given to the system, by type and title.
  String? _shown;

  @override
  void initState() {
    super.initState();
    unawaited(_quiet(ref.read(quickActionsProvider).initialize(_picked)));
  }

  /// No menu is no reason to stop the app (tests have no system side).
  static Future<void> _quiet(Future<void> call) =>
      call.catchError((Object _) {});

  void _picked(String type) {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    if (type == libraryShortcut) {
      navigator.popUntil((route) => route.isFirst);
      ref.read(showBooksProvider.notifier).request();
    } else if (int.tryParse(type.replaceFirst(_bookPrefix, '')) case final id?
        when type.startsWith(_bookPrefix)) {
      unawaited(
        navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => ReaderScreen(bookId: id)),
          (route) => route.isFirst,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider).value;
    if (books != null) {
      final items = shortcutItems(AppLocalizations.of(context), books);
      final shown = [for (final i in items) '${i.type}\n${i.localizedTitle}']
          .join('\n');
      if (shown != _shown) {
        _shown = shown;
        unawaited(
          _quiet(ref.read(quickActionsProvider).setShortcutItems(items)),
        );
      }
    }
    return widget.child;
  }
}
