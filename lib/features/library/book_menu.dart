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

/// "В подборку…" for [book], from its page.
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
  final books = ref.read(bookRepositoryProvider);
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
