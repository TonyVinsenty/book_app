import 'dart:async';

import 'package:book_app/app/notice.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/data/folders/folder_scanner.dart';
import 'package:book_app/data/import_queue.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/features/library/book_menu.dart';
import 'package:book_app/features/library/book_shelf.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/library/collection_pick_screen.dart';
import 'package:book_app/features/library/collection_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tabs "Книги" (statuses, list or grid, "Продолжить", the "Add book"
/// button) and "Подборки" (stage 9.11, mockup `docs/design/library-v2.html`,
/// variant Б).
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  var _tab = _Tab.books;

  Future<void> _addBooks() async {
    final List<String> paths;
    try {
      paths = await ref.read(pickBooksProvider)();
    } on PlatformException {
      if (!mounted) return;
      showNotice(context, AppLocalizations.of(context).importPickFailed);
      return;
    }
    if (!mounted) return;
    // The summary comes when the queue empties (see build).
    unawaited(ref.read(importQueueProvider.notifier).add(paths));
  }

  void _showSummary(List<ImportResult> results) {
    final l10n = AppLocalizations.of(context);
    showNotice(
      context,
      _summary(l10n, results),
      // With "Подробнее" it would stay until closed, over the list.
      persist: false,
      duration: const Duration(seconds: 8),
      action: results.length < 2
          ? null
          : SnackBarAction(
              label: l10n.importDetails,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _ImportDetails(results: results),
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
    final books = _tab == _Tab.books;
    return Scaffold(
      // No app bar: the name is not needed here (owner, 2026-10-20).
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _BackToBook(),
            _Tabs(
              selected: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
            ),
            if (queue.busy) _ImportProgress(queue: queue),
            Expanded(
              child: switch (view) {
                AsyncData(:final value) when books && value.libraryIsEmpty =>
                  EmptyMessage(
                    title: l10n.libraryEmpty,
                    hint: l10n.libraryEmptyHint,
                  ),
                AsyncData(:final value) when books => _BooksTab(view: value),
                AsyncData(:final value) => _CollectionsTab(view: value),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
      // The picker replaces its previous copies, so it waits for the queue.
      floatingActionButton: queue.busy || !books
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

/// "Вернуться к «…»": back to the book the reader was closed on, whatever
/// the shelf (owner, 2026-10-21); nothing if that book is gone.
class _BackToBook extends ConsumerWidget {
  const _BackToBook();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(leftBookProvider);
    final book = id == null
        ? null
        : ref.watch(booksProvider).value?.where((b) => b.id == id).firstOrNull;
    if (book == null) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 16, 0),
        child: TextButton.icon(
          onPressed: () => openBook(context, book.id),
          icon: const Icon(Icons.arrow_back),
          label: Text(
            AppLocalizations.of(context).libraryBackToBook(book.title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

enum _Tab { books, collections }

/// "Книги" | "Подборки".
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});

  final _Tab selected;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    Widget tab(_Tab tab, String name) {
      final on = tab == selected;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: Material(
            color: on ? colors.accent : Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: on ? null : () => onChanged(tab),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: on ? colors.background : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          tab(_Tab.books, l10n.libraryTabBooks),
          tab(_Tab.collections, l10n.libraryTabCollections),
        ],
      ),
    );
  }
}

/// "Продолжить", the status button with the look and order buttons, then
/// the books; all of it scrolls together.
class _BooksTab extends ConsumerWidget {
  const _BooksTab({required this.view});

  final LibraryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(bookRepositoryProvider);
    final titleFont = ref.watch(
      readingSettingsProvider.select((s) => s.font.family),
    );
    // Not over a chosen status or the author groups (owner, 2026-10-20).
    final last = view.filter.status == null && view.sort != LibrarySort.author
        ? view.continueBook
        : null;
    // Pull down → look in the folders now; the queue line shows the rest.
    return RefreshIndicator(
      onRefresh: () async => unawaited(ref.read(scanFoldersProvider)()),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (last != null)
            SliverToBoxAdapter(
              child: ContinueCard(
                onTap: () => openBook(context, last.id),
                onLongPress: () => unawaited(showBookMenu(context, ref, last)),
                coverFile: repository.coverFile(last),
                title: last.title,
                authors: last.authors.join(', '),
                percent: percentRead(last) ?? 0,
                titleFont: titleFont,
              ),
            ),
          SliverToBoxAdapter(
            child: ShelfBar(
              view: view,
              onStatus: (status) => unawaited(
                chooseFilter(
                  ref.read(settingsRepositoryProvider),
                  LibraryFilter(status: status),
                ),
              ),
            ),
          ),
          if (view.books.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyShelf(status: view.filter.status),
            )
          else ...[
            BookShelf(
              view: view,
              onLongPress: (book) =>
                  unawaited(showBookMenu(context, ref, book)),
            ),
            // Room for the button over the last book.
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ],
      ),
    );
  }
}

/// "Создать подборку" and the collections by name, each with three covers
/// and the number of books.
class _CollectionsTab extends ConsumerWidget {
  const _CollectionsTab({required this.view});

  final LibraryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    Future<void> create() => createCollection(context, ref);

    if (view.collections.isEmpty) {
      return EmptyMessage(
        icon: Icons.collections_bookmark_outlined,
        title: l10n.collectionsEmpty,
        hint: l10n.collectionsEmptyHint,
        action: FilledButton.icon(
          onPressed: () => unawaited(create()),
          icon: const Icon(Icons.add),
          label: Text(l10n.collectionCreate),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => unawaited(create()),
            icon: const Icon(Icons.add),
            label: Text(l10n.collectionCreate),
          ),
        ),
        for (final c in view.collections)
          CollectionCard(
            key: ValueKey(c.id),
            collection: c,
            books: view.collectionBooks[c.id] ?? const [],
            onTap: () => openCollection(context, c.id),
          ),
        if (view.collections.length < 4)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Text(
              l10n.collectionsHint,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
          ),
      ],
    );
  }
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
