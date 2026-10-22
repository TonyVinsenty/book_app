import 'dart:async';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/features/library/book_page.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/library/folders_screen.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The books of [view] as one sliver: a list or a grid, under author headers
/// when sorted by author (mockup `docs/design/library-v2.html`).
class BookShelf extends ConsumerWidget {
  const BookShelf({
    super.key,
    required this.view,
    this.onLongPress,
    this.picked,
    this.onPick,
  });

  final LibraryView view;

  /// Opens the book menu.
  final ValueChanged<BookRow>? onLongPress;

  /// Not null while books are checked for a collection: a tap calls [onPick]
  /// instead of opening the book page.
  final Set<int>? picked;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final titleFont = ref.watch(
      readingSettingsProvider.select((s) => s.font.family),
    );
    return SliverMainAxisGroup(
      slivers: [
        for (final group in view.groups) ...[
          if (group.hasHeader)
            SliverToBoxAdapter(
              child: _GroupHeader(
                title: group.author ?? l10n.libraryNoAuthor,
                count: group.books.length,
                titleFont: titleFont,
              ),
            ),
          switch (view.layout) {
            LibraryLayout.list => _BookList(
              books: group.books,
              shelf: this,
              titleFont: titleFont,
            ),
            LibraryLayout.grid => _BookGrid(
              books: group.books,
              shelf: this,
              titleFont: titleFont,
            ),
          },
        ],
      ],
    );
  }
}

/// What a tap and a long press on [book] do on [shelf].
extension on BookShelf {
  VoidCallback tapOf(BuildContext context, BookRow book) => picked == null
      ? () => openBookPage(context, book.id)
      : () => onPick?.call(book.id);

  VoidCallback? longPressOf(BookRow book) =>
      picked == null && onLongPress != null ? () => onLongPress!(book) : null;
}

class _BookList extends ConsumerWidget {
  const _BookList({
    required this.books,
    required this.shelf,
    required this.titleFont,
  });

  final List<BookRow> books;
  final BookShelf shelf;
  final String titleFont;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(bookRepositoryProvider);
    return SliverList.builder(
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        return BookTile(
          key: ValueKey(book.id),
          onTap: shelf.tapOf(context, book),
          onLongPress: shelf.longPressOf(book),
          coverFile: repository.coverFile(book),
          title: book.title,
          authors: book.authors.join(', '),
          mark: ReadMark.of(book),
          titleFont: titleFont,
          picked: shelf.picked?.contains(book.id),
        );
      },
    );
  }
}

/// Covers three in a row; tiles grow with the system text size.
class _BookGrid extends ConsumerWidget {
  const _BookGrid({
    required this.books,
    required this.shelf,
    required this.titleFont,
  });

  static const _columns = 3;
  static const _side = 16.0;
  static const _gapX = 14.0;
  static const _gapY = 18.0;

  final List<BookRow> books;
  final BookShelf shelf;
  final String titleFont;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(bookRepositoryProvider);
    final scaler = MediaQuery.textScalerOf(context);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(_side, 6, _side, 8),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width =
              (constraints.crossAxisExtent - _gapX * (_columns - 1)) / _columns;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              crossAxisSpacing: _gapX,
              mainAxisSpacing: _gapY,
              mainAxisExtent: BookGridTile.heightFor(width, scaler),
            ),
            itemCount: books.length,
            itemBuilder: (context, i) {
              final book = books[i];
              return BookGridTile(
                key: ValueKey(book.id),
                onTap: shelf.tapOf(context, book),
                onLongPress: shelf.longPressOf(book),
                coverFile: repository.coverFile(book),
                title: book.title,
                authors: book.authors.join(', '),
                mark: ReadMark.of(book),
                titleFont: titleFont,
                picked: shelf.picked?.contains(book.id),
              );
            },
          );
        },
      ),
    );
  }
}

