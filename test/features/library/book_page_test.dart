import 'dart:io';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/book_pages.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/features/library/book_page.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/layout/page_cache.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 10, 1);

BookRow _book(
  int id, {
  required String title,
  int position = 0,
  bool opened = false,
  bool finished = false,
  String? annotation,
}) => BookRow(
  id: id,
  title: title,
  authors: const ['Л. Н. Толстой'],
  sourceFormat: SourceFormat.fb2,
  sourceName: '$id.fb2',
  sourceSize: 3 * 1024 * 1024 ~/ 2,
  sourceHash: '$id',
  parserVersion: 1,
  wordCount: 100,
  positionWord: position,
  positionSection: 0,
  positionBlock: 0,
  positionChar: 0,
  addedAt: _day,
  openedAt: opened ? _day : null,
  touchedAt: _day,
  finishedAt: finished ? _day.add(const Duration(days: 17)) : null,
  annotation: annotation,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temp;
  late AppDatabase db;
  late ContentStore store;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('book_page_');
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    store = ContentStore(Directory('${temp.path}/books'));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<BookRow?> row(WidgetTester tester, int id) => tester
      .runAsync(
        () => (db.select(
          db.books,
        )..where((b) => b.id.equals(id))).getSingleOrNull(),
      )
      .then((r) => r);

  /// The library with [books]; a tap on [open] shows its page.
  Future<void> pumpPage(
    WidgetTester tester,
    List<BookRow> books, {
    required String open,
    Future<void> Function()? before,
  }) async {
    await tester.runAsync(() async {
      for (final b in books) {
        await db.into(db.books).insert(b);
      }
      await before?.call();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contentStoreProvider.overrideWithValue(store),
          bookRepositoryProvider.overrideWithValue(BookRepository(db, store)),
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
      i < 50 && find.widgetWithText(BookTile, open).evaluate().isEmpty;
      i++
    ) {
      await settle(tester);
    }
    await tester.tap(find.widgetWithText(BookTile, open));
    await settle(tester);
    expect(find.byType(BookPageScreen), findsOneWidget);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await settle(tester);
  }

  Finder onPage(Finder f) =>
      find.descendant(of: find.byType(BookPageScreen), matching: f);

  testWidgets('a new book: estimated pages, no reading yet', (tester) async {
    await pumpPage(tester, [
      _book(1, title: 'Война и мир'),
    ], open: 'Война и мир');

    expect(onPage(find.text('Война и мир')), findsOneWidget);
    expect(onPage(find.text('Л. Н. Толстой')), findsOneWidget);
    expect(onPage(find.text('Новая')), findsOneWidget);
    expect(onPage(find.textContaining('≈ ')), findsOneWidget);
    expect(onPage(find.textContaining('(оценка)')), findsOneWidget);
    expect(onPage(find.text('100')), findsOneWidget);
    expect(onPage(find.text('слов')), findsOneWidget);
    expect(onPage(find.text('—')), findsOneWidget);
    expect(
      onPage(find.textContaining('Добавлена 1 окт. · FB2 · 1,5 МБ')),
      findsOneWidget,
    );
    expect(onPage(find.text('Не добавлена')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Читать'), findsOneWidget);
  });

  testWidgets('pages saved by the reader: exact, with the page read', (
    tester,
  ) async {
    await pumpPage(
      tester,
      [_book(2, title: 'Анна Каренина', position: 42, opened: true)],
      open: 'Анна Каренина',
      before: () async {
        // The page and look this test screen gives the reader.
        const settings = ReadingSettings();
        final style = pageStyleOf(
          settings,
          system: TextScaler.noScaling,
          color: Colors.black,
        );
        final pageSize = readerPageOf(
          const Size(800, 600),
          settings.margins.side,
        );
        Directory('${temp.path}/books/2').createSync(recursive: true);
        PageCache(store.pagesDir(2)).save(
          layoutKeyOf(style: style, pageSize: pageSize, parserVersion: 1),
          [
            [0, 20, 40, 60, 80],
          ],
        );
        await SettingsRepository(db).set(
          SettingKeys.readerLastLayout,
          LastLayout(
            pageSize: pageSize,
            styleKey: styleKeyOf(style: style, pageSize: pageSize),
          ).encode(),
        );
      },
    );

    expect(onPage(find.text('5')), findsOneWidget);
    expect(onPage(find.text('страниц')), findsOneWidget);
    expect(onPage(find.text('3')), findsOneWidget);
    expect(onPage(find.text('стр. прочитано')), findsOneWidget);
    expect(onPage(find.textContaining('Страниц при вашем шрифте.')), findsOne);
    expect(onPage(find.text('Читаю · 42 %')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Продолжить'), findsOneWidget);
  });

  testWidgets('without the saved pages a book being read shows percent', (
    tester,
  ) async {
    await pumpPage(tester, [
      _book(2, title: 'Анна Каренина', position: 42, opened: true),
    ], open: 'Анна Каренина');

    expect(onPage(find.textContaining('≈ ')), findsOneWidget);
    expect(onPage(find.text('42 %')), findsNWidgets(2));
    expect(onPage(find.text('прочитано')), findsOneWidget);
  });

  testWidgets('status buttons: read, reading again, queued', (tester) async {
    await pumpPage(tester, [
      _book(2, title: 'Анна Каренина', position: 42, opened: true),
    ], open: 'Анна Каренина');

    await tap(tester, find.widgetWithText(OutlinedButton, 'Прочитано'));
    expect((await row(tester, 2))!.finishedAt, isNotNull);
    expect(onPage(find.text('дочитана')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Читать снова'), findsOneWidget);

    await tap(tester, find.widgetWithText(OutlinedButton, 'Читаю снова'));
    expect((await row(tester, 2))!.finishedAt, isNull);
    expect(onPage(find.text('Читаю · 42 %')), findsOneWidget);

    await tap(tester, find.widgetWithText(OutlinedButton, 'Статус: Читаю'));
    await tap(
      tester,
      find.widgetWithText(RadioListTile<BookStatus>, 'На очереди'),
    );
    expect((await row(tester, 2))!.statusMark, StatusMark.queued);
    expect(onPage(find.text('Статус: На очереди')), findsOneWidget);
  });

  testWidgets('a read book never opened has no "Читаю снова"', (tester) async {
    await pumpPage(tester, [
      _book(3, title: 'Шинель', finished: true),
    ], open: 'Шинель');

    expect(onPage(find.textContaining('Дочитана 18 окт.')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Читаю снова'), findsNothing);
  });

  testWidgets('collections: their names, the sheet to change them', (
    tester,
  ) async {
    await pumpPage(
      tester,
      [_book(1, title: 'Война и мир')],
      open: 'Война и мир',
      before: () async {
        await db
            .into(db.collections)
            .insert(CollectionRow(id: 7, name: 'Классика', createdAt: _day));
        await db
            .into(db.bookCollections)
            .insert(
              BookCollectionRow(collectionId: 7, bookId: 1, addedAt: _day),
            );
      },
    );

    expect(onPage(find.text('Классика')), findsOneWidget);
    await tap(tester, find.text('В подборку'));
    await tap(tester, find.widgetWithText(CheckboxListTile, 'Классика'));
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(onPage(find.text('Не добавлена')), findsOneWidget);
  });

  testWidgets('a deleted book closes its page', (tester) async {
    await pumpPage(tester, [
      _book(1, title: 'Война и мир'),
    ], open: 'Война и мир');

    // The trash icon at the top right, with a confirmation.
    await tap(tester, onPage(find.byTooltip('Удалить книгу')));
    await tap(tester, find.widgetWithText(TextButton, 'Отмена'));
    expect(await row(tester, 1), isNotNull);
    await tap(tester, onPage(find.byTooltip('Удалить книгу')));
    await tap(tester, find.widgetWithText(TextButton, 'Удалить'));
    expect(await row(tester, 1), isNull);
    expect(find.byType(BookPageScreen), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('the annotation: short in full, long in part with «Ещё»', (
    tester,
  ) async {
    final long = List.filled(40, 'Длинная аннотация о книге.').join(' ');
    await pumpPage(tester, [
      _book(1, title: 'Война и мир', annotation: 'Роман-эпопея.\nО войне.'),
      _book(2, title: 'Анна Каренина', annotation: long),
      _book(3, title: 'Воскресение'),
    ], open: 'Война и мир');
    expect(onPage(find.text('Аннотация')), findsOneWidget);
    expect(onPage(find.text('Роман-эпопея.\nО войне.')), findsOneWidget);
    expect(onPage(find.text('Ещё')), findsNothing);

    await tester.binding.handlePopRoute();
    await settle(tester);
    await tap(tester, find.widgetWithText(BookTile, 'Анна Каренина'));
    Text annotation() => tester.widget<Text>(onPage(find.text(long)));
    // The button may be under the bottom one: scroll it up before the tap.
    Future<void> press(String label) async {
      await tester.ensureVisible(onPage(find.text(label)));
      await tester.pumpAndSettle();
      await tap(tester, onPage(find.text(label)));
    }

    expect(annotation().maxLines, 6);
    await press('Ещё');
    expect(annotation().maxLines, isNull);
    await press('Свернуть');
    expect(annotation().maxLines, 6);

    await tester.binding.handlePopRoute();
    await settle(tester);
    await tap(tester, find.widgetWithText(BookTile, 'Воскресение'));
    expect(onPage(find.text('Аннотация')), findsNothing);
  });
}
