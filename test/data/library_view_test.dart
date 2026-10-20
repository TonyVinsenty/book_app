import 'dart:io';

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/collection_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 10, 1);

BookRow _book(
  int id, {
  String title = 'Книга',
  List<String> authors = const [],
  int words = 100,
  int position = 0,
  int? opened,
  int? finished,
  int added = 0,
  int? touched,
  StatusMark? mark,
}) => BookRow(
  id: id,
  title: title,
  authors: authors,
  sourceFormat: SourceFormat.txt,
  sourceName: '$id.txt',
  sourceSize: 1,
  sourceHash: '$id',
  parserVersion: 1,
  wordCount: words,
  positionWord: position,
  positionSection: 0,
  positionBlock: 0,
  positionChar: 0,
  addedAt: _day.add(Duration(hours: added)),
  openedAt: opened == null ? null : _day.add(Duration(hours: opened)),
  touchedAt: _day.add(Duration(hours: touched ?? opened ?? added)),
  finishedAt: finished == null ? null : _day.add(Duration(hours: finished)),
  statusMark: mark,
);

List<int> _ids(List<BookRow> books) => [for (final b in books) b.id];

List<String> _sorted(List<String> titles) {
  final keys = [for (final t in titles) (t, SortKey(t))]
    ..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final k in keys) k.$1];
}

