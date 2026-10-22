import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which books the library shows (ADR 0005 addendum 3): those with
/// [status] (null — any) in the collection [collectionId] (null — all
/// books). Stored as `library.status` and `library.collection`.
@immutable
final class LibraryFilter {
  const LibraryFilter({this.status, this.collectionId});

  /// Unknown or broken values mean "any".
  factory LibraryFilter.fromStored(Map<String, String> stored) => LibraryFilter(
    status: BookStatus.values.asNameMap()[stored[SettingKeys.libraryStatus]],
    collectionId: int.tryParse(stored[SettingKeys.libraryCollection] ?? ''),
  );

  /// The shelf stored before statuses: `reading`, `finished` or
  /// `c:<collection id>`; anything else is [all].
  factory LibraryFilter.fromShelf(String? key) => switch (key) {
    'reading' => const LibraryFilter(status: BookStatus.reading),
    'finished' => const LibraryFilter(status: BookStatus.finished),
    final String k when k.startsWith('c:') => LibraryFilter(
      collectionId: int.tryParse(k.substring(2)),
    ),
    _ => all,
  };

  static const all = LibraryFilter();

  final BookStatus? status;
  final int? collectionId;

  LibraryFilter withStatus(BookStatus? status) =>
      LibraryFilter(status: status, collectionId: collectionId);

  LibraryFilter withCollection(int? id) =>
      LibraryFilter(status: status, collectionId: id);

  /// The settings to write; null — remove.
  Map<String, String?> get stored => {
    SettingKeys.libraryStatus: status?.name,
    SettingKeys.libraryCollection: collectionId?.toString(),
  };

  bool holds(BookRow book, Set<int> collectionBooks) =>
      (status == null || statusOf(book) == status) &&
      (collectionId == null || collectionBooks.contains(book.id));

  @override
  bool operator ==(Object other) =>
      other is LibraryFilter &&
      other.status == status &&
      other.collectionId == collectionId;

  @override
  int get hashCode => Object.hash(status, collectionId);

  @override
  String toString() => 'LibraryFilter($status, $collectionId)';
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

/// Books as rows or as a grid of covers, three in a row; stored by name.
enum LibraryLayout {
  list,
  grid;

