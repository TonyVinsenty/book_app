import 'dart:async';

import 'package:book_app/app/notice.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/collection_repository.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/features/library/book_shelf.dart';
import 'package:book_app/features/library/collection_name_dialog.dart';
import 'package:book_app/features/library/collection_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Создать подборку": the name, then the books checked for it.
Future<void> createCollection(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final name = await askCollectionName(
    context,
    title: l10n.collectionNew,
    action: l10n.create,
    save: ref.read(collectionRepositoryProvider).checkName,
  );
  if (name != null && context.mounted) {
    await _push(context, CollectionPickScreen(name: name));
  }
}

/// A long press on a book: a new collection with [bookId] checked; the name
/// is asked at "Готово".
void pickForNewCollection(BuildContext context, int bookId) =>
    unawaited(_push(context, CollectionPickScreen(initial: {bookId})));

/// "Добавить книги" of a collection: its books are checked.
void pickForCollection(BuildContext context, int collectionId) =>
    unawaited(_push(context, CollectionPickScreen(collectionId: collectionId)));

Future<void> _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

/// The whole library with checks (mockup "Создание подборки", steps 3–4),
/// for [collectionId] or a new collection called [name]. Nothing is written
/// until "Готово": the checks are this screen's own.
class CollectionPickScreen extends ConsumerStatefulWidget {
  const CollectionPickScreen({
    super.key,
    this.collectionId,
    this.name,
    this.initial = const {},
  });

  final int? collectionId;

  /// A new collection; asked at "Готово" when null.
  final String? name;

  /// Checked at the start of a new collection.
  final Set<int> initial;

  @override
  ConsumerState<CollectionPickScreen> createState() =>
      _CollectionPickScreenState();
}

class _CollectionPickScreenState extends ConsumerState<CollectionPickScreen> {
  /// Filled once the collection's books are known: checking from an empty
  /// set would take them out of it at "Готово".
  Set<int>? _checked;
  var _saving = false;

  Set<int> get _picked => _checked!;

  Set<int>? _seed() {
    final id = widget.collectionId;
    if (id == null) return {...widget.initial};
    final links = ref.watch(collectionLinksProvider).value;
    return links == null
        ? null
        : {
            ...widget.initial,
            for (final l in links)
              if (l.collectionId == id) l.bookId,
          };
  }

  void _toggle(int bookId) => setState(
    () =>
        _picked.contains(bookId) ? _picked.remove(bookId) : _picked.add(bookId),
  );

  Future<void> _done(LibraryView view) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _save(view);
    } on Object {
      if (!mounted) rethrow;
      setState(() => _saving = false);
      showNotice(context, AppLocalizations.of(context).collectionSaveFailed);
      rethrow;
    }
  }

  Future<void> _save(LibraryView view) async {
    // A book may have been deleted meanwhile.
    final ids = {
      for (final b in view.books)
        if (_picked.contains(b.id)) b.id,
    };
    final repository = ref.read(collectionRepositoryProvider);
    if (widget.collectionId case final id?) {
      await repository.setBooks(id, ids);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final created = await _create(repository, ids);
    if (!mounted) return;
    if (created == null) {
      setState(() => _saving = false);
      return;
    }
    final l10n = AppLocalizations.of(context);
    showNotice(context, l10n.collectionCreated(created.name));
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CollectionScreen(collectionId: created.id),
        ),
      ),
    );
  }

  /// Asks the name when there is none yet, or when it was taken meanwhile.
  Future<CollectionRow?> _create(
    CollectionRepository repository,
    Set<int> ids,
  ) async {
    if (widget.name case final name?) {
      try {
        return await repository.create(name, bookIds: ids);
      } on CollectionNameException {
        // Asked again below, with the error shown there.
      }
    }
    if (!mounted) return null;
    final l10n = AppLocalizations.of(context);
    return askCollectionName(
      context,
      title: l10n.collectionNew,
      action: l10n.create,
      initial: widget.name ?? '',
      save: (name) => repository.create(name, bookIds: ids),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(collectionViewProvider(const LibraryFilter())).value;
    _checked ??= _seed();
    final id = widget.collectionId;
    final name = id == null
        ? widget.name ?? l10n.collectionNew
        : view?.collections.where((c) => c.id == id).firstOrNull?.name;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: view == null || name == null || _checked == null
            ? const SizedBox.shrink()
            : Column(
                children: [
                  _Header(name: name, picked: _picked.length),
                  Expanded(
                    child: view.libraryIsEmpty
                        ? EmptyMessage(
                            title: l10n.libraryEmpty,
                            hint: l10n.libraryEmptyHint,
                          )
                        : CustomScrollView(
                            slivers: [
                              BookShelf(
                                view: view,
                                picked: _picked,
                                onPick: _toggle,
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 16),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: view == null || name == null || _checked == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _saving ? null : () => unawaited(_done(view)),
                  child: Text(l10n.collectionPickDone(_picked.length)),
                ),
              ),
            ),
    );
  }
}

/// Close (nothing is saved), the name and how many books are checked.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.picked});

  final String name;
  final int picked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          const CloseButton(),
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
                    fontSize: 19,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                Text(
                  l10n.collectionPickHint(picked),
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
