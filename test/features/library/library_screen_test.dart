import 'dart:io';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/features/library/book_shelf.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/library/collection_screen.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:drift/drift.dart'
    show DatabaseConnection, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_importer.dart';

final _day = DateTime(2026, 10, 1);

BookRow _book(
  int id, {
  required String title,
  List<String> authors = const [],
  int position = 0,
  int? opened,
  int? finished,
  int added = 0,
}) => BookRow(
  id: id,
  title: title,
  authors: authors,
  sourceFormat: SourceFormat.txt,
  sourceName: '$id.txt',
  sourceSize: 1,
  sourceHash: '$id',
  parserVersion: 1,
  wordCount: 100,
  positionWord: position,
  positionSection: 0,
  positionBlock: 0,
  positionChar: 0,
  addedAt: _day.add(Duration(hours: added)),
  openedAt: opened == null ? null : _day.add(Duration(hours: opened)),
  touchedAt: _day.add(Duration(hours: opened ?? added)),
  finishedAt: finished == null ? null : _day.add(Duration(hours: finished)),
);

void main() {
  // Each test opens its own in-memory database.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temp;
  late FakeImporter importer;
  late AppDatabase db;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('library_');
    importer = FakeImporter()..hold = true;
    // Closing a drift database under fake time hangs, so it is left open;
    // synchronous stream closing leaves no pending timer.
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => temp.deleteSync(recursive: true));

  /// Lets real async work (file deletion, database) run.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  Future<void> pumpLibrary(
    WidgetTester tester, {
    List<String> picked = const [],
    List<BookRow> books = const [],
    List<CollectionRow> collections = const [],
    List<BookCollectionRow> links = const [],
    bool live = false,
  }) async {
    final paths = [
      for (final name in picked)
        (File('${temp.path}/$name')..writeAsStringSync('x')).path,
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bookRepositoryProvider.overrideWithValue(
            BookRepository(db, ContentStore(Directory('${temp.path}/books'))),
          ),
          // Live: books, collections and links come from the database.
          if (!live) ...[
            booksProvider.overrideWithValue(AsyncData(books)),
            collectionsProvider.overrideWithValue(AsyncData(collections)),
            collectionLinksProvider.overrideWithValue(AsyncData(links)),
          ],
          bookImporterProvider.overrideWithValue(importer),
          pickBooksProvider.overrideWithValue(() async => paths),
        ],
        child: MaterialApp(
          theme: buildAppTheme(ReadingPalette.paper, night: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LibraryScreen(),
        ),
      ),
    );
    for (
      var i = 0;
      i < 50 &&
          find.byType(ShelfBar).evaluate().isEmpty &&
          find.text('Здесь появятся ваши книги').evaluate().isEmpty;
      i++
    ) {
      await settle(tester);
    }
    await settle(tester);
  }

  Future<String?> stored(WidgetTester tester, String key) =>
      tester.runAsync(() => SettingsRepository(db).get(key)).then((v) => v);

  Future<void> release(WidgetTester tester) async {
    await tester.runAsync(importer.release);
    await settle(tester);
  }

  /// Titles of the shown books, top to bottom.
  List<String> titles(WidgetTester tester, Type tile) => [
    for (final e in find.byType(tile).evaluate())
      switch (e.widget) {
        BookTile(:final title) || BookGridTile(:final title) => title,
        _ => '',
      },
  ];

  final shelfBooks = [
    _book(1, title: 'Война и мир', authors: ['Л. Н. Толстой'], added: 1),
    _book(
      2,
      title: 'Анна Каренина',
      authors: ['Л. Н. Толстой'],
      position: 42,
      opened: 5,
      added: 2,
    ),
    _book(3, title: 'Шинель', position: 100, opened: 3, finished: 4, added: 3),
  ];

  group('import', () {
    testWidgets('shows progress, then a summary with details', (tester) async {
      await pumpLibrary(tester, picked: ['a.txt', 'dup.txt', 'bad.txt']);
      await tester.tap(find.text('Добавить книгу'));
      await settle(tester);

      expect(find.text('Добавляется 1 из 3: a.txt'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // The picker waits until the queue is done.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FloatingActionButton), findsNothing);

      await release(tester);
      expect(find.text('Добавляется 2 из 3: dup.txt'), findsOneWidget);
      await release(tester);
      await release(tester);
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.text(
          'Добавлено книг: 1, уже были в библиотеке: 1, '
          'не удалось добавить: 1',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Подробнее'));
      await tester.pumpAndSettle();
      expect(find.text('Добавление книг'), findsOneWidget);
      expect(find.text('Добавлена'), findsOneWidget);
      expect(find.text('Уже была в библиотеке'), findsOneWidget);
      expect(find.text('Файл повреждён'), findsOneWidget);
      expect(find.text('bad.txt'), findsOneWidget);
    });

    testWidgets('one file: its own message, no details', (tester) async {
      await pumpLibrary(tester, picked: ['bad.fb2']);
      await tester.tap(find.text('Добавить книгу'));
      await settle(tester);
      await release(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Файл повреждён, книгу не удалось прочитать: bad.fb2'),
        findsOneWidget,
      );
      expect(find.text('Подробнее'), findsNothing);
    });

    testWidgets('a cancelled pick does nothing', (tester) async {
      await pumpLibrary(tester);
      await tester.tap(find.text('Добавить книгу'));
      await settle(tester);

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  /// Room for every book of a test.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder inRow(String title, Finder what) => find.descendant(
    of: find.ancestor(
      of: find.text(title),
      matching: find.byWidgetPredicate(
        (w) => w is BookTile || w is BookGridTile,
      ),
    ),
    matching: what,
  );

  /// Opens the status sheet and picks [name] in it.
  Future<void> chooseStatus(WidgetTester tester, String name) async {
    await tester.tap(
      find
          .descendant(of: find.byType(ShelfBar), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Статус книги'), findsOneWidget);
    final item = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(name),
    );
    // The sheet scrolls on a low screen.
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await settle(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('rows show the status of every book', (tester) async {
    tall(tester);
    await pumpLibrary(
      tester,
      books: [
        ...shelfBooks,
        _book(
          4,
          title: 'Бесы',
          opened: 1,
          added: 4,
        ).copyWith(statusMark: const Value(StatusMark.queued)),
        _book(
          5,
          title: 'Идиот',
          opened: 2,
          added: 5,
        ).copyWith(statusMark: const Value(StatusMark.abandoned)),
      ],
    );

    expect(find.text('Все · 5'), findsOneWidget);
    expect(inRow('Анна Каренина', find.text('Читаю · 42 %')), findsOneWidget);
    expect(inRow('Шинель', find.text('Прочитано')), findsOneWidget);
    expect(inRow('Война и мир', find.text('Новая')), findsOneWidget);
    expect(inRow('Бесы', find.text('На очереди')), findsOneWidget);
    expect(inRow('Идиот', find.text('Брошена')), findsOneWidget);

    // "Продолжить" is the book opened last of those being read.
    final card = find.byType(ContinueCard);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Анна Каренина')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('42 %')),
      findsOneWidget,
    );
    expect(find.text('ПРОДОЛЖИТЬ'), findsOneWidget);
  });

  testWidgets('the status filter shows counts and is remembered', (
    tester,
  ) async {
    await pumpLibrary(tester, books: shelfBooks);

    await chooseStatus(tester, 'Читаю');
    expect(titles(tester, BookTile), ['Анна Каренина']);
    expect(find.text('Читаю · 1'), findsOneWidget);
    expect(await stored(tester, SettingKeys.libraryStatus), 'reading');
    // Hidden over a chosen status.
    expect(find.byType(ContinueCard), findsNothing);

    await tester.tap(find.text('Читаю · 1'));
    await tester.pumpAndSettle();
    Finder count(String name, String n) => find.descendant(
      of: find.ancestor(
        of: find.text(name),
        matching: find.byType(RadioListTile<int>),
      ),
      matching: find.text(n),
    );
    expect(count('Все', '3'), findsOneWidget);
    expect(count('Новые', '1'), findsOneWidget);
    expect(count('Прочитано', '1'), findsOneWidget);
    expect(count('Брошены', '0'), findsOneWidget);
    final finished = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Прочитано'),
    );
    await tester.ensureVisible(finished);
    await tester.pumpAndSettle();
    await tester.tap(finished);
    await settle(tester);
    await tester.pumpAndSettle();
    expect(titles(tester, BookTile), ['Шинель']);

    await chooseStatus(tester, 'Все');
    expect(titles(tester, BookTile), hasLength(3));
    expect(find.byType(ContinueCard), findsOneWidget);
    expect(await stored(tester, SettingKeys.libraryStatus), isNull);
  });

  testWidgets('empty statuses explain themselves', (tester) async {
    await pumpLibrary(tester, books: [_book(1, title: 'Война и мир')]);

    for (final (status, text) in [
      ('Читаю', 'Сейчас вы ничего не читаете'),
      ('На очереди', 'Очередь пуста'),
      ('Брошены', 'Брошенных книг нет'),
      ('Прочитано', 'Прочитанных книг нет'),
    ]) {
      await chooseStatus(tester, status);
      expect(find.text(text), findsOneWidget, reason: status);
      expect(find.text('$status · 0'), findsOneWidget);
      expect(find.byType(BookTile), findsNothing);
    }
  });

  testWidgets('the order menu sorts the books and is remembered', (
    tester,
  ) async {
    await pumpLibrary(tester, books: shelfBooks);

    await tester.tap(find.byTooltip('Сортировка: Недавние'));
    await tester.pumpAndSettle();
    expect(find.text('Сортировка'), findsOneWidget);
    expect(find.text('Группы по фамилии автора'), findsOneWidget);
    await tester.tap(find.text('Название'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(find.text('Сортировка'), findsNothing);
    expect(titles(tester, BookTile), [
      'Анна Каренина',
      'Война и мир',
      'Шинель',
    ]);
    expect(await stored(tester, SettingKeys.librarySort), 'title');
  });

  testWidgets('by author: groups with headers, no "Продолжить"', (
    tester,
  ) async {
    tall(tester);
    await tester.runAsync(
      () => SettingsRepository(db).set(SettingKeys.librarySort, 'author'),
    );
    await pumpLibrary(tester, books: shelfBooks);

    expect(find.byType(ContinueCard), findsNothing);
    expect(find.text('Толстой Л. Н.'), findsOneWidget);
    expect(find.text('Без автора'), findsOneWidget);
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Толстой Л. Н.'), lessThan(top('Анна Каренина')));
    expect(top('Война и мир'), lessThan(top('Без автора')));
    expect(top('Без автора'), lessThan(top('Шинель')));

    await tester.tap(find.byTooltip('Показать обложками'));
    await settle(tester);
    expect(find.text('Толстой Л. Н.'), findsOneWidget);
    expect(find.byType(BookGridTile), findsNWidgets(3));
  });

  testWidgets('the grid button shows covers three in a row', (tester) async {
    await pumpLibrary(tester, books: shelfBooks);
    expect(find.byType(BookGridTile), findsNothing);

    await tester.tap(find.byTooltip('Показать обложками'));
    await settle(tester);

    expect(find.byType(BookTile), findsNothing);
    expect(titles(tester, BookGridTile), [
      'Анна Каренина',
      'Шинель',
      'Война и мир',
    ]);
    final first = tester.getTopLeft(find.byType(BookGridTile).at(0));
    final third = tester.getTopLeft(find.byType(BookGridTile).at(2));
    expect(third.dy, first.dy, reason: 'one row');
    expect(inRow('Анна Каренина', find.text('Читаю · 42 %')), findsOneWidget);
    expect(
      inRow('Анна Каренина', find.byType(LinearProgressIndicator)),
      findsOneWidget,
    );
    expect(inRow('Шинель', find.byType(LinearProgressIndicator)), findsNothing);
    expect(await stored(tester, SettingKeys.libraryLayout), 'grid');

    await tester.tap(find.byTooltip('Показать списком'));
    await settle(tester);
    expect(find.byType(BookTile), findsNWidgets(3));
  });

  testWidgets('a large system text size fits the grid and the list', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(
      () => SettingsRepository(db).set(SettingKeys.libraryLayout, 'grid'),
    );
    await pumpLibrary(
      tester,
      books: [
        for (var i = 1; i <= 6; i++)
          _book(
            i,
            title: 'Очень длинное название книги номер $i',
            authors: ['Фёдор Михайлович Достоевский'],
            opened: i.isEven ? i : null,
            position: 50,
          ),
      ],
    );

    expect(find.byType(BookGridTile), findsWidgets);
    expect(tester.takeException(), isNull, reason: 'no overflow');

    await chooseStatus(tester, 'На очереди');
    expect(tester.takeException(), isNull, reason: 'no overflow');
    await chooseStatus(tester, 'Все');
    await tester.tap(find.byTooltip('Показать списком'));
    await settle(tester);
    expect(find.byType(BookTile), findsWidgets);
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });

  group('collections tab', () {
    final collections = [
      for (final (i, name) in [
        'Русская классика',
        'Школьная программа (9 класс)',
        'Люблю перечитывать',
        'Для поездок и долгих перелётов на выходные и в отпуск',
        'Нон-фикшн',
        'Детям на ночь',
        'Подарки',
      ].indexed)
        CollectionRow(id: i + 1, name: name, createdAt: _day),
    ];

    Future<void> openTab(WidgetTester tester) async {
      await tester.tap(find.text('Подборки'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists collections with covers and counts', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpLibrary(
        tester,
        books: shelfBooks,
        collections: collections,
        links: [
          for (final b in shelfBooks)
            BookCollectionRow(bookId: b.id, collectionId: 1, addedAt: _day),
          BookCollectionRow(bookId: 1, collectionId: 4, addedAt: _day),
        ],
      );
      await openTab(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Создать подборку'), findsOneWidget);
      final first = find.widgetWithText(CollectionCard, 'Русская классика');
      expect(
        find.descendant(of: first, matching: find.text('3 книги')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: first, matching: find.byType(BookCover)),
        findsNWidgets(3),
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');
      // Seven collections: no hint, every one can be scrolled to.
      expect(find.textContaining('Одну книгу можно'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Школьная программа (9 класс)'),
        200,
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');
    });

    testWidgets('a collection opens with its books and its own status', (
      tester,
    ) async {
      await pumpLibrary(
        tester,
        books: shelfBooks,
        collections: [CollectionRow(id: 7, name: 'Классика', createdAt: _day)],
        links: [
          BookCollectionRow(bookId: 1, collectionId: 7, addedAt: _day),
          BookCollectionRow(bookId: 3, collectionId: 7, addedAt: _day),
        ],
      );
      await openTab(tester);
      expect(find.textContaining('Одну книгу можно'), findsOneWidget);
      await tester.tap(find.text('Классика'));
      await tester.pumpAndSettle();

      expect(find.byType(CollectionScreen), findsOneWidget);
      expect(find.text('2 книги'), findsOneWidget);
      expect(titles(tester, BookTile), ['Шинель', 'Война и мир']);
      await chooseStatus(tester, 'Прочитано');
      expect(titles(tester, BookTile), ['Шинель']);
      // Not stored: the library keeps its own status.
      expect(await stored(tester, SettingKeys.libraryStatus), isNull);
      await chooseStatus(tester, 'Читаю');
      expect(find.text('Сейчас вы ничего не читаете'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(CollectionCard), findsOneWidget);
    });

    testWidgets('"Создать подборку" names one and opens it', (tester) async {
      await tester.runAsync(() async {
        for (final b in shelfBooks) {
          await db.into(db.books).insert(b);
        }
      });
      await pumpLibrary(tester, live: true);
      await openTab(tester);
      expect(find.text('Подборок пока нет'), findsOneWidget);

      await tester.tap(find.text('Создать подборку'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Для отпуска');
      await tester.tap(find.text('Создать'));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(find.byType(CollectionScreen), findsOneWidget);
      expect(find.text('Для отпуска'), findsOneWidget);
      expect(find.text('В подборке пока пусто'), findsOneWidget);
    });
  });

  group('book menu', () {
    /// [shelfBooks] and the collection "Классика" with "Война и мир" in the
    /// database, so menu actions show on the screen.
    Future<void> pumpLive(WidgetTester tester) async {
      await tester.runAsync(() async {
        for (final b in shelfBooks) {
          await db.into(db.books).insert(b);
        }
        await db
            .into(db.collections)
            .insert(CollectionRow(id: 7, name: 'Классика', createdAt: _day));
        await db
            .into(db.bookCollections)
            .insert(
              BookCollectionRow(bookId: 1, collectionId: 7, addedAt: _day),
            );
      });
      await pumpLibrary(tester, live: true);
    }

    Future<BookRow?> row(WidgetTester tester, int id) => tester
        .runAsync(
          () => (db.select(
            db.books,
          )..where((b) => b.id.equals(id))).getSingleOrNull(),
        )
        .then((r) => r);

    Future<Set<int>> collectionsOf(WidgetTester tester, int bookId) => tester
        .runAsync(() async {
          final links = await db.select(db.bookCollections).get();
          return {
            for (final l in links)
              if (l.bookId == bookId) l.collectionId,
          };
        })
        .then((r) => r!);

    Future<void> longPress(WidgetTester tester, Finder target) async {
      await tester.longPress(target);
      await tester.pumpAndSettle();
    }

    Future<void> choose(WidgetTester tester, String item) async {
      await tester.tap(find.text(item));
      await settle(tester);
      await tester.pumpAndSettle();
    }

    Finder tile(String title) => find.widgetWithText(BookTile, title);

    /// A status in the book's status sheet.
    Future<void> pick(WidgetTester tester, String status) async {
      await tester.tap(find.widgetWithText(RadioListTile<BookStatus>, status));
      await settle(tester);
      await tester.pumpAndSettle();
    }

    testWidgets('changes the status of a book', (tester) async {
      await pumpLive(tester);

      await longPress(tester, tile('Война и мир'));
      expect(find.text('В подборку…'), findsOneWidget);
      // Only inside a collection.
      expect(find.text('Убрать из подборки'), findsNothing);
      await choose(tester, 'Статус: Новая');
      expect(find.text('Статус книги'), findsOneWidget);
      // A book never opened becomes "Читаю" by opening it.
      expect(
        find.widgetWithText(RadioListTile<BookStatus>, 'Читаю'),
        findsNothing,
      );
      await pick(tester, 'Прочитано');
      expect((await row(tester, 1))!.finishedAt, isNotNull);
      expect(inRow('Война и мир', find.text('Прочитано')), findsOneWidget);

      await longPress(tester, tile('Шинель'));
      await choose(tester, 'Статус: Прочитано');
      await pick(tester, 'Читаю');
      expect((await row(tester, 3))!.finishedAt, isNull);
      expect(inRow('Шинель', find.text('Читаю · 100 %')), findsOneWidget);

      await longPress(tester, tile('Анна Каренина'));
      await choose(tester, 'Статус: Читаю');
      await pick(tester, 'На очереди');
      expect((await row(tester, 2))!.statusMark, StatusMark.queued);
      expect(inRow('Анна Каренина', find.text('На очереди')), findsOneWidget);

      await longPress(tester, tile('Анна Каренина'));
      await choose(tester, 'Статус: На очереди');
      await pick(tester, 'Брошена');
      expect((await row(tester, 2))!.statusMark, StatusMark.abandoned);
    });

    testWidgets('deletes a book only after confirmation', (tester) async {
      await pumpLive(tester);

      await longPress(tester, tile('Война и мир'));
      await choose(tester, 'Удалить книгу');
      expect(find.text('Удалить «Война и мир»?'), findsOneWidget);
      await choose(tester, 'Отмена');
      expect(await row(tester, 1), isNotNull);

      await longPress(tester, tile('Война и мир'));
      await choose(tester, 'Удалить книгу');
      await choose(tester, 'Удалить');
      expect(await row(tester, 1), isNull);
      expect(await collectionsOf(tester, 1), isEmpty);
      expect(titles(tester, BookTile), isNot(contains('Война и мир')));
    });

    testWidgets('puts a book in collections, a new one too', (tester) async {
      await pumpLive(tester);

      await longPress(tester, tile('Шинель'));
      await choose(tester, 'В подборку…');
      expect(find.text('0 книг'), findsNothing);
      expect(find.text('1 книга'), findsOneWidget);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Классика'));
      await settle(tester);
      expect(await collectionsOf(tester, 3), {7});
      expect(find.text('2 книги'), findsOneWidget);

      await choose(tester, 'Новая подборка');
      await choose(tester, 'Создать');
      expect(find.text('Введите название'), findsOneWidget);
      await tester.enterText(find.byType(TextField), ' классика ');
      await choose(tester, 'Создать');
      expect(find.text('Подборка с таким названием уже есть'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Сказки');
      await choose(tester, 'Создать');
      expect(find.byType(TextField), findsNothing);
      final ids = await collectionsOf(tester, 3);
      expect(ids, hasLength(2));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Сказки'),
            )
            .value,
        isTrue,
      );

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Классика'));
      await settle(tester);
      expect(await collectionsOf(tester, 3), ids.difference({7}));
    });

    testWidgets('inside a collection takes the book out of it', (tester) async {
      await pumpLive(tester);
      await tester.tap(find.text('Подборки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Классика'));
      await tester.pumpAndSettle();

      await longPress(tester, tile('Война и мир'));
      await choose(tester, 'Убрать из подборки');
      expect(await collectionsOf(tester, 1), isEmpty);
      expect(await row(tester, 1), isNotNull);
      expect(find.text('В подборке пока пусто'), findsOneWidget);
      expect(find.text('0 книг'), findsOneWidget);
    });

    testWidgets('a deleted collection closes its screen', (tester) async {
      await pumpLive(tester);
      await tester.tap(find.text('Подборки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Классика'));
      await tester.pumpAndSettle();
      expect(find.byType(CollectionScreen), findsOneWidget);

      await tester.runAsync(
        () => (db.delete(db.collections)..where((c) => c.id.equals(7))).go(),
      );
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(CollectionScreen), findsNothing);
      expect(find.text('Подборок пока нет'), findsOneWidget);
    });

    testWidgets('a long press on a grid cover opens the menu', (tester) async {
      await tester.runAsync(
        () => SettingsRepository(db).set(SettingKeys.libraryLayout, 'grid'),
      );
      await pumpLive(tester);

      await longPress(tester, find.widgetWithText(BookGridTile, 'Шинель'));
      expect(find.text('Статус: Прочитано'), findsOneWidget);
      expect(find.text('Удалить книгу'), findsOneWidget);
    });
  });
}
