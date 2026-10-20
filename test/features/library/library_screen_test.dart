import 'dart:io';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
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
          booksProvider.overrideWithValue(AsyncData(books)),
          collectionsProvider.overrideWithValue(AsyncData(collections)),
          collectionLinksProvider.overrideWithValue(AsyncData(links)),
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
          find.byType(ChoiceChip).evaluate().isEmpty &&
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

  testWidgets('rows show the percent, the read mark or nothing', (
    tester,
  ) async {
    await pumpLibrary(tester, books: shelfBooks);

    expect(find.text('3 книги'), findsOneWidget);
    expect(titles(tester, BookTile), [
      'Анна Каренина',
      'Шинель',
      'Война и мир',
    ]);
    Finder inRow(String title, Finder what) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(BookTile)),
      matching: what,
    );
    expect(inRow('Анна Каренина', find.text('42 %')), findsOneWidget);
    expect(inRow('Шинель', find.text('Прочитано')), findsOneWidget);
    expect(inRow('Война и мир', find.byType(ReadMarkLine)), findsNothing);

    // "Продолжить" is the book opened last.
    final card = find.byType(ContinueCard);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Анна Каренина')),
      findsOneWidget,
    );
    expect(find.text('ПРОДОЛЖИТЬ'), findsOneWidget);
  });

  testWidgets('a shelf filters the books and is remembered', (tester) async {
    await pumpLibrary(
      tester,
      books: shelfBooks,
      collections: [CollectionRow(id: 7, name: 'Классика', createdAt: _day)],
      links: [BookCollectionRow(bookId: 1, collectionId: 7, addedAt: _day)],
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Читаю'));
    await settle(tester);
    expect(titles(tester, BookTile), ['Анна Каренина']);
    expect(await stored(tester, SettingKeys.libraryShelf), 'reading');
    expect(find.byType(ContinueCard), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Прочитано'));
    await settle(tester);
    expect(titles(tester, BookTile), ['Шинель']);
    expect(find.byType(ContinueCard), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Классика'));
    await settle(tester);
    expect(titles(tester, BookTile), ['Война и мир']);
    expect(find.text('1 книга'), findsOneWidget);
    expect(await stored(tester, SettingKeys.libraryShelf), 'c:7');
  });

  testWidgets('empty shelves explain themselves', (tester) async {
    await pumpLibrary(
      tester,
      books: [_book(1, title: 'Война и мир')],
      collections: [CollectionRow(id: 7, name: 'Классика', createdAt: _day)],
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Читаю'));
    await settle(tester);
    expect(find.text('Сейчас вы ничего не читаете'), findsOneWidget);
    expect(find.text('0 книг'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Прочитано'));
    await settle(tester);
    expect(find.text('Прочитанных книг нет'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Классика'));
    await settle(tester);
    expect(find.text('В подборке пока пусто'), findsOneWidget);
    expect(find.byType(BookTile), findsNothing);
  });

  testWidgets('the order menu sorts every shelf and is remembered', (
    tester,
  ) async {
    await pumpLibrary(tester, books: shelfBooks);

    await tester.tap(find.text('Недавние'));
    await tester.pumpAndSettle();
    expect(find.text('Сортировка'), findsOneWidget);
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
    expect(
      find.descendant(
        of: find.byType(BookGridTile),
        matching: find.text('42 %'),
      ),
      findsOneWidget,
    );
    expect(await stored(tester, SettingKeys.libraryLayout), 'grid');

    await tester.tap(find.byTooltip('Показать списком'));
    await settle(tester);
    expect(find.byType(BookTile), findsNWidgets(3));
  });

  testWidgets('a large system text size fits the grid', (tester) async {
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
          ),
      ],
    );

    expect(find.byType(BookGridTile), findsWidgets);
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });
}
