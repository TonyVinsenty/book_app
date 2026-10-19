import 'dart:async';
import 'dart:io';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/import_queue.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The book list and the "Add book" button (stage 5: a plain list).
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importPickFailed)));
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
    final books = ref.watch(booksProvider);
    final queue = ref.watch(importQueueProvider);
    ref.listen(importQueueProvider, (previous, next) {
      final finished = next.finished;
      if (finished != null && previous?.finished == null) {
        _showSummary(finished);
      }
    });
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Column(
        children: [
          if (queue.busy) _ImportProgress(queue: queue),
          Expanded(
            child: switch (books) {
              AsyncData(value: final list) when list.isEmpty =>
                const _EmptyLibrary(),
              AsyncData(value: final list) => _BookList(books: list),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
      // The picker replaces its previous copies, so it waits for the queue.
      floatingActionButton: queue.busy
          ? null
          : FloatingActionButton.extended(
              onPressed: _addBooks,
              icon: const Icon(Icons.add),
              label: Text(l10n.addBook),
            ),
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

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.libraryEmpty,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.libraryEmptyHint,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookList extends ConsumerWidget {
  const _BookList({required this.books});

  final List<BookRow> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(bookRepositoryProvider);
    return ListView.builder(
      // Room for the button over the last item.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        return ListTile(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReaderScreen(bookId: book.id),
            ),
          ),
          leading: _Cover(file: repository.coverFile(book), title: book.title),
          title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: book.authors.isEmpty
              ? null
              : Text(
                  book.authors.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        );
      },
    );
  }
}

/// A small cover, decoded at the size it is shown; a book without one gets
/// a plain tile with the first letter of its title (stage 9 draws better).
class _Cover extends StatelessWidget {
  const _Cover({required this.file, required this.title});

  static const _width = 40.0;
  static const _height = 60.0;

  final File? file;
  final String title;

  @override
  Widget build(BuildContext context) {
    final file = this.file;
    final placeholder = _placeholder(Theme.of(context));
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: _width,
        height: _height,
        child: file == null
            ? placeholder
            : Image.file(
                file,
                fit: BoxFit.cover,
                // Covers are portrait: decoded by height, they fill the box.
                cacheHeight: (_height * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    final letter = title.trim().characters.firstOrNull?.toUpperCase() ?? '';
    return ColoredBox(
      color: theme.colorScheme.secondaryContainer,
      child: Center(
        child: Text(
          letter,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
