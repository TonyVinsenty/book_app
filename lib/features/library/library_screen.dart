import 'dart:async';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/import_queue.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shelves of books as a list or a grid, "Продолжить" and the "Add book"
/// button (stage 9, mockup `docs/design/library.html`).
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  Future<void> _addBooks() async {
    final List<String> paths;
    try {
      paths = await ref.read(pickBooksProvider)();
    } on PlatformException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.importPickFailed)));
      return;
    }
    if (!mounted) return;
    // The summary comes when the queue empties (see build).
    unawaited(ref.read(importQueueProvider.notifier).add(paths));
  }

  void _showSummary(List<ImportResult> results) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_summary(l10n, results)),
        action: results.length < 2
            ? null
            : SnackBarAction(
                label: l10n.importDetails,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _ImportDetails(results: results),
                ),
              ),
      ),
    );
  }

  static String _summary(AppLocalizations l10n, List<ImportResult> results) {
    if (results.length == 1) {
      return switch (results.single) {
        ImportAdded(:final book) => l10n.importAdded(book.title),
        ImportDuplicate(:final book) => l10n.importDuplicate(book.title),
        ImportFailed(:final fileName, :final error) => switch (error) {
          ImportError.unsupportedFormat => l10n.importUnsupported(fileName),
          ImportError.damaged => l10n.importDamaged(fileName),
          ImportError.drm => l10n.importDrm(fileName),
          ImportError.unreadable => l10n.importUnreadable(fileName),
        },
      };
    }
    final added = results.whereType<ImportAdded>().length;
    final duplicates = results.whereType<ImportDuplicate>().length;
    final failed = results.whereType<ImportFailed>().length;
    return [
      l10n.importSummaryAdded(added),
      if (duplicates > 0) l10n.importSummaryDuplicates(duplicates),
      if (failed > 0) l10n.importSummaryFailed(failed),
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(libraryViewProvider);
    final queue = ref.watch(importQueueProvider);
    ref.listen(importQueueProvider, (previous, next) {
      final finished = next.finished;
      if (finished != null && previous?.finished == null) {
        _showSummary(finished);
      }
    });
    return Scaffold(
      // No app bar: the name is not needed here (owner, 2026-10-20).
      body: SafeArea(
        bottom: false,
        child: switch (view) {
          AsyncData(value: final view) when view.libraryIsEmpty => Column(
            children: [
              if (queue.busy) _ImportProgress(queue: queue),
              const Expanded(child: _EmptyLibrary()),
            ],
          ),
          AsyncData(value: final view) => _Library(view: view, queue: queue),
          _ => const SizedBox.shrink(),
        },
      ),
      // The picker replaces its previous copies, so it waits for the queue.
      floatingActionButton: queue.busy
          ? null
          : FloatingActionButton.extended(
              // It hides and comes back with the queue; two of them in one
              // page transition would clash as heroes.
              heroTag: null,
              onPressed: _addBooks,
              icon: const Icon(Icons.add),
              label: Text(l10n.addBook),
            ),
    );
  }
}

/// "Продолжить", shelves, the count with the look and order buttons, then
/// the books of the shelf; all of it scrolls together.
class _Library extends ConsumerWidget {
  const _Library({required this.view, required this.queue});

  final LibraryView view;
  final ImportQueueState queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(bookRepositoryProvider);
    final titleFont = ref.watch(
      readingSettingsProvider.select((s) => s.font.family),
    );
    final last = view.continueBook;
    return CustomScrollView(
      slivers: [
        if (last != null)
          SliverToBoxAdapter(
            child: ContinueCard(
              onTap: () => _openBook(context, last.id),
              coverFile: repository.coverFile(last),
              title: last.title,
              authors: last.authors.join(', '),
              mark: _markOf(last),
              titleFont: titleFont,
            ),
          ),
        SliverToBoxAdapter(child: _Shelves(view: view)),
        SliverToBoxAdapter(child: _ShelfHeader(view: view)),
        if (queue.busy)
          SliverToBoxAdapter(child: _ImportProgress(queue: queue)),
        if (view.books.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyShelf(shelf: view.shelf),
          )
        else ...[
          switch (view.layout) {
            LibraryLayout.list => SliverList.builder(
              itemCount: view.books.length,
              itemBuilder: (context, i) {
                final book = view.books[i];
                return BookTile(
                  key: ValueKey(book.id),
                  onTap: () => _openBook(context, book.id),
                  coverFile: repository.coverFile(book),
                  title: book.title,
                  authors: book.authors.join(', '),
                  mark: _markOf(book),
                  titleFont: titleFont,
                );
              },
            ),
            LibraryLayout.grid => _BookGrid(
              books: view.books,
              titleFont: titleFont,
            ),
          },
          // Room for the button over the last book.
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ],
    );
  }
}

ReadMark _markOf(BookRow book) =>
    ReadMark(percent: percentRead(book), finished: book.finishedAt != null);

/// Covers three in a row; tiles grow with the system text size.
class _BookGrid extends ConsumerWidget {
  const _BookGrid({required this.books, required this.titleFont});

  static const _columns = 3;
  static const _side = 16.0;
  static const _gapX = 14.0;
  static const _gapY = 18.0;

