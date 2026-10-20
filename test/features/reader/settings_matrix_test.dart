import 'dart:io';

import 'package:book_app/app/app.dart';
import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/page_texture.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/platform/screen_channel.dart';
import 'package:book_app/platform/system_bars.dart';
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
  late ContentStore store;
  late BookRepository repo;
  late int bookId;
  late AppDatabase db;

  /// Calls to keep the screen on (true) or let it dim (false).
  late List<bool> keepScreenOn;

  /// Calls to show (true) or hide (false) the status bar.
  late List<bool> statusBar;

  setUp(() => temp = Directory.systemTemp.createTempSync('reader_'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// Lets real async work (isolates, files, database) run.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }

  /// The app with one generated three-chapter book in the library;
  /// [reopen] starts it as after a restart with that book read last,
  /// [lostFiles] removes the book files first.
  Future<void> pumpApp(
    WidgetTester tester, {
    bool reopen = false,
    bool lostFiles = false,
  }) async {
    // Closing a drift database under fake time hangs, so it is left open;
    // synchronous stream closing leaves no pending timer.
    keepScreenOn = [];
    statusBar = [];
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    store = ContentStore(Directory('${temp.path}/books'));
    repo = BookRepository(db, store);
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
      if (reopen) await repo.markOpened(bookId);
    });
    if (lostFiles) Directory('${temp.path}/books').deleteSync(recursive: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contentStoreProvider.overrideWithValue(store),
          bookRepositoryProvider.overrideWithValue(repo),
          keepScreenOnProvider.overrideWithValue((on) async {
            keepScreenOn.add(on);
          }),
          showStatusBarProvider.overrideWithValue((shown) async {
            statusBar.add(shown);
          }),
        ],
        child: BookApp(reopenBookId: reopen ? bookId : null),
      ),
    );
    await settle(tester);
  }

  Future<void> openBook(WidgetTester tester) async {
    for (var i = 0; i < 100 && find.byType(BookTile).evaluate().isEmpty; i++) {
      await settle(tester);
    }
    await tester.tap(find.byType(BookTile));
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

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('every setting value, in chapter 2, middle of a page: same '
      'word on screen', (tester) async {
    await pumpApp(tester);
    await openBook(tester);
    // Into the second chapter, a few pages deep.
    await tapAt(tester, 0.5);
    await tester.tap(find.byTooltip('Оглавление'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Глава 2'));
    await settle(tester);
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tapAt(tester, 0.95);
    }
    final page = reader(tester).page;
    final word = (page.firstWord + page.endWord) ~/ 2;
    expect(reader(tester).layout.sectionIndex, 1);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    );
    final notifier = container.read(readingSettingsProvider.notifier);

    Future<void> change(
      String label,
      ReadingSettings Function(ReadingSettings) edit,
    ) async {
      notifier.set(edit(container.read(readingSettingsProvider)));
      await tester.pumpAndSettle();
      final p = reader(tester).page;
      expect(reader(tester).layout.sectionIndex, 1, reason: label);
      // The word the page started with before must stay on the page
      // (the page may start a little earlier, never later).
      expect(p.firstWord, lessThanOrEqualTo(page.firstWord), reason: label);
      expect(p.endWord, greaterThan(page.firstWord), reason: label);
    }

    for (final f in BookFont.values) {
      await change('font $f', (s) => s.copyWith(font: f));
    }
    await change('font back', (s) => s.copyWith(font: BookFont.literata));
    for (final h in [1.3, 1.45, 1.7]) {
      await change('line $h', (s) => s.copyWith(lineHeight: h));
    }
    for (final m in PageMargins.values) {
      await change('margins $m', (s) => s.copyWith(margins: m));
    }
    for (final a in BookAlign.values) {
      await change('align $a', (s) => s.copyWith(align: a));
    }
    await change('justify', (s) => s.copyWith(align: BookAlign.justify));
    for (final on in [false, true, false, true]) {
      await change('hyphenate $on', (s) => s.copyWith(hyphenate: on));
    }
    for (final size in ReadingSettings.fontSizes) {
      await change('size $size', (s) => s.withFontSize(size));
    }
    for (final p in ReadingPalette.values) {
      for (final n in NightMode.values) {
        for (final t in PageTexture.values) {
          await change(
            '$p $n $t',
            (s) => s.copyWith(palette: p, night: n, texture: t),
          );
        }
      }
    }
    await change('defaults', (_) => const ReadingSettings());
    expect(reader(tester).page.firstWord, page.firstWord);
    expect(word, greaterThan(page.firstWord - 1));
    await closeApp(tester);
  });
}
