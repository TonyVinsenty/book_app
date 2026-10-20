import 'dart:async';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/reading_position.dart';
import 'package:book_app/data/book_pages.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/features/library/book_menu.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/layout/page_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

void openBookPage(BuildContext context, int bookId) => unawaited(
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => BookPageScreen(bookId: bookId)),
  ),
);

/// A tap on a book (mockup v2 "Страница книги"): cover, status, pages for
/// the current font, words, how far it is read; "Читать", the status,
/// collections, deleting.
class BookPageScreen extends ConsumerStatefulWidget {
  const BookPageScreen({super.key, required this.bookId});

  final int bookId;

  @override
  ConsumerState<BookPageScreen> createState() => _BookPageScreenState();
}

class _BookPageScreenState extends ConsumerState<BookPageScreen> {
  var _closing = false;

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider).value;
    final book = books?.where((b) => b.id == widget.bookId).firstOrNull;
    if (books != null && book == null) _close();
    return Scaffold(
      appBar: AppBar(),
      body: book == null ? const SizedBox.shrink() : _BookPage(book: book),
      bottomNavigationBar: book == null ? null : _MainButton(book: book),
    );
  }

  /// The book was deleted: back to the library.
  void _close() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(Navigator.of(context).maybePop());
    });
  }
}

class _BookPage extends ConsumerWidget {
  const _BookPage({required this.book});

  final BookRow book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.readingColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final settings = ref.watch(readingSettingsProvider);
    final titleFont = settings.font.family;
    final status = statusOf(book);
    final mark = ReadMark.of(book);
    final pages = _pagesOf(context, ref, settings);
    final opened = book.openedAt != null;

    final (String readValue, String readLabel) = switch (status) {
      BookStatus.finished => (
        _date(book.finishedAt!, locale),
        l10n.bookPageFinishedOn,
      ),
      _ when !opened => ('—', l10n.bookPageReadShare),
      _ when pages.exact => (
        NumberFormat.decimalPattern(locale).format(pages.current),
        l10n.bookPageAtPage,
      ),
      _ => (l10n.bookPagePercent(mark.percent), l10n.bookPageReadShare),
    };
    final total = NumberFormat.decimalPattern(locale).format(pages.total);
    final note = [
      if (status == BookStatus.finished)
        l10n.bookPageFinished(_date(book.finishedAt!, locale)),
      l10n.bookPageAdded(_date(book.addedAt, locale)),
      _formatName(book.sourceFormat),
      _size(l10n, book.sourceSize, locale),
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _Hero(book: book, mark: mark, titleFont: titleFont),
        const SizedBox(height: 20),
        // Tiles of one height when a label takes two lines.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Tile(
                value: pages.exact ? total : l10n.bookPageAbout(total),
                label: pages.exact
                    ? l10n.bookPagePages(pages.total)
                    : l10n.bookPagePagesEstimate(pages.total),
              ),
              const SizedBox(width: 8),
              _Tile(
                value: NumberFormat.compact(locale: locale)
                    .format(book.wordCount),
                // "84 тыс. слов": past a thousand the word is always "слов".
                label: l10n.bookPageWords(
                  book.wordCount < 1000 ? book.wordCount : 0,
                ),
              ),
              const SizedBox(width: 8),
              _Tile(value: readValue, label: readLabel),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${pages.exact ? l10n.bookPageExactNote : l10n.bookPageEstimateNote}'
          ' $note',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        _StatusButtons(book: book, status: status),
        const SizedBox(height: 12),
        _CollectionsRow(book: book, titleFont: titleFont),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              minimumSize: const Size(0, 48),
            ),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.bookMenuDelete),
            onPressed: () => unawaited(_delete(context, ref)),
          ),
        ),
      ],
    );
  }

  /// Pages with the reader's look and page: exact from its saved split,
  /// otherwise an estimate (ADR 0005, addendum 3).
  BookPages _pagesOf(
    BuildContext context,
    WidgetRef ref,
    ReadingSettings settings,
  ) {
    final style = pageStyleOf(
      settings,
      system: MediaQuery.textScalerOf(context),
      color: context.readingColors.text,
      hyphenation: ref.watch(hyphenationProvider),
    );
    final last = ref.watch(lastLayoutProvider).value;
    final pageSize = bookPageSizeOf(
      last: last,
      area: MediaQuery.viewPaddingOf(context)
          .deflateSize(MediaQuery.sizeOf(context)),
      side: settings.margins.side,
    );
    final cache = PageCache(ref.watch(contentStoreProvider).pagesDir(book.id));
    return bookPagesOf(
      words: book.wordCount,
      positionWord: book.positionWord,
      style: style,
      pageSize: pageSize,
      cached: cache.peek(
        layoutKeyOf(
          style: style,
          pageSize: pageSize,
          parserVersion: book.parserVersion,
        ),
        words: book.wordCount,
      ),
      last: last,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (await confirmBookDelete(context, book.title)) {
      // The page closes itself once the book is gone.
      await ref.read(bookRepositoryProvider).deleteBook(book.id);
    }
  }
}

