import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the library list shows: everything, an automatic shelf or one of
/// the owner's collections (ADR 0005 addendum 2). Stored as [key].
final class Shelf {
  const Shelf._(this.key, [this.collectionId]);

  factory Shelf.collection(int id) => Shelf._('c:$id', id);

  /// Unknown or broken keys mean [all].
  factory Shelf.fromKey(String? key) {
    for (final shelf in const [all, reading, finished]) {
      if (shelf.key == key) return shelf;
    }
    final id = key != null && key.startsWith('c:')
        ? int.tryParse(key.substring(2))
        : null;
    return id == null ? all : Shelf.collection(id);
  }

  static const all = Shelf._('all');

  /// Opened and not read to the end.
  static const reading = Shelf._('reading');
  static const finished = Shelf._('finished');

  final String key;

  /// Set for a collection shelf.
  final int? collectionId;

  bool get isAutomatic => collectionId == null;

  /// "Продолжить" is shown here.
  bool get showsContinue => this == all || this == reading;

  bool holds(BookRow book, Set<int> collectionBooks) => switch (this) {
    all => true,
    reading => book.openedAt != null && book.finishedAt == null,
    finished => book.finishedAt != null,
    _ => collectionBooks.contains(book.id),
  };

  @override
  bool operator ==(Object other) => other is Shelf && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'Shelf($key)';
}

/// One order for every shelf; stored by name.
enum LibrarySort {
  /// Last added, opened or imported again first.
  recent,
  added,
  title,

  /// By the surname of the first author; books without one at the end.
  author,

  /// Most read first; read books count as 100%.
  progress;

  /// Unknown or broken names mean [recent].
  static LibrarySort fromKey(String? key) =>
      values.firstWhere((s) => s.name == key, orElse: () => recent);
}

/// Whole percent read, rounded down (99.6% is not 100%); null for a book
/// never opened.
int? percentRead(BookRow book) {
  if (book.openedAt == null) return null;
  if (book.wordCount <= 0) return 0;
  return (book.positionWord * 100 ~/ book.wordCount).clamp(0, 100);
}

/// The books of [shelf] in [sort] order. [links] — all book-in-collection
/// rows.
List<BookRow> shelfBooks(
  List<BookRow> books,
  Shelf shelf,
  LibrarySort sort,
  List<BookCollectionRow> links,
) {
  final inCollection = {
    for (final l in links)
      if (l.collectionId == shelf.collectionId) l.bookId,
  };
  final shown = [
    for (final b in books)
      if (shelf.holds(b, inCollection)) b,
  ];
  return sortBooks(shown, sort);
}

List<BookRow> sortBooks(List<BookRow> books, LibrarySort sort) {
  final Comparator<BookRow> order;
  switch (sort) {
    case LibrarySort.recent:
      order = (a, b) => b.touchedAt.compareTo(a.touchedAt);
    case LibrarySort.added:
      order = (a, b) => b.addedAt.compareTo(a.addedAt);
    case LibrarySort.title:
      final keys = {for (final b in books) b.id: SortKey(b.title)};
      order = (a, b) => keys[a.id]!.compareTo(keys[b.id]!);
    case LibrarySort.author:
      final keys = {
        for (final b in books)
          b.id: (
            surname: switch (surnameOf(b.authors)) {
              final s? => SortKey(s),
              null => null,
            },
            author: SortKey(b.authors.firstOrNull ?? ''),
            title: SortKey(b.title),
          ),
      };
      order = (a, b) {
        final ka = keys[a.id]!;
        final kb = keys[b.id]!;
        final byName = switch ((ka.surname, kb.surname)) {
          (null, null) => 0,
          (null, _) => 1,
          (_, null) => -1,
          (final x?, final y?) => x.compareTo(y),
        };
        if (byName != 0) return byName;
        final byAuthor = ka.author.compareTo(kb.author);
        if (byAuthor != 0) return byAuthor;
        return ka.title.compareTo(kb.title);
      };
    case LibrarySort.progress:
      double share(BookRow b) => b.finishedAt != null ? 1 : b.progress;
      order = (a, b) => share(b).compareTo(share(a));
  }
  return [...books]..sort((a, b) {
    final c = order(a, b);
    return c != 0 ? c : b.id.compareTo(a.id);
  });
}

/// Surname of the first author: the part before a comma ("Толстой, Лев"),
/// else the last word that is not an initial ("Л. Н. Толстой",
/// "Толстой Л. Н."); null when there is no author.
String? surnameOf(List<String> authors) {
  final first = authors.firstOrNull?.trim() ?? '';
  if (first.isEmpty) return null;
  final comma = first.indexOf(',');
  if (comma > 0) return first.substring(0, comma).trim();
  final words = first.split(RegExp(r'\s+'));
  final names = [
    for (final w in words)
      if (!_initial.hasMatch(w)) w,
  ];
  return names.isEmpty ? first : names.last;
}

final _initial = RegExp(r'^\p{L}{1,2}\.$', unicode: true);

/// A string compared the Russian way: no case, «ё» = «е», leading quotes
/// and marks skipped, Cyrillic before Latin, numbers by value ("2" < "10").
final class SortKey implements Comparable<SortKey> {
  SortKey(String text) : _s = _normal(text);