  /// Unknown or broken names mean [list].
  static LibraryLayout fromKey(String? key) =>
      values.firstWhere((l) => l.name == key, orElse: () => list);
}

/// The one status of a book (ADR 0005 addendum 3). Only "queued" and
/// "abandoned" are stored as such; the others follow from the dates.
enum BookStatus { notStarted, reading, queued, abandoned, finished }

BookStatus statusOf(BookRow book) {
  if (book.finishedAt != null) return BookStatus.finished;
  return switch (book.statusMark) {
    StatusMark.queued => BookStatus.queued,
    StatusMark.abandoned => BookStatus.abandoned,
    null => book.openedAt != null ? BookStatus.reading : BookStatus.notStarted,
  };
}

/// Whole percent read, rounded down (99.6% is not 100%); null for a book
/// never opened.
int? percentRead(BookRow book) {
  if (book.openedAt == null) return null;
  return percentOf(book.positionWord, book.wordCount);
}

/// Whole percent of [wordCount] words read up to [word], rounded down.
int percentOf(int word, int wordCount) =>
    wordCount <= 0 ? 0 : (word * 100 ~/ wordCount).clamp(0, 100);

/// The books of [filter] in [sort] order. [links] — all book-in-collection
/// rows.
List<BookRow> filterBooks(
  List<BookRow> books,
  LibraryFilter filter,
  LibrarySort sort,
  List<BookCollectionRow> links,
) {
  final inCollection = _booksOf(filter.collectionId, links);
  final shown = [
    for (final b in books)
      if (filter.holds(b, inCollection)) b,
  ];
  return sortBooks(shown, sort);
}

Set<int> _booksOf(int? collectionId, List<BookCollectionRow> links) => {
  for (final l in links)
    if (l.collectionId == collectionId) l.bookId,
};

/// How many books of each status the collection [collectionId] (null — the
/// library) has; every status is there, 0 for none.
Map<BookStatus, int> statusCounts(
  List<BookRow> books,
  int? collectionId,
  List<BookCollectionRow> links,
) {
  final inCollection = _booksOf(collectionId, links);
  final counts = {for (final s in BookStatus.values) s: 0};
  for (final b in books) {
    if (collectionId == null || inCollection.contains(b.id)) {
      counts.update(statusOf(b), (n) => n + 1);
    }
  }
  return counts;
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
          b.id: (author: authorKeyOf(b.authors), title: SortKey(b.title)),
      };
      order = (a, b) {
        final ka = keys[a.id]!;
        final kb = keys[b.id]!;
        final byAuthor = _compareAuthors(ka.author, kb.author);
        return byAuthor != 0 ? byAuthor : ka.title.compareTo(kb.title);
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

/// Books by one author come together: by [authorKeyOf], books without an
/// author last.
int _compareAuthors(AuthorKey? a, AuthorKey? b) => switch ((a, b)) {
  (null, null) => 0,
  (null, _) => 1,
  (_, null) => -1,
  (final x?, final y?) => switch (x.surname.compareTo(y.surname)) {
    0 => x.initial.compareTo(y.initial),
    final c => c,
  },
};

/// Who a book is grouped under: the surname and the first letter of the
/// given name of the first author.
typedef AuthorKey = ({SortKey surname, SortKey initial});

/// "Лев Толстой", "Л. Н. Толстой" and "Толстой, Лев Николаевич" give one key,
/// "Алексей Толстой" another; null when there is no author.
AuthorKey? authorKeyOf(List<String> authors) {
  final first = authors.firstOrNull?.trim() ?? '';
  if (first.isEmpty) return null;
  final (:surname, :given) = _nameOf(first);
  final letter = _letter.firstMatch(given.join(' '))?[0] ?? '';
  return (surname: SortKey(surname), initial: SortKey(letter));
}

/// Books under one header: an author when sorted by author, else one group
/// of all books without a header.
final class BookGroup {
  const BookGroup.all(this.books) : author = null, hasHeader = false;
  const BookGroup.author(String this.author, this.books) : hasHeader = true;
  const BookGroup.noAuthor(this.books) : author = null, hasHeader = true;

  /// The most frequent spelling of the author in the group as "Фамилия
  /// И. О." ([authorHeaderOf]); null for [BookGroup.all] and "Без автора".
  final String? author;
  final bool hasHeader;
  final List<BookRow> books;
}

/// [sorted] in groups: by author for [LibrarySort.author] (its order already
/// puts them together), else one group; none for no books.
List<BookGroup> groupBooks(List<BookRow> sorted, LibrarySort sort) {
  if (sorted.isEmpty) return const [];
  if (sort != LibrarySort.author) return [BookGroup.all(sorted)];
  final groups = <BookGroup>[];
  var start = 0;
  AuthorKey? key = authorKeyOf(sorted.first.authors);
  void close(int end) {
    final books = sorted.sublist(start, end);
    groups.add(
      key == null
          ? BookGroup.noAuthor(books)
          : BookGroup.author(authorHeaderOf(_mostFrequentAuthor(books)), books),
    );
  }

  for (var i = 1; i < sorted.length; i++) {
    final next = authorKeyOf(sorted[i].authors);
    if (_compareAuthors(key, next) == 0) continue;
    close(i);
    start = i;
    key = next;
  }
  close(sorted.length);
  return groups;
}

/// Ties go to the spelling seen first (the first book by title).
String _mostFrequentAuthor(List<BookRow> books) {
  final counts = <String, int>{};
  for (final b in books) {
    final name = b.authors.first.trim();
    counts[name] = (counts[name] ?? 0) + 1;
  }
  var best = counts.keys.first;
  for (final MapEntry(:key, :value) in counts.entries) {
    if (value > counts[best]!) best = key;
  }
  return best;
}

/// "Фамилия И. О.": "Лев Николаевич Толстой", "Л. Н. Толстой" and "Толстой,
/// Лев Николаевич" all give "Толстой Л. Н."; a name of initials only stays.
String authorHeaderOf(String name) {
  final full = name.trim();
  if (full.isEmpty) return full;
  final (:surname, :given) = _nameOf(full);
  if (surname == full) return full;
  final initials = [
    for (final w in given)
      if (_letter.firstMatch(w)?[0] case final l?) '${l.toUpperCase()}.',
  ];
  return initials.isEmpty ? surname : '$surname ${initials.join(' ')}';
}

/// Surname of the first author ([_nameOf]); null when there is no author.
String? surnameOf(List<String> authors) {
  final first = authors.firstOrNull?.trim() ?? '';
  return first.isEmpty ? null : _nameOf(first).surname;
}

/// The surname and the other words of one name: the part before a comma
/// ("Толстой, Лев"); the first word before a given name and patronymic
/// ("Толстой Лев Николаевич") or before a known given name ("Достоевский
/// Фёдор"); else the last word that is not an initial ("Л. Н. Толстой",
/// "Толстой Л. Н."). With only initials ("А. Б.") the surname is the
/// whole name.
({String surname, List<String> given}) _nameOf(String name) {
  final comma = name.indexOf(',');
  if (comma > 0) {
    final rest = name.substring(comma + 1).trim();
    return (
      surname: name.substring(0, comma).trim(),
      given: rest.isEmpty ? const [] : rest.split(_spaces),
    );
  }
  final words = name.split(_spaces);
  final names = [
    for (var i = 0; i < words.length; i++)
      if (!_initial.hasMatch(words[i])) i,
  ];
  if (names.isEmpty) return (surname: name, given: words);
  bool given(int i) => _givenNames.contains(SortKey(words[i]));
  final surnameFirst = switch (names.length) {
    1 => false,
    2 => given(names.last) && !given(names.first),
    _ => _patronymic.hasMatch(words[names.last]) && !given(names.first),
  };
  final at = surnameFirst ? names.first : names.last;
  return (surname: words[at], given: [...words]..removeAt(at));
}

final _spaces = RegExp(r'\s+');
final _patronymic = RegExp(
  r'(вич|вна|ична|ьич|оглы|кызы)$',
  caseSensitive: false,
);

/// Common given names, to tell "Фамилия Имя" from "Имя Фамилия".
final Set<SortKey> _givenNames = {
  for (final n in const [
    // Russian, male.
    'александр', 'алексей', 'анатолий', 'андрей', 'антон', 'аркадий',
    'арсений', 'артем', 'афанасий', 'борис', 'вадим', 'валентин', 'валерий',
    'василий', 'вениамин', 'виктор', 'виталий', 'владимир', 'владислав',
    'всеволод', 'вячеслав', 'гавриил', 'гаврила', 'геннадий', 'георгий',
    'глеб', 'григорий', 'даниил', 'денис', 'дмитрий', 'евгений', 'егор',
    'ефим', 'захар', 'иван', 'игорь', 'илья', 'иосиф', 'кирилл',
    'константин', 'лев', 'леонид', 'максим', 'марк', 'михаил', 'николай',
    'олег', 'осип', 'павел', 'петр', 'роман', 'савва', 'самуил', 'семен',
    'сергей', 'станислав', 'степан', 'тарас', 'тимофей', 'федор', 'филипп',
    'эдуард', 'юрий', 'яков', 'ян',
    // Russian, female.
    'агния', 'александра', 'алла', 'анастасия', 'анна', 'валентина',
    'варвара', 'вера', 'виктория', 'галина', 'дарья', 'евгения',
    'екатерина', 'елена', 'елизавета', 'зинаида', 'зоя', 'ирина', 'клавдия',
    'ксения', 'лариса', 'лидия', 'любовь', 'людмила', 'маргарита', 'марина',
    'мария', 'марфа', 'надежда', 'наталия', 'наталья', 'нина', 'ольга',
    'полина', 'светлана', 'софия', 'софья', 'тамара', 'татьяна', 'юлия',
    // Latin script.
    'agatha', 'alexandre', 'anna', 'anne', 'arthur', 'charles', 'charlotte',
    'david', 'edith', 'edward', 'elizabeth', 'emile', 'emily', 'francis',
    'frank', 'franz', 'friedrich', 'george', 'gustave', 'henry', 'herbert',
    'honore', 'jack', 'james', 'jane', 'jean', 'johann', 'john', 'joseph',
    'jules', 'karl', 'louisa', 'marcel', 'mark', 'mary', 'michael', 'oscar',
    'paul', 'peter', 'pierre', 'richard', 'robert', 'stefan', 'thomas',
    'victor', 'virginia', 'walter', 'william',
  ])
    SortKey(n),
};

final _initial = RegExp(r'^\p{L}{1,2}\.$', unicode: true);
final _letter = RegExp(r'\p{L}', unicode: true);

/// A string compared the Russian way: no case, «ё» = «е», leading quotes
/// and marks skipped, Cyrillic before Latin, numbers by value ("2" < "10").
final class SortKey implements Comparable<SortKey> {
  SortKey(String text) : _s = _normal(text);

  final String _s;

  static String _normal(String text) {
    final lower = _foldLatin(text.toLowerCase().replaceAll('ё', 'е'));
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

  /// "é" sorts as "e", "ß" as "ss": Latin letters with marks stay with
  /// their plain letter.
  static String _foldLatin(String s) {
    if (!s.contains(_marked)) return s;
    final out = StringBuffer();
    for (final rune in s.runes) {
      final c = String.fromCharCode(rune);
      out.write(_latinFold[c] ?? c);
    }
    return out.toString();
  }

  static final _marked = RegExp('[\u00C0-\u024F]');

  static final Map<String, String> _latinFold = {
    for (final (plain, marked) in const [
      ('a', 'àáâãäåāăą'),
      ('c', 'çćĉċč'),
      ('d', 'ďđ'),
      ('e', 'èéêëēĕėęě'),
      ('g', 'ĝğġģ'),
      ('h', 'ĥħ'),
      ('i', 'ìíîïĩīĭįı'),
      ('j', 'ĵ'),
      ('k', 'ķ'),
      ('l', 'ĺļľŀł'),
      ('n', 'ñńņň'),
      ('o', 'òóôõöøōŏő'),
      ('r', 'ŕŗř'),
      ('s', 'śŝşš'),
      ('t', 'ţťŧ'),
      ('u', 'ùúûüũūŭůűų'),
      ('y', 'ýÿŷ'),
      ('z', 'źżž'),
      ('ss', 'ß'),
      ('ae', 'æ'),
      ('oe', 'œ'),
    ])
      for (final m in marked.split('')) m: plain,
  };

  @override
  bool operator ==(Object other) => other is SortKey && other._s == _s;

  @override
  int get hashCode => _s.hashCode;

  @override
  String toString() => 'SortKey($_s)';
}

/// What the library screen shows.
final class LibraryView {
  const LibraryView({
    required this.filter,
    required this.sort,
    this.layout = LibraryLayout.list,
    required this.books,
    required this.groups,
    required this.collections,
    required this.continueBook,
    required this.libraryIsEmpty,
    this.statusCounts = const {},
    this.collectionBooks = const {},
  });

  /// The chosen filter; a deleted collection falls back to all books.
  final LibraryFilter filter;
  final LibrarySort sort;
  final LibraryLayout layout;

  /// Books of [filter] in [sort] order.
  final List<BookRow> books;

  /// [books] under headers: by author for [LibrarySort.author], else one
  /// group without a header; empty when there are no books.
  final List<BookGroup> groups;

  /// The owner's collections by name.
  final List<CollectionRow> collections;

  /// "Продолжить": the last opened book with the status "Читаю". The same on
  /// every shelf, so switching shelves does not move them (owner,
  /// 2026-10-20).
  final BookRow? continueBook;

  final bool libraryIsEmpty;

  /// Books of each status in the chosen collection (or the library),
  /// whatever the chosen status.
  final Map<BookStatus, int> statusCounts;

  /// Books of every collection (by id) in [sort] order, whatever the
  /// filter; a collection without books is missing.
  final Map<int, List<BookRow>> collectionBooks;
}

LibraryView libraryViewOf({
  required List<BookRow> books,
  required List<CollectionRow> collections,
  required List<BookCollectionRow> links,
  required LibraryFilter filter,
  required LibrarySort sort,
  LibraryLayout layout = LibraryLayout.list,
}) {
  final collectionId = filter.collectionId;
  final shown =
      collectionId == null || collections.any((c) => c.id == collectionId)
      ? filter
      : filter.withCollection(null);
  final names = {for (final c in collections) c.id: SortKey(c.name)};
  final shownBooks = filterBooks(books, shown, sort, links);
  final byId = {for (final b in books) b.id: b};
  final inCollections = <int, List<BookRow>>{};
  for (final l in links) {
    if (byId[l.bookId] case final book?) {
      (inCollections[l.collectionId] ??= []).add(book);
    }
  }
  BookRow? last;
  for (final b in books) {
    final opened = b.openedAt;
    if (opened == null || statusOf(b) != BookStatus.reading) continue;
    if (last == null || opened.isAfter(last.openedAt!)) last = b;
  }
  return LibraryView(
    filter: shown,
    sort: sort,
    layout: layout,
    books: shownBooks,
    groups: groupBooks(shownBooks, sort),
    collections: [...collections]
      ..sort((a, b) {
        final c = names[a.id]!.compareTo(names[b.id]!);
        return c != 0 ? c : a.id.compareTo(b.id);
      }),
    continueBook: last,
    libraryIsEmpty: books.isEmpty,
    statusCounts: statusCounts(books, shown.collectionId, links),
    collectionBooks: {
      for (final MapEntry(:key, :value) in inCollections.entries)
        key: sortBooks(value, sort),
    },
  );
}

final libraryFilterProvider = StreamProvider<LibraryFilter>((ref) async* {
  final settings = ref.watch(settingsRepositoryProvider);
  await moveOldShelf(settings);
  yield* settings
      .watchKeys([SettingKeys.libraryStatus, SettingKeys.libraryCollection])
      .map(LibraryFilter.fromStored);
});

/// Once: the shelf chosen before statuses becomes the filter (ADR 0005
/// addendum 3).
Future<void> moveOldShelf(SettingsRepository settings) async {
  final shelf = await settings.get(SettingKeys.libraryShelf);
  if (shelf == null) return;
  await settings.setAll({
    ...LibraryFilter.fromShelf(shelf).stored,
    SettingKeys.libraryShelf: null,
  });
}

final librarySortProvider = StreamProvider<LibrarySort>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.librarySort)
      .map(LibrarySort.fromKey),
);

final libraryLayoutProvider = StreamProvider<LibraryLayout>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.libraryLayout)
      .map(LibraryLayout.fromKey),
);

