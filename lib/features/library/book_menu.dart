import 'dart:async';
import 'dart:io';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/library/collection_name_dialog.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _BookAction { collections, markFinished, readAgain, uncollect, delete }

/// What a long press on a book offers (mockup "Действия с книгой"):
/// collections, the read mark, taking it out of the shown collection,
/// deleting it.
Future<void> showBookMenu(
  BuildContext context,
  WidgetRef ref, {
  required BookRow book,
  required Shelf shelf,
  String? titleFont,
}) async {
  final books = ref.read(bookRepositoryProvider);
  final collections = ref.read(collectionRepositoryProvider);
  final header = _BookHeader(
    book: book,
    coverFile: books.coverFile(book),
    titleFont: titleFont,
  );
  // "Продолжить" shows on every shelf, its book may be in another one.
  final collectionId = shelf.collectionId;
  final inCollection =
      collectionId != null &&
      (ref.read(collectionLinksProvider).value ?? const []).any(
        (l) => l.collectionId == collectionId && l.bookId == book.id,
      );
  final action = await showModalBottomSheet<_BookAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => _BookMenu(
      header: header,
      finished: book.finishedAt != null,
      inCollection: inCollection,
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _BookAction.collections:
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _BookCollections(bookId: book.id, header: header),
      );
    case _BookAction.markFinished:
      await books.markFinished(book.id);
    case _BookAction.readAgain:
      await books.markUnfinished(book.id);
    case _BookAction.uncollect:
      await collections.removeBook(collectionId!, book.id);
    case _BookAction.delete:
      if (await _confirmDelete(context, book.title)) {
        await books.deleteBook(book.id);
      }
  }
}

Future<bool> _confirmDelete(BuildContext context, String title) async {
  final l10n = AppLocalizations.of(context);
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.bookDeleteTitle(title)),
      content: Text(l10n.bookDeleteText),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return yes ?? false;
}

class _BookMenu extends StatelessWidget {
  const _BookMenu({
    required this.header,
    required this.finished,
    required this.inCollection,
  });

  final Widget header;
  final bool finished;
  final bool inCollection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final danger = Theme.of(context).colorScheme.error;
    Widget item(IconData icon, String text, _BookAction action, {Color? c}) =>
        ListTile(
          leading: Icon(icon, color: c),
          title: Text(text, style: TextStyle(color: c)),
          onTap: () => Navigator.of(context).pop(action),
        );
    return SafeArea(
      // Scrolls on a low screen (landscape, large text).
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            item(
              Icons.collections_bookmark_outlined,
              l10n.bookMenuToCollection,
              _BookAction.collections,
            ),
            if (finished)
              item(Icons.replay, l10n.bookMenuReadAgain, _BookAction.readAgain)
            else
              item(
                Icons.check_circle_outline,
                l10n.bookMenuMarkFinished,
                _BookAction.markFinished,
              ),
            if (inCollection)
              item(
                Icons.remove_circle_outline,
                l10n.bookMenuRemoveFromCollection,
                _BookAction.uncollect,
              ),
            item(
              Icons.delete_outline,
              l10n.bookMenuDelete,
              _BookAction.delete,
              c: danger,
            ),
          ],
        ),
      ),
    );
  }
}

/// "В подборку…": a checkmark for every collection, one tap puts the book
/// in or takes it out; "Новая подборка" creates one with the book in it.
class _BookCollections extends ConsumerWidget {
  const _BookCollections({required this.bookId, required this.header});

  final int bookId;
  final Widget header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final repository = ref.watch(collectionRepositoryProvider);
    final collections = switch (ref.watch(libraryViewProvider)) {
      AsyncData(:final value) => value.collections,
      _ => const <CollectionRow>[],
    };
    final links = ref.watch(collectionLinksProvider).value ?? const [];
    final counts = <int, int>{};
    final mine = <int>{};
    for (final l in links) {
      counts.update(l.collectionId, (n) => n + 1, ifAbsent: () => 1);
      if (l.bookId == bookId) mine.add(l.collectionId);
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            header,
            for (final c in collections)
              CheckboxListTile(
                value: mine.contains(c.id),
                secondary: const Icon(Icons.collections_bookmark_outlined),
                title: Text(c.name),
                subtitle: Text(l10n.libraryBookCount(counts[c.id] ?? 0)),
                onChanged: (on) => unawaited(
                  on ?? false
                      ? repository.addBook(c.id, bookId)
                      : repository.removeBook(c.id, bookId),
                ),
              ),
            ListTile(
              leading: Icon(Icons.add, color: colors.accent),
              title: Text(
                l10n.collectionNew,
                style: TextStyle(color: colors.accent),
              ),
              onTap: () => unawaited(
                askCollectionName<void>(
                  context,
                  title: l10n.collectionNew,
                  action: l10n.create,
                  save: (name) async {
                    final created = await repository.create(name);
                    await repository.addBook(created.id, bookId);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The cover, title and authors on top of the menu.
class _BookHeader extends StatelessWidget {
  const _BookHeader({
    required this.book,
    required this.coverFile,
    required this.titleFont,
  });

  final BookRow book;
  final File? coverFile;
  final String? titleFont;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.readingColors;
    final authors = book.authors.join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          BookCover(
            file: coverFile,
            title: book.title,
            width: 36,
            height: 52,
            titleFont: titleFont,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: titleFont,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (authors.isNotEmpty)
                  Text(
                    authors,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
