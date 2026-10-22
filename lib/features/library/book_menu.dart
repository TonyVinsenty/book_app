import 'dart:async';
import 'dart:io';

import 'package:book_app/app/notice.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/features/library/book_page.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/library/collection_name_dialog.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _MenuAction { share, details, collections, removeFromCollection, delete }

/// A long press on a book (library and collections): the book menu. In the
/// collection [collectionId] it can also take the book out of it.
Future<void> showBookMenu(
  BuildContext context,
  WidgetRef ref,
  BookRow book, {
  int? collectionId,
}) async {
  final titleFont = ref.read(readingSettingsProvider).font.family;
  final action = await showModalBottomSheet<_MenuAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final error = Theme.of(context).colorScheme.error;
      ListTile item(_MenuAction action, IconData icon, String label) =>
          ListTile(
            leading: Icon(icon),
            title: Text(label),
            onTap: () => Navigator.of(context).pop(action),
          );
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BookHeader(
                book: book,
                coverFile: ref.read(bookRepositoryProvider).coverFile(book),
                titleFont: titleFont,
              ),
              item(_MenuAction.share, Icons.adaptive.share, l10n.bookMenuShare),
              item(
                _MenuAction.details,
                Icons.info_outline,
                l10n.bookMenuDetails,
              ),
              item(
                _MenuAction.collections,
                Icons.collections_bookmark_outlined,
                l10n.bookMenuAddToCollection,
              ),
              if (collectionId != null)
                item(
                  _MenuAction.removeFromCollection,
                  Icons.remove_circle_outline,
                  l10n.bookMenuRemoveFromCollection,
                ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: error),
                title: Text(
                  l10n.bookMenuDelete,
                  style: TextStyle(color: error),
                ),
                onTap: () => Navigator.of(context).pop(_MenuAction.delete),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _MenuAction.share:
      await shareBook(context, ref, book);
    case _MenuAction.details:
      openBookPage(context, book.id);
    case _MenuAction.collections:
      await showBookCollections(context, ref, book: book, titleFont: titleFont);
    case _MenuAction.removeFromCollection:
      await ref
          .read(collectionRepositoryProvider)
          .removeBook(collectionId!, book.id);
    case _MenuAction.delete:
      if (await confirmBookDelete(context, book.title)) {
        await ref.read(bookRepositoryProvider).deleteBook(book.id);
      }
  }
}

/// "Поделиться": the book's file to the system share sheet (11а.6).
Future<void> shareBook(
  BuildContext context,
  WidgetRef ref,
  BookRow book,
) async {
  try {
    await ref.read(bookSharerProvider).share(book);
  } on Object {
    if (!context.mounted) rethrow;
    showNotice(context, AppLocalizations.of(context).bookShareFailed);
    rethrow;
  }
}

/// "В подборку…" for [book], from its page or the book menu.
Future<void> showBookCollections(
  BuildContext context,
  WidgetRef ref, {
  required BookRow book,
  String? titleFont,
}) => _showCollections(
  context,
  book.id,
  _BookHeader(
    book: book,
    coverFile: ref.read(bookRepositoryProvider).coverFile(book),
    titleFont: titleFont,
  ),
);

Future<void> _showCollections(
  BuildContext context,
  int bookId,
  Widget header,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _BookCollections(bookId: bookId, header: header),
);

/// "Статус книги": Читаю, На очереди, Брошена, Прочитано (ADR 0005
/// addendum 3). "Новая" is not chosen by hand, and a book never opened
/// becomes "Читаю" by opening it.
Future<void> chooseBookStatus(
  BuildContext context,
  WidgetRef ref,
  BookRow book,
) async {
  final l10n = AppLocalizations.of(context);
  // Read now: the caller may be gone when the sheet closes.
  final books = ref.read(bookRepositoryProvider);
  final current = statusOf(book);
  final options = [
    if (book.openedAt != null) BookStatus.reading,
    BookStatus.queued,
    BookStatus.abandoned,
    BookStatus.finished,
  ];
  final chosen = await showModalBottomSheet<BookStatus>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: RadioGroup<BookStatus>(
          groupValue: current,
          onChanged: (status) => Navigator.of(context).pop(status),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  l10n.libraryStatusFilter,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final status in options)
                RadioListTile<BookStatus>(
                  value: status,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(statusName(l10n, status)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  l10n.statusNewHint,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.readingColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (chosen == null || chosen == current) return;
  await switch (chosen) {
    // Takes off both "queued"/"abandoned" and the read mark.
    BookStatus.reading => books.setStatusMark(book.id, null),
    BookStatus.queued => books.setStatusMark(book.id, StatusMark.queued),
    BookStatus.abandoned => books.setStatusMark(book.id, StatusMark.abandoned),
    BookStatus.finished => books.markFinished(book.id),
    BookStatus.notStarted => Future<void>.value(),
  };
}

/// The status of one book: "Новая", "Читаю", "На очереди", …
String statusName(AppLocalizations l10n, BookStatus status) => switch (status) {
  BookStatus.notStarted => l10n.statusNew,
  BookStatus.reading => l10n.statusReadingShort,
  BookStatus.queued => l10n.statusQueued,
  BookStatus.abandoned => l10n.statusAbandoned,
  BookStatus.finished => l10n.statusFinished,
};

/// Asks before deleting the book [title].
Future<bool> confirmBookDelete(BuildContext context, String title) async {
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
                  save: (name) => repository.create(name, bookIds: {bookId}),
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