String _date(DateTime date, String locale) =>
    (date.year == DateTime.now().year
            ? DateFormat.MMMd(locale)
            : DateFormat.yMMMd(locale))
        .format(date)
        // "16 окт." stays on one line.
        .replaceAll(' ', ' ');

String _formatName(SourceFormat format) => switch (format) {
  SourceFormat.txt => 'TXT',
  SourceFormat.fb2 => 'FB2',
  SourceFormat.fb2zip => 'FB2.ZIP',
  SourceFormat.epub => 'EPUB',
};

String _size(AppLocalizations l10n, int bytes, String locale) {
  const mb = 1024 * 1024;
  if (bytes < mb) return l10n.sizeKb('${(bytes / 1024).ceil()}');
  return l10n.sizeMb(NumberFormat('0.#', locale).format(bytes / mb));
}

/// Cover, status, title, authors and, while reading, the bar.
class _Hero extends StatelessWidget {
  const _Hero({required this.book, required this.mark, this.titleFont});

  final BookRow book;
  final ReadMark mark;
  final String? titleFont;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.readingColors;
    final l10n = AppLocalizations.of(context);
    return Consumer(
      builder: (context, ref, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(
            file: ref.watch(bookRepositoryProvider).coverFile(book),
            title: book.title,
            width: 112,
            height: 164,
            titleFont: titleFont,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookStatusLabel(mark: mark),
                const SizedBox(height: 6),
                Text(
                  book.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: titleFont,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (book.authors.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    book.authors.join(', '),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                if (mark.status == BookStatus.reading) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: ReadBar(share: mark.percent / 100)),
                      const SizedBox(width: 8),
                      Text(
                        l10n.bookPagePercent(mark.percent),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.readingColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Статус: …" and "Прочитано"; for a read book "Прочитано" and "Читаю
/// снова".
class _StatusButtons extends ConsumerWidget {
  const _StatusButtons({required this.book, required this.status});

  final BookRow book;
  final BookStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final books = ref.read(bookRepositoryProvider);
    Widget button(IconData? icon, String text, VoidCallback onPressed) =>
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: icon == null ? null : Icon(icon, size: 20),
            label: Text(text, maxLines: 2, textAlign: TextAlign.center),
            onPressed: onPressed,
          ),
        );
    void chooseStatus() => unawaited(chooseBookStatus(context, ref, book));
    final finished = status == BookStatus.finished;
    return Row(
      children: [
        button(
          finished ? Icons.check : null,
          finished
              ? l10n.statusFinished
              : l10n.bookMenuStatus(statusName(l10n, status)),
          chooseStatus,
        ),
        if (!finished || book.openedAt != null) const SizedBox(width: 8),
        if (!finished)
          button(
            Icons.done_all,
            l10n.statusFinished,
            () => unawaited(books.markFinished(book.id)),
          )
        else if (book.openedAt != null)
          button(
            Icons.replay,
            l10n.bookPageReadingAgain,
            () => unawaited(books.markUnfinished(book.id)),
          ),
      ],
    );
  }
}

/// "В подборку" with the collections the book is in.
class _CollectionsRow extends ConsumerWidget {
  const _CollectionsRow({required this.book, this.titleFont});

  final BookRow book;
  final String? titleFont;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final links = ref.watch(collectionLinksProvider).value ?? const [];
    final mine = {
      for (final l in links)
        if (l.bookId == book.id) l.collectionId,
    };
    final names = [
      for (final c
          in ref.watch(collectionsProvider).value ?? const <CollectionRow>[])
        if (mine.contains(c.id)) c.name,
    ];
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: 60,
        leading: Icon(
          Icons.collections_bookmark_outlined,
          color: colors.textSecondary,
        ),
        title: Text(
          l10n.bookPageCollections,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          names.isEmpty ? l10n.bookPageNoCollections : names.join(', '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => unawaited(
          showBookCollections(context, ref, book: book, titleFont: titleFont),
        ),
      ),
    );
  }
}

/// "Читать", "Продолжить" or, for a read book, "Читать снова" from the
/// start.
class _MainButton extends ConsumerWidget {
  const _MainButton({required this.book});

  final BookRow book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final finished = book.finishedAt != null;
    final text = finished
        ? l10n.bookPageReadAgain
        : book.openedAt != null
        ? l10n.libraryContinue
        : l10n.bookPageRead;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () async {
            if (finished) {
              await ref
                  .read(bookRepositoryProvider)
                  .savePosition(book.id, ReadingPosition.start);
            }
            // "Back" from the book goes to the library, as from
            // "Продолжить".
            if (!context.mounted) return;
            unawaited(
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => ReaderScreen(bookId: book.id),
                ),
              ),
            );
          },
          child: Text(text),
        ),
      ),
    );
  }
}