void main() {
  group('SortKey', () {
    final cases = <String, List<String>>{
      'case and ё': ['ёж', 'Ель', 'Жук', 'еда'],
      'leading quotes and marks': ['«Яма»', '...Бег', '"Анна"', ' Вий'],
      'Cyrillic before Latin': ['Zoo', 'Alice', 'Ящик', 'Арбуз'],
      'numbers by value': ['Том 10', 'Том 2', 'Том 1', 'Том 02а'],
      'digits before letters': ['Альфа', '1984', '451 по Фаренгейту'],
      'shorter first': ['Война и мир', 'Война', 'Войнаx'],
    };
    final expected = <String, List<String>>{
      'case and ё': ['еда', 'ёж', 'Ель', 'Жук'],
      'leading quotes and marks': ['"Анна"', '...Бег', ' Вий', '«Яма»'],
      'Cyrillic before Latin': ['Арбуз', 'Ящик', 'Alice', 'Zoo'],
      'numbers by value': ['Том 1', 'Том 2', 'Том 02а', 'Том 10'],
      'digits before letters': ['451 по Фаренгейту', '1984', 'Альфа'],
      'shorter first': ['Война', 'Война и мир', 'Войнаx'],
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      test(key, () => expect(_sorted(value), expected[key]));
    }

    test('ё and е are equal', () {
      expect(SortKey('Ёлка').compareTo(SortKey('елка')), 0);
    });
  });

  test('surname of the first author', () {
    const cases = <List<String>, String?>{
      ['Лев Николаевич Толстой', 'Другой']: 'Толстой',
      ['Л. Н. Толстой']: 'Толстой',
      ['Толстой Л. Н.']: 'Толстой',
      ['Толстой, Лев']: 'Толстой',
      ['Lewis Carroll']: 'Carroll',
      ['Гомер']: 'Гомер',
      ['  ']: null,
      <String>[]: null,
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      expect(surnameOf(key), value, reason: '$key');
    }
  });

  test('percent read: rounded down, none for a book never opened', () {
    expect(percentRead(_book(1, position: 50)), isNull);
    expect(percentRead(_book(1, position: 0, opened: 1)), 0);
    expect(percentRead(_book(1, words: 1000, position: 996, opened: 1)), 99);
    expect(percentRead(_book(1, position: 100, opened: 1)), 100);
    expect(percentRead(_book(1, words: 0, opened: 1)), 0);
    expect(percentRead(_book(1, words: 10, position: 50, opened: 1)), 100);
  });

  test('status: read, then a mark, then opened, else new', () {
    const q = StatusMark.queued;
    const a = StatusMark.abandoned;
    final cases = <(int?, int?, StatusMark?), BookStatus>{
      (null, null, null): BookStatus.notStarted,
      (1, null, null): BookStatus.reading,
      (1, 2, null): BookStatus.finished,
      (null, 2, null): BookStatus.finished,
      (null, null, q): BookStatus.queued,
      (1, null, q): BookStatus.queued,
      (1, null, a): BookStatus.abandoned,
      (null, null, a): BookStatus.abandoned,
      // Never written together; the read mark wins.
      (1, 2, a): BookStatus.finished,
    };
    for (final MapEntry(key: (opened, finished, mark), :value)
        in cases.entries) {
      final book = _book(1, opened: opened, finished: finished, mark: mark);
      expect(statusOf(book), value, reason: '$opened $finished $mark');
    }
  });

  group('author key', () {
    void same(List<String> a, List<String> b) =>
        expect(authorKeyOf(a), authorKeyOf(b), reason: '$a = $b');
    void differs(List<String> a, List<String> b) =>
        expect(authorKeyOf(a), isNot(authorKeyOf(b)), reason: '$a ≠ $b');

    test('spellings of one author give one key', () {
      for (final other in [
        ['Л. Н. Толстой'],
        ['Толстой, Лев Николаевич'],
        ['Толстой Л. Н.'],
        ['Лев Николаевич Толстой'],
        ['лев толстой'],
        ['  Лев   Толстой '],
      ]) {
        same(['Лев Толстой'], other);
      }
      same(['Пётр Алексеев'], ['П. Алексеев']);
      same(['Фёдор Достоевский'], ['Федор Достоевский']);
      same(['Гомер'], ['гомер']);
    });

    test('namesakes are apart', () {
      differs(['Лев Толстой'], ['Алексей Толстой']);
      differs(['Лев Толстой'], ['Толстой']);
      differs(['Анна Ан'], ['Николай Ан']);
    });

    test('only the first author counts', () {
      same(['Аркадий Стругацкий', 'Борис Стругацкий'], ['А. Стругацкий']);
      differs(['Илья Ильф', 'Евгений Петров'], ['Евгений Петров']);
    });

    test('no author, or only initials', () {
      expect(authorKeyOf(const []), isNull);
      expect(authorKeyOf(const ['  ']), isNull);
      same(['А. Б.'], ['А. Б.']);
    });
  });

  group('groups', () {
    final books = [
      _book(1, title: 'Война и мир', authors: ['Толстой, Лев Николаевич']),
      _book(2, title: 'Анна Каренина', authors: ['Лев Толстой']),
      _book(3, title: 'Воскресение', authors: ['Л. Н. Толстой']),
      _book(4, title: 'Хаджи-Мурат', authors: ['Лев Толстой']),
      _book(5, title: 'Аэлита', authors: ['Алексей Толстой']),
      _book(6, title: 'Сказки'),
      _book(7, title: 'Бесы', authors: ['Достоевский Ф. М.']),
      _book(8, title: 'Alice', authors: ['Lewis Carroll']),
      _book(9, title: 'Песни', authors: ['  ']),
    ];
    List<(String?, bool, String)> groups(LibrarySort sort) => [
      for (final g in groupBooks(sortBooks(books, sort), sort))
        (g.author, g.hasHeader, _ids(g.books).join(' ')),
    ];

    test('by author: surname, then name; no author last', () {
      expect(groups(LibrarySort.author), [
        ('Достоевский Ф. М.', true, '7'),
        ('Алексей Толстой', true, '5'),
        ('Лев Толстой', true, '2 1 3 4'),
        ('Lewis Carroll', true, '8'),
        (null, true, '9 6'),
      ]);
    });

    test('other sorts: one group without a header', () {
      for (final sort in LibrarySort.values) {
        if (sort == LibrarySort.author) continue;
        final all = groups(sort);
        expect(all, hasLength(1), reason: sort.name);
        expect(all.single.$2, isFalse);
        expect(all.single.$3, _ids(sortBooks(books, sort)).join(' '));
      }
    });

    test('no books, no groups', () {
      expect(groupBooks(const [], LibrarySort.author), isEmpty);
      expect(groupBooks(const [], LibrarySort.recent), isEmpty);
    });

    test('the header is the most frequent spelling, else the first', () {
      final tie = [
        _book(1, title: 'Б', authors: ['Л. Толстой']),
        _book(2, title: 'А', authors: ['Лев Толстой']),
      ];
      final g = groupBooks(
        sortBooks(tie, LibrarySort.author),
        LibrarySort.author,
      );
      expect(g.single.author, 'Лев Толстой');
    });

    test('the view gives the groups of the shown books', () {
      final v = libraryViewOf(
        books: books,
        collections: const [],
        links: const [],
        shelf: Shelf.all,
        sort: LibrarySort.author,
      );
      expect(v.groups, hasLength(5));
      expect([for (final g in v.groups) ...g.books], v.books);
    });
  });

  group('shelves', () {
    final books = [
      _book(1),
      _book(2, opened: 1),
      _book(3, opened: 2, finished: 3),
      _book(4, finished: 4),
      _book(5, opened: 5, mark: StatusMark.queued),
    ];
    final links = [
      BookCollectionRow(bookId: 1, collectionId: 7, addedAt: _day),
      BookCollectionRow(bookId: 3, collectionId: 7, addedAt: _day),
      BookCollectionRow(bookId: 2, collectionId: 8, addedAt: _day),
    ];
    final cases = <Shelf, List<int>>{
      Shelf.all: [1, 2, 3, 4, 5],
      Shelf.reading: [2],
      Shelf.finished: [3, 4],
      Shelf.collection(7): [1, 3],
      Shelf.collection(9): [],
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      test(key.key, () {
        final shown = shelfBooks(books, key, LibrarySort.added, links);
        expect(_ids(shown)..sort(), value);
      });
    }
  });

  test('shelf and sort keys; unknown ones fall back', () {
    for (final shelf in [
      Shelf.all,
      Shelf.reading,
      Shelf.finished,
      Shelf.collection(12),
    ]) {
      expect(Shelf.fromKey(shelf.key), shelf);
    }
    for (final key in [null, '', 'c:', 'c:x', 'other']) {
      expect(Shelf.fromKey(key), Shelf.all, reason: '$key');
    }
    expect(Shelf.fromKey('c:12').collectionId, 12);
    for (final sort in LibrarySort.values) {
      expect(LibrarySort.fromKey(sort.name), sort);
    }
    expect(LibrarySort.fromKey('bad'), LibrarySort.recent);
    expect(LibrarySort.fromKey(null), LibrarySort.recent);
  });

  group('sorts', () {
    final books = [
      _book(1, title: 'Идиот', authors: ['Ф. М. Достоевский'], added: 1),
      _book(
        2,
        title: '«Анна Каренина»',
        authors: ['Лев Толстой'],
        added: 2,
        opened: 10,
        position: 30,
      ),
      _book(3, title: 'Alice', authors: ['Lewis Carroll'], added: 3),
      _book(
        4,
        title: 'Бесы',
        authors: ['Достоевский, Фёдор'],
        added: 4,
        opened: 5,
        position: 10,
        finished: 6,
      ),
      _book(5, title: 'Без автора', added: 5, opened: 7, position: 90),
      _book(6, title: 'Война и мир', authors: ['Толстой Л. Н.'], added: 6),
    ];
    final cases = <LibrarySort, List<int>>{
      LibrarySort.recent: [2, 5, 6, 4, 3, 1],
      LibrarySort.added: [6, 5, 4, 3, 2, 1],
      LibrarySort.title: [2, 5, 4, 6, 1, 3],
      // Достоевский Ф.: by title; Толстой Л.: by title; Carroll; no author
      // last.
      LibrarySort.author: [4, 1, 2, 6, 3, 5],
      LibrarySort.progress: [4, 5, 2, 6, 3, 1],
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      test(key.name, () => expect(_ids(sortBooks(books, key)), value));
    }

    test('equal keys: newest book first', () {
      final same = [_book(1), _book(3), _book(2)];
      expect(_ids(sortBooks(same, LibrarySort.title)), [3, 2, 1]);
    });
  });

  group('library view', () {
    final books = [
      _book(1, opened: 3),
      _book(2, opened: 5, finished: 6),
      _book(3),
    ];
    CollectionRow collection(int id, String name) =>
        CollectionRow(id: id, name: name, createdAt: _day);

    LibraryView view(
      Shelf shelf, {
      List<CollectionRow> collections = const [],
    }) => libraryViewOf(
      books: books,
      collections: collections,
      links: const [],
      shelf: shelf,
      sort: LibrarySort.recent,
    );

    test('"Продолжить" — the last opened unread book, on every shelf', () {
      // Book 2 was opened later but is read to the end.
      expect(view(Shelf.all).continueBook?.id, 1);
      expect(view(Shelf.reading).continueBook?.id, 1);
      expect(view(Shelf.finished).continueBook?.id, 1);
      final mine = [collection(4, 'Мои')];
      expect(view(Shelf.collection(4), collections: mine).continueBook?.id, 1);
    });

    test('"Продолжить" skips queued and abandoned books', () {
      final aside = libraryViewOf(
        books: [
          _book(1, opened: 1),
          _book(2, opened: 2, mark: StatusMark.abandoned),
          _book(3, opened: 3, mark: StatusMark.queued),
        ],
        collections: const [],
        links: const [],
        shelf: Shelf.all,
        sort: LibrarySort.recent,
      );
      expect(aside.continueBook?.id, 1);
    });

    test('no "Продолжить" when every opened book is read', () {
      final done = libraryViewOf(
        books: [_book(1, opened: 1, finished: 2), _book(2)],
        collections: const [],
        links: const [],
        shelf: Shelf.all,
        sort: LibrarySort.recent,
      );
      expect(done.continueBook, isNull);
    });

    test('no "Продолжить" before any book was opened', () {
      final fresh = libraryViewOf(
        books: [_book(1)],
        collections: const [],
        links: const [],
        shelf: Shelf.all,
        sort: LibrarySort.recent,
      );
      expect(fresh.continueBook, isNull);
      expect(fresh.libraryIsEmpty, isFalse);
    });

    test('a deleted collection falls back to Все', () {
      final v = view(Shelf.collection(9), collections: [collection(4, 'Мои')]);
      expect(v.shelf, Shelf.all);
      expect(v.books, hasLength(3));
    });

    test('collections by name', () {
      final v = view(
        Shelf.all,
        collections: [
          collection(1, 'Сказки'),
          collection(2, 'английские'),
          collection(3, 'Classics'),
          collection(4, 'Ёлки'),
        ],
      );
      expect([for (final c in v.collections) c.id], [2, 4, 1, 3]);
    });
  });

  test('provider: shelf and sort are stored settings', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        contentStoreProvider.overrideWithValue(
          ContentStore(Directory('${Directory.systemTemp.path}/none')),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final sub = container.listen(libraryViewProvider, (_, _) {});
    addTearDown(sub.close);
    Future<LibraryView> next() async {
      await pumpEventQueue();
      return sub.read().requireValue;
    }

    final first = await next();
    expect(first.shelf, Shelf.all);
    expect(first.sort, LibrarySort.recent);
    expect(first.libraryIsEmpty, isTrue);

    final c = await CollectionRepository(db).create('Мои');
    final settings = container.read(settingsRepositoryProvider);
    await chooseShelf(settings, Shelf.collection(c.id));
    await chooseSort(settings, LibrarySort.title);
    final chosen = await next();
    expect(chosen.shelf, Shelf.collection(c.id));
    expect(chosen.sort, LibrarySort.title);
  });
}
