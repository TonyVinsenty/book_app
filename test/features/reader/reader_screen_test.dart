import 'dart:io';

import 'package:book_app/app/app.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../layout/sample_book.dart';

void main() {
  // Each test opens its own in-memory database.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temp;
  late BookRepository repo;
  late int bookId;

  setUp(() => temp = Directory.systemTemp.createTempSync('reader_'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// Lets real async work (isolates, files, database) run.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }

  /// The app with one generated three-chapter book in the library.
  Future<void> pumpApp(WidgetTester tester) async {
    // Closing a drift database under fake time hangs, so it is left open;
    // synchronous stream closing leaves no pending timer.
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = BookRepository(db, ContentStore(Directory('${temp.path}/books')));
    final content = sampleBook(paragraphs: 30);
    final source = File('${temp.path}/book.txt')..writeAsStringSync('книга');
    await tester.runAsync(() async {
      bookId = (await repo.addBook(
        content: content,
        source: source,
        sourceName: 'book.txt',
        sourceHash: 'hash',
        parserVersion: txtParserVersion,
        wordCount: tokenize(content).length,
      )).id;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bookRepositoryProvider.overrideWithValue(repo),
        ],
        child: const BookApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> openBook(WidgetTester tester) async {
    await tester.tap(find.byType(ListTile));
    for (
      var i = 0;
      i < 100 && find.byType(ReaderView).evaluate().isEmpty;
      i++
    ) {
      await settle(tester);
    }
    await tester.pumpAndSettle();
  }

  ReaderViewState reader(WidgetTester tester) =>
      tester.state<ReaderViewState>(find.byType(ReaderView));

  Future<void> tapAt(WidgetTester tester, double x) async {
    final size = tester.getSize(find.byType(ReaderView));
    await tester.tapAt(Offset(size.width * x, size.height / 2));
    await settle(tester);
  }

  Future<int> savedWord() async => (await repo.findById(bookId))!.positionWord;

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('pages turn by taps, across chapters, and the place is saved', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);

    expect(reader(tester).page.firstWord, 0);
    expect(reader(tester).layout.sectionIndex, 0);
    final pages = reader(tester).layout.pages.length;
    expect(pages, greaterThan(1));

    await tapAt(tester, 0.95);
    final second = reader(tester).page.firstWord;
    expect(second, greaterThan(0));
    expect(await tester.runAsync(savedWord), second);

    for (var i = 1; i < pages; i++) {
      await tapAt(tester, 0.95);
    }
    expect(reader(tester).layout.sectionIndex, 1, reason: 'next chapter');
    expect(find.text('1 / ${reader(tester).layout.pages.length}'), findsOne);

    await tapAt(tester, 0.05);
    expect(reader(tester).layout.sectionIndex, 0);
    expect(find.text('$pages / $pages'), findsOneWidget);

    // The middle shows the bar; its back button returns to the library.
    await tapAt(tester, 0.5);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderView), findsNothing);
    final saved = await tester.runAsync(savedWord);
    expect(
      (await tester.runAsync(() => repo.findById(bookId)))!.openedAt,
      isNotNull,
    );

    await openBook(tester);
    final page = reader(tester).page;
    expect(page.firstWord, saved, reason: 'opens where reading stopped');
    await closeApp(tester);
  });

  testWidgets('a new screen size keeps the same word on screen', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    for (var i = 0; i < 3; i++) {
      await tapAt(tester, 0.95);
    }
    final word = reader(tester).page.firstWord;

    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();

    final page = reader(tester).page;
    expect(page.firstWord, lessThanOrEqualTo(word));
    expect(page.endWord, greaterThan(word));
    await closeApp(tester);
  });
}