  final List<BookRow> books;
  final String titleFont;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(bookRepositoryProvider);
    final scaler = MediaQuery.textScalerOf(context);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(_side, 6, _side, 0),
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
                onTap: () => _openBook(context, book.id),
                coverFile: repository.coverFile(book),
                title: book.title,
                authors: book.authors.join(', '),
                mark: _markOf(book),
                titleFont: titleFont,
              );
            },
          );
        },
      ),
    );
  }
}

/// "Все · Читаю · Прочитано · collections", one tap to switch.
class _Shelves extends ConsumerWidget {
  const _Shelves({required this.view});

  final LibraryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final shelves = [
      (Shelf.all, l10n.libraryShelfAll),
      (Shelf.reading, l10n.libraryShelfReading),
      (Shelf.finished, l10n.libraryShelfFinished),
      for (final c in view.collections) (Shelf.collection(c.id), c.name),
    ];
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        itemCount: shelves.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (shelf, name) = shelves[i];
          final selected = shelf == view.shelf;
          return ChoiceChip(
            label: Text(name),
            selected: selected,
            showCheckmark: false,
            shape: const StadiumBorder(),
            side: BorderSide(
              color: selected
                  ? colors.accent
                  : colors.text.withValues(alpha: 0.14),
              width: 1.5,
            ),
            color: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.accent
                  : colors.background,
            ),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? colors.background : colors.text,
            ),
            onSelected: (_) => unawaited(
              chooseShelf(ref.read(settingsRepositoryProvider), shelf),
            ),
          );
        },
      ),
    );
  }
}

/// "12 книг", the list/grid button and the order button.
class _ShelfHeader extends ConsumerWidget {
  const _ShelfHeader({required this.view});

  final LibraryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.readingColors;
    final grid = view.layout == LibraryLayout.grid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.libraryBookCount(view.books.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
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
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
            icon: const Icon(Icons.sort, size: 20),
            label: Text(_sortName(l10n, view.sort)),
            onPressed: () => unawaited(_chooseSort(context, ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseSort(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<LibrarySort>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<LibrarySort>(
          groupValue: view.sort,
          onChanged: (sort) => Navigator.of(context).pop(sort),
          // Scrolls on a low screen (landscape, large text).
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    l10n.librarySort,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final sort in LibrarySort.values)
                  RadioListTile<LibrarySort>(
                    value: sort,
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text(_sortName(l10n, sort)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (chosen == null || chosen == view.sort) return;
    await chooseSort(ref.read(settingsRepositoryProvider), chosen);
  }

  static String _sortName(AppLocalizations l10n, LibrarySort sort) =>
      switch (sort) {
        LibrarySort.recent => l10n.librarySortRecent,
        LibrarySort.added => l10n.librarySortAdded,
        LibrarySort.title => l10n.librarySortTitle,
        LibrarySort.author => l10n.librarySortAuthor,
        LibrarySort.progress => l10n.librarySortProgress,
      };
}

/// "Adding 2 of 5: name" with a progress line, over the book list.
class _ImportProgress extends StatelessWidget {
  const _ImportProgress({required this.queue});

  final ImportQueueState queue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = (queue.done + 1).clamp(1, queue.total);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l10n.importProgress(current, queue.total, queue.current ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: queue.done / queue.total),
      ],
    );
  }
}

/// Every file of the last batch and what became of it.
class _ImportDetails extends StatelessWidget {
  const _ImportDetails({required this.results});

  final List<ImportResult> results;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.importDetailsTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final result in results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(switch (result) {
                  ImportAdded(:final book) ||
                  ImportDuplicate(:final book) => book.title,
                  ImportFailed(:final fileName) => fileName,
                }),
                subtitle: Text(switch (result) {
                  ImportAdded() => l10n.importStatusAdded,
                  ImportDuplicate() => l10n.importStatusDuplicate,
                  ImportFailed(:final error) => switch (error) {
                    ImportError.unsupportedFormat =>
                      l10n.importStatusUnsupported,
                    ImportError.damaged => l10n.importStatusDamaged,
                    ImportError.drm => l10n.importStatusDrm,
                    ImportError.unreadable => l10n.importStatusUnreadable,
                  },
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Empty(title: l10n.libraryEmpty, hint: l10n.libraryEmptyHint);
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.shelf});

  final Shelf shelf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, hint) = switch (shelf) {
      Shelf.reading => (l10n.libraryReadingEmpty, l10n.libraryReadingEmptyHint),
      Shelf.finished => (
        l10n.libraryFinishedEmpty,
        l10n.libraryFinishedEmptyHint,
      ),
      // "Все" is empty only with an empty library, shown on its own.
      _ => (l10n.libraryCollectionEmpty, l10n.libraryCollectionEmptyHint),
    };
    return _Empty(title: title, hint: hint);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.hint});

  final String title;
  final String hint;

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
            Icon(Icons.menu_book_outlined, size: 56, color: colors.accent),
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
          ],
        ),
      ),
    );
  }
}

void _openBook(BuildContext context, int bookId) => unawaited(
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => ReaderScreen(bookId: bookId))),
);