Future<void> chooseFilter(SettingsRepository settings, LibraryFilter filter) =>
    settings.setAll(filter.stored);

Future<void> chooseSort(SettingsRepository settings, LibrarySort sort) =>
    settings.set(SettingKeys.librarySort, sort.name);

Future<void> chooseLayout(SettingsRepository settings, LibraryLayout layout) =>
    settings.set(SettingKeys.libraryLayout, layout.name);

/// The library tab: the whole library with the stored status. The stored
/// collection is not used there: a collection opens on its own screen
/// ([collectionViewProvider]).
final libraryViewProvider = Provider<AsyncValue<LibraryView>>(
  (ref) => _viewOf(
    ref,
    ref.watch(libraryFilterProvider).whenData((f) => f.withCollection(null)),
  ),
);

/// A collection screen: its books with [LibraryFilter.status] (chosen on
/// that screen, not stored).
final collectionViewProvider = Provider.autoDispose
    .family<AsyncValue<LibraryView>, LibraryFilter>(
      (ref, filter) => _viewOf(ref, AsyncData(filter)),
    );

/// Loading until every part came once.
AsyncValue<LibraryView> _viewOf(Ref ref, AsyncValue<LibraryFilter> filter) {
  final books = ref.watch(booksProvider);
  final collections = ref.watch(collectionsProvider);
  final links = ref.watch(collectionLinksProvider);
  final sort = ref.watch(librarySortProvider);
  final layout = ref.watch(libraryLayoutProvider);
  for (final part in [books, collections, links, filter, sort, layout]) {
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
      filter: filter.requireValue,
      sort: sort.requireValue,
      layout: layout.requireValue,
    ),
  );
}
