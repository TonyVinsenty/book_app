import 'dart:io';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/data/db/app_database.dart';
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
  /// (current, total) while picked files are imported.
  (int, int)? _progress;

  Future<void> _addBooks() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final List<String> paths;
    try {
      paths = await ref.read(pickBooksProvider)();
    } on PlatformException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importPickFailed)));
      return;
    }
    if (paths.isEmpty || !mounted) return;

    final importer = ref.read(bookImporterProvider);
    final results = <ImportResult>[];
    for (final (i, path) in paths.indexed) {
      setState(() => _progress = (i + 1, paths.length));
      final copy = File(path);
      results.add(await importer.importFile(copy));
      try {
        await copy.delete();
      } on FileSystemException {
        // A leftover in the cache folder; the next pick clears it.
      }
    }
    if (!mounted) return;
    setState(() => _progress = null);
    messenger.showSnackBar(SnackBar(content: Text(_summary(l10n, results))));
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
    final progress = _progress;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        bottom: progress == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: progress.$1 / progress.$2,
                ),
              ),
      ),
      body: switch (books) {
        AsyncData(value: final list) when list.isEmpty => const _EmptyLibrary(),
        AsyncData(value: final list) => _BookList(books: list),
        _ => const SizedBox.shrink(),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: progress == null ? _addBooks : null,
        icon: const Icon(Icons.add),
        label: Text(
          progress == null
              ? l10n.addBook
              : l10n.importProgress(progress.$1, progress.$2),
        ),
      ),
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
