import 'dart:async';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/features/library/book_shelf.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void openCollection(BuildContext context, int id) => unawaited(
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => CollectionScreen(collectionId: id)),
  ),
);

/// The books of one collection with the same status, look and order
/// buttons as the library (mockup "Внутри подборки"). The status chosen here
/// is not remembered.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key, required this.collectionId});

  final int collectionId;

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  BookStatus? _status;

  /// Seen in the collections once: a new one may come a moment later.
  var _seen = false;
  var _closing = false;

  @override
  Widget build(BuildContext context) {
    final view = ref
        .watch(
          collectionViewProvider(
            LibraryFilter(status: _status, collectionId: widget.collectionId),
          ),
        )
        .value;
    final collection = view?.collections
        .where((c) => c.id == widget.collectionId)
        .firstOrNull;
    if (collection != null) _seen = true;
    if (_seen && view != null && collection == null) _close();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: view == null || collection == null
            ? const SizedBox.shrink()
            : Column(
                children: [
                  _Header(
                    name: collection.name,
                    count: view.collectionBooks[collection.id]?.length ?? 0,
                  ),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: ShelfBar(
                            view: view,
                            onStatus: (s) => setState(() => _status = s),
                          ),
                        ),
                        if (view.books.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyShelf(status: view.filter.status),
                          )
                        else ...[
                          BookShelf(view: view),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// The collection was deleted: back to the library.
  void _close() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(Navigator.of(context).maybePop());
    });
  }
}

/// Back, the name (up to two lines) and the number of books.
class _Header extends ConsumerWidget {
  const _Header({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final titleFont = ref.watch(
      readingSettingsProvider.select((s) => s.font.family),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          const BackButton(),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: titleFont,
                    fontSize: 19,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                Text(
                  l10n.libraryBookCount(count),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One collection on the "Подборки" tab: up to three covers in a stack, the
/// name (up to two lines), the number of books.
class CollectionCard extends ConsumerWidget {
  const CollectionCard({
    super.key,
    required this.collection,
    required this.books,
    required this.onTap,
  });

  static const _coverWidth = 36.0;
  static const _coverHeight = 54.0;
  static const _shift = 14.0;

  final CollectionRow collection;

  /// In the library order; the first three are shown.
  final List<BookRow> books;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final repository = ref.watch(bookRepositoryProvider);
    final titleFont = ref.watch(
      readingSettingsProvider.select((s) => s.font.family),
    );
    final covers = books.take(3).toList();
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 80),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: _coverWidth + _shift * 2 + 4,
                height: _coverHeight + 6,
                child: covers.isEmpty
                    ? Icon(
                        Icons.collections_bookmark_outlined,
                        size: 36,
                        color: colors.textSecondary,
                      )
                    : Stack(
                        children: [
                          // The first book lies on top.
                          for (final (i, b) in covers.indexed.toList().reversed)
                            Positioned(
                              left: i * _shift,
                              top: 3,
                              child: BookCover(
                                file: repository.coverFile(b),
                                title: b.title,
                                width: _coverWidth,
                                height: _coverHeight,
                                titleFont: titleFont,
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: titleFont,
                        fontSize: 16.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.libraryBookCount(books.length),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