  final String _s;

  static String _normal(String text) {
    final lower = text.toLowerCase().replaceAll('ё', 'е');
    final start = lower.indexOf(RegExp(r'[\p{L}\p{N}]', unicode: true));
    return start < 0 ? lower.trim() : lower.substring(start);
  }

  @override
  int compareTo(SortKey other) {
    final a = _s;
    final b = other._s;
    var i = 0;
    var j = 0;
    while (i < a.length && j < b.length) {
      final ca = a.codeUnitAt(i);
      final cb = b.codeUnitAt(j);
      if (_isDigit(ca) && _isDigit(cb)) {
        final ei = _digitsEnd(a, i);
        final ej = _digitsEnd(b, j);
        final c = _compareNumbers(a.substring(i, ei), b.substring(j, ej));
        if (c != 0) return c;
        i = ei;
        j = ej;
        continue;
      }
      final byClass = _class(ca).compareTo(_class(cb));
      if (byClass != 0) return byClass;
      if (ca != cb) return ca.compareTo(cb);
      i++;
      j++;
    }
    return (a.length - i).compareTo(b.length - j);
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  static int _digitsEnd(String s, int from) {
    var i = from;
    while (i < s.length && _isDigit(s.codeUnitAt(i))) {
      i++;
    }
    return i;
  }

  static int _compareNumbers(String a, String b) {
    final x = a.replaceFirst(RegExp('^0+(?=.)'), '');
    final y = b.replaceFirst(RegExp('^0+(?=.)'), '');
    if (x.length != y.length) return x.length.compareTo(y.length);
    return x.compareTo(y);
  }

  /// Spaces and marks, digits, Cyrillic, Latin, other letters.
  static int _class(int c) {
    if (_isDigit(c)) return 1;
    if (c >= 0x0400 && c <= 0x04FF) return 2;
    if (c >= 0x61 && c <= 0x7A) return 3;
    if (c < 0x80 || (c >= 0x2000 && c <= 0x206F)) return 0;
    return 4;
  }

  @override
  String toString() => 'SortKey($_s)';
}

/// What the library screen shows.
final class LibraryView {
  const LibraryView({
    required this.shelf,
    required this.sort,
    required this.books,
    required this.collections,
    required this.continueBook,
    required this.libraryIsEmpty,
  });

  /// The chosen shelf; a deleted collection falls back to "Все".
  final Shelf shelf;
  final LibrarySort sort;

  /// Books of [shelf] in [sort] order.
  final List<BookRow> books;

  /// The owner's collections by name.
  final List<CollectionRow> collections;

  /// "Продолжить": the last opened book, on shelves that show it.
  final BookRow? continueBook;

  final bool libraryIsEmpty;
}

LibraryView libraryViewOf({
  required List<BookRow> books,
  required List<CollectionRow> collections,
  required List<BookCollectionRow> links,
  required Shelf shelf,
  required LibrarySort sort,
}) {
  final known =
      shelf.isAutomatic || collections.any((c) => c.id == shelf.collectionId);
  final shown = known ? shelf : Shelf.all;
  final names = {for (final c in collections) c.id: SortKey(c.name)};
  BookRow? last;
  for (final b in books) {
    final opened = b.openedAt;
    if (opened == null) continue;
    if (last == null || opened.isAfter(last.openedAt!)) last = b;
  }
  return LibraryView(
    shelf: shown,
    sort: sort,
    books: shelfBooks(books, shown, sort, links),
    collections: [...collections]
      ..sort((a, b) {
        final c = names[a.id]!.compareTo(names[b.id]!);
        return c != 0 ? c : a.id.compareTo(b.id);
      }),
    continueBook: shown.showsContinue ? last : null,
    libraryIsEmpty: books.isEmpty,
  );
}

final libraryShelfProvider = StreamProvider<Shelf>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.libraryShelf)
      .map(Shelf.fromKey),
);

final librarySortProvider = StreamProvider<LibrarySort>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.librarySort)
      .map(LibrarySort.fromKey),
);

Future<void> chooseShelf(SettingsRepository settings, Shelf shelf) =>
    settings.set(SettingKeys.libraryShelf, shelf.key);

Future<void> chooseSort(SettingsRepository settings, LibrarySort sort) =>
    settings.set(SettingKeys.librarySort, sort.name);

/// Everything the library screen shows; loading until every part came once.
final libraryViewProvider = Provider<AsyncValue<LibraryView>>((ref) {
  final books = ref.watch(booksProvider);
  final collections = ref.watch(collectionsProvider);
  final links = ref.watch(collectionLinksProvider);
  final shelf = ref.watch(libraryShelfProvider);
  final sort = ref.watch(librarySortProvider);
  for (final part in [books, collections, links, shelf, sort]) {
    if (part case AsyncError(:final error, :final stackTrace)) {
      return AsyncError(error, stackTrace);
    }
    if (!part.hasValue) return const AsyncLoading();
  }
  return AsyncData(
    libraryViewOf(
      books: books.requireValue,
      collections: collections.requireValue,
      links: links.requireValue,
      shelf: shelf.requireValue,
      sort: sort.requireValue,
    ),
  );
});