/// "Толстой Л. Н." and the number of books, over a line.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.count,
    required this.titleFont,
  });

  final String title;
  final int count;
  final String titleFont;

  @override
  Widget build(BuildContext context) {
    final colors = context.readingColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colors.text.withValues(alpha: 0.14),
              width: 1.5,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: titleFont,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Все · 11" (opens the statuses), then the list/grid and order buttons.
class ShelfBar extends ConsumerWidget {
  const ShelfBar({super.key, required this.view, required this.onStatus});

  final LibraryView view;

  /// A status chosen in the sheet; null — all books.
  final ValueChanged<BookStatus?> onStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final grid = view.layout == LibraryLayout.grid;
    final status = view.filter.status;
    final on = status != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Material(
                color: on ? colors.surface : Colors.transparent,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: on
                        ? colors.accent
                        : colors.text.withValues(alpha: 0.14),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => unawaited(_chooseStatus(context)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              l10n.libraryFilterButton(
                                statusFilterName(l10n, status),
                                view.books.length,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: on ? colors.accent : colors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more,
                            size: 20,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.folders,
            color: colors.textSecondary,
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => openFolders(context),
          ),
          IconButton(
            tooltip: grid ? l10n.libraryShowList : l10n.libraryShowGrid,
            color: colors.textSecondary,
            icon: Icon(grid ? Icons.view_list_outlined : Icons.grid_view),
            onPressed: () => unawaited(
              chooseLayout(
                ref.read(settingsRepositoryProvider),
                grid ? LibraryLayout.list : LibraryLayout.grid,
              ),
            ),
          ),
          IconButton(
            tooltip: '${l10n.librarySort}: ${sortName(l10n, view.sort)}',
            color: colors.textSecondary,
            icon: const Icon(Icons.sort),
            onPressed: () => unawaited(_chooseSort(context, ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseStatus(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final options = <BookStatus?>[null, ...BookStatus.values];
    final total = view.statusCounts.values.fold(0, (a, b) => a + b);
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => _Sheet(
        title: l10n.libraryStatusFilter,
        child: RadioGroup<int>(
          groupValue: options.indexOf(view.filter.status),
          onChanged: (i) => Navigator.of(context).pop(i),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, status) in options.indexed)
                RadioListTile<int>(
                  value: i,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Row(
                    children: [
                      Expanded(child: Text(statusFilterName(l10n, status))),
                      Text(
                        '${status == null ? total : view.statusCounts[status] ?? 0}',
                        style: TextStyle(
                          color: context.readingColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || options[chosen] == view.filter.status) return;
    onStatus(options[chosen]);
  }

  Future<void> _chooseSort(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<LibrarySort>(
      context: context,
      showDragHandle: true,
      builder: (context) => _Sheet(
        title: l10n.librarySort,
        child: RadioGroup<LibrarySort>(
          groupValue: view.sort,
          onChanged: (sort) => Navigator.of(context).pop(sort),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final sort in LibrarySort.values)
                RadioListTile<LibrarySort>(
                  value: sort,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(sortName(l10n, sort)),
                  subtitle: sort == LibrarySort.author
                      ? Text(l10n.librarySortAuthorHint)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || chosen == view.sort) return;
    await chooseSort(ref.read(settingsRepositoryProvider), chosen);
  }
}

/// A bottom sheet with a title; scrolls on a low screen (landscape, large
/// text).
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          child,
        ],
      ),
    ),
  );
}

/// "Все", "Новые", "Читаю", "На очереди", "Брошены", "Прочитано".
String statusFilterName(AppLocalizations l10n, BookStatus? status) =>
    switch (status) {
      null => l10n.libraryShelfAll,
      BookStatus.notStarted => l10n.libraryShelfNew,
      BookStatus.reading => l10n.libraryShelfReading,
      BookStatus.queued => l10n.libraryShelfQueued,
      BookStatus.abandoned => l10n.libraryShelfAbandoned,
      BookStatus.finished => l10n.libraryShelfFinished,
    };

String sortName(AppLocalizations l10n, LibrarySort sort) => switch (sort) {
  LibrarySort.recent => l10n.librarySortRecent,
  LibrarySort.added => l10n.librarySortAdded,
  LibrarySort.title => l10n.librarySortTitle,
  LibrarySort.author => l10n.librarySortAuthor,
  LibrarySort.progress => l10n.librarySortProgress,
};

/// No books of the chosen status (or in the collection).
class EmptyShelf extends StatelessWidget {
  const EmptyShelf({super.key, required this.status});

  final BookStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, title, hint) = switch (status) {
      BookStatus.notStarted => (
        Icons.menu_book_outlined,
        l10n.libraryNewEmpty,
        l10n.libraryNewEmptyHint,
      ),
      BookStatus.reading => (
        Icons.menu_book_outlined,
        l10n.libraryReadingEmpty,
        l10n.libraryReadingEmptyHint,
      ),
      BookStatus.queued => (
        Icons.schedule,
        l10n.libraryQueuedEmpty,
        l10n.libraryQueuedEmptyHint,
      ),
      BookStatus.abandoned => (
        Icons.pause_circle_outline,
        l10n.libraryAbandonedEmpty,
        l10n.libraryAbandonedEmptyHint,
      ),
      BookStatus.finished => (
        Icons.check_circle_outline,
        l10n.libraryFinishedEmpty,
        l10n.libraryFinishedEmptyHint,
      ),
      // "Все" is empty only in an empty collection: the empty library is
      // shown on its own.
      null => (
        Icons.collections_bookmark_outlined,
        l10n.libraryCollectionEmpty,
        l10n.libraryCollectionEmptyHint,
      ),
    };
    return EmptyMessage(icon: icon, title: title, hint: hint);
  }
}

/// A large icon, a title and a hint in the middle; an optional button.
class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    this.icon = Icons.menu_book_outlined,
    required this.title,
    required this.hint,
    this.action,
  });

  final IconData icon;
  final String title;
  final String hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.readingColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 32, 36, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colors.accent),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action case final action?) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

void openBook(BuildContext context, int bookId) => unawaited(
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => ReaderScreen(bookId: bookId))),
);
