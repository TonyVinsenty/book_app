import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:book_app/app/app.dart';
import 'package:book_app/app/pro.dart';
import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:book_app/book/tokenizer/token.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_pages.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/data/stats_repository.dart';
import 'package:book_app/features/library/book_page.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/features/reader/contents_screen.dart';
import 'package:book_app/features/reader/guide_layer.dart';
import 'package:book_app/features/reader/guide_panel.dart';
import 'package:book_app/features/reader/image_viewer.dart';
import 'package:book_app/features/reader/note_view.dart';
import 'package:book_app/features/reader/page_images.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/features/reader/settings_panel.dart';
import 'package:book_app/features/speed/rsvp_screen.dart';
import 'package:book_app/features/speed/speed_controls.dart';
import 'package:book_app/features/stats/book_stats_sheet.dart';
import 'package:book_app/layout/page_cache.dart';
import 'package:book_app/platform/screen_channel.dart';
import 'package:book_app/platform/system_bars.dart';
import 'package:book_app/speed/pause_text.dart';
import 'package:book_app/speed/phrases.dart';
import 'package:book_app/speed/rewind.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/speed/steps.dart';
import 'package:book_app/speed/timing.dart';
import 'package:book_app/stats/stats_records.dart';
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

  /// The clock of the reading meters, moved by hand.
  late DateTime clock;
  void wait(int seconds) => clock = clock.add(Duration(seconds: seconds));

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
    bool pro = true,
    BookContent? book,
  }) async {
    // Closing a drift database under fake time hangs, so it is left open;
    // synchronous stream closing leaves no pending timer.
    keepScreenOn = [];
    statusBar = [];
    clock = DateTime(2026, 10, 23, 20);
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    store = ContentStore(Directory('${temp.path}/books'));
    repo = BookRepository(db, store);
    final content = book ?? sampleBook(paragraphs: 30);
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
          proUnlockedProvider.overrideWithValue(pro),
          contentStoreProvider.overrideWithValue(store),
          bookRepositoryProvider.overrideWithValue(repo),
          statsClockProvider.overrideWithValue(() => clock),
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
    // The book page opens first; its main button opens the book.
    final read = find.descendant(
      of: find.byType(BookPageScreen),
      matching: find.byType(FilledButton),
    );
    for (var i = 0; i < 100 && read.evaluate().isEmpty; i++) {
      await settle(tester);
    }
    await tester.tap(read);
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

  /// « · 12,3 %» after the page number: the share read up to the shown
  /// page, to a tenth.
  String percent(WidgetTester tester) {
    final r = reader(tester);
    final tenths = r.page.firstWord * 1000 ~/ r.widget.opened.tokens.length;
    return ' · ${tenths ~/ 10},${tenths % 10} %';
  }

  Future<void> tapAt(WidgetTester tester, double x) async {
    final size = tester.getSize(find.byType(ReaderView));
    await tester.tapAt(Offset(size.width * x, size.height / 2));
    await settle(tester);
    // A turned page slides in (14.3).
    if (x < 1 / 3 || x > 2 / 3) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<int> savedWord() async => (await repo.findById(bookId))!.positionWord;

  Future<DateTime?> finishedAt(WidgetTester tester) async =>
      (await tester.runAsync(() => repo.findById(bookId)))!.finishedAt;

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('pages turn by taps, across chapters, and the place is saved', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(keepScreenOn, isEmpty, reason: 'the library lets it dim');
    await openBook(tester);
    expect(keepScreenOn, [true], reason: 'an open book keeps it on');

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
    // Numbers go across the book, split while the reader was idle.
    final book = reader(tester).pagination;
    expect(book.isComplete, isTrue);
    final total = book.pageCount.value;
    expect(total, greaterThan(pages + reader(tester).layout.pages.length));
    expect(find.text('стр. ${pages + 1} / $total${percent(tester)}'), findsOne);
    expect(percent(tester), isNot(' · 0 %'));

    await tapAt(tester, 0.05);
    expect(reader(tester).layout.sectionIndex, 0);
    expect(find.text('стр. $pages / $total${percent(tester)}'), findsOneWidget);

    // The middle shows the panels; «Библиотека» returns to the library.
    await tapAt(tester, 0.5);
    await tester.tap(find.text('Библиотека'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderView), findsNothing);
    expect(keepScreenOn, [true, false]);
    final saved = await tester.runAsync(savedWord);
    expect(
      (await tester.runAsync(() => repo.findById(bookId)))!.openedAt,
      isNotNull,
    );

    await openBook(tester);
    final page = reader(tester).page;
    expect(page.firstWord, saved, reason: 'opens where reading stopped');
    expect(
      reader(tester).pagination.isComplete,
      isTrue,
      reason: 'the page count is saved with the book',
    );
    expect(store.pagesDir(bookId).listSync(), hasLength(1));
    await closeApp(tester);
  });

  testWidgets('the page follows a finger: a short pull springs back, a long '
      'one turns; a tap slides', (tester) async {
    await pumpApp(tester);
    await openBook(tester);
    final view = find.byType(ReaderView);
    final width = tester.getSize(view).width;
    const slow = Duration(milliseconds: 600);
    Future<void> rest() => tester.pump(const Duration(milliseconds: 300));

    // Before the first page it only gives a little and comes back.
    await tester.timedDrag(view, Offset(width * 0.4, 0), slow);
    await rest();
    expect(reader(tester).page.firstWord, 0);

    await tester.timedDrag(view, Offset(-width * 0.1, 0), slow);
    await rest();
    expect(reader(tester).page.firstWord, 0, reason: 'springs back');
    expect(find.byType(PageImages), findsOne, reason: 'at rest: one page');

    await tester.timedDrag(view, Offset(-width * 0.4, 0), slow);
    await rest();
    final second = reader(tester).page.firstWord;
    expect(second, greaterThan(0));

    // A tap slides the next page in: both are on screen for a moment.
    await tester.tapAt(Offset(width * 0.95, tester.getSize(view).height / 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(reader(tester).page.firstWord, greaterThan(second));
    expect(find.byType(PageImages), findsNWidgets(2));
    await rest();
    expect(find.byType(PageImages), findsOne);

    await tester.timedDrag(view, Offset(width * 0.4, 0), slow);
    await rest();
    expect(reader(tester).page.firstWord, second, reason: 'back by a pull');
    await closeApp(tester);
  });

  testWidgets('the last book reopens on start; back leads to the library', (
    tester,
  ) async {
    await pumpApp(tester, reopen: true);
    for (
      var i = 0;
      i < 100 && find.byType(ReaderView).evaluate().isEmpty;
      i++
    ) {
      await settle(tester);
    }
    await tester.pumpAndSettle();
    expect(find.byType(ReaderView), findsOneWidget);
    expect(find.byType(LibraryScreen), findsNothing, reason: 'covered');

    await tester.binding.handlePopRoute(); // system "back"
    await tester.pumpAndSettle();
    expect(find.byType(BookTile), findsOneWidget);
    expect(find.byType(ContinueCard), findsOneWidget);

    // «Вернуться к «…»» opens it again, whatever the shelf.
    await tester.tap(find.textContaining('Вернуться к «'));
    for (
      var i = 0;
      i < 100 && find.byType(ReaderView).evaluate().isEmpty;
      i++
    ) {
      await settle(tester);
    }
    await tester.pumpAndSettle();
    expect(find.byType(ReaderView), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('a lost last book leaves the library with a message', (
    tester,
  ) async {
    await pumpApp(tester, reopen: true, lostFiles: true);
    for (var i = 0; i < 100 && find.byType(SnackBar).evaluate().isEmpty; i++) {
      await settle(tester);
    }
    await tester.pumpAndSettle();
    expect(find.text('Не удалось открыть последнюю книгу'), findsOneWidget);
    expect(find.byType(ReaderScreen), findsNothing);
    expect(find.byType(BookTile), findsOneWidget);
    expect(find.textContaining('Вернуться к'), findsNothing, reason: 'broken');

    // A tap closes the message.
    await tester.tap(find.text('Не удалось открыть последнюю книгу'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await closeApp(tester);
  });

  testWidgets('a lost book opened by hand shows the way back', (tester) async {
    await pumpApp(tester, lostFiles: true);
    for (var i = 0; i < 100 && find.byType(BookTile).evaluate().isEmpty; i++) {
      await settle(tester);
    }
    await tester.tap(find.byType(BookTile));
    // The book page opens first; its main button opens the book.
    final read = find.descendant(
      of: find.byType(BookPageScreen),
      matching: find.byType(FilledButton),
    );
    for (var i = 0; i < 100 && read.evaluate().isEmpty; i++) {
      await settle(tester);
    }
    await tester.tap(read);
    for (
      var i = 0;
      i < 100 && find.text('К библиотеке').evaluate().isEmpty;
      i++
    ) {
      await settle(tester);
    }
    expect(find.text('Не удалось открыть книгу'), findsOneWidget);

    await tester.tap(find.text('К библиотеке'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsNothing);
    expect(find.textContaining('Вернуться к'), findsNothing, reason: 'broken');
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

  testWidgets('settings changes keep the place: A+ A+ A− A− → same page', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    for (var i = 0; i < 4; i++) {
      await tapAt(tester, 0.95);
    }
    final start = reader(tester).page;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    );
    final notifier = container.read(readingSettingsProvider.notifier);
    Future<void> change(ReadingSettings Function(ReadingSettings) edit) async {
      notifier.set(edit(container.read(readingSettingsProvider)));
      await tester.pumpAndSettle();
      final page = reader(tester).page;
      expect(page.firstWord, lessThanOrEqualTo(start.firstWord));
      expect(page.endWord, greaterThan(start.firstWord));
    }

    const scale = TextScaler.noScaling;
    await change((s) => s.larger(scale));
    expect(reader(tester).layout.style.fontSize, 19);
    await change((s) => s.larger(scale));
    await change((s) => s.smaller(scale));
    await change((s) => s.smaller(scale));
    expect(reader(tester).page.firstWord, start.firstWord);
    expect(reader(tester).page.endWord, start.endWord);

    final before = reader(tester).pagination;
    await change((s) => s.copyWith(font: BookFont.lora));
    final lora = reader(tester).pagination;
    expect(lora, isNot(same(before)), reason: 'a new font: split again');
    expect(lora.isComplete, isFalse);
    await tester.pump(Duration.zero); // idle time
    expect(lora.isComplete, isTrue);
    await change((s) => s.copyWith(lineHeight: 1.8));
    await change((s) => s.copyWith(margins: PageMargins.wide));
    await change((s) => s.copyWith(align: BookAlign.justify));
    final justified = reader(tester).pagination;
    await change((s) => s.copyWith(palette: ReadingPalette.sage));
    await change((s) => s.copyWith(night: NightMode.night));
    expect(
      reader(tester).pagination,
      same(justified),
      reason: 'colors keep the pages',
    );
    await change((_) => const ReadingSettings());
    expect(reader(tester).page.firstWord, start.firstWord);
    await closeApp(tester);
  });

  testWidgets('the middle shows the panels and the status bar; A+ keeps '
      'the place', (tester) async {
    await pumpApp(tester);
    await openBook(tester);
    expect(statusBar, [false], reason: 'hidden while reading');
    for (var i = 0; i < 4; i++) {
      await tapAt(tester, 0.95);
    }
    final start = reader(tester).page;
    final pages = reader(tester).layout.pages.length;
    final pageArea = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.size == reader(tester).layout.pageSize,
    );
    final top = tester.getTopLeft(pageArea);

    await tapAt(tester, 0.5);
    expect(reader(tester).panelsShown, isTrue);
    expect(statusBar, [false, true]);
    expect(find.text('Глава 1'), findsOneWidget);
    expect(
      find.text(
        'стр. 5 / ${reader(tester).pagination.pageCount.value}'
        '${percent(tester)} · до конца главы ${pages - 5} стр.',
      ),
      findsOneWidget,
    );
    expect(tester.getTopLeft(pageArea), top, reason: 'the page stays put');

    // A+ three times: a larger font, the same place.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('A+'));
      await tester.pumpAndSettle();
    }
    expect(reader(tester).layout.style.fontSize, 22);
    final page = reader(tester).page;
    expect(page.firstWord, lessThanOrEqualTo(start.firstWord));
    expect(page.endWord, greaterThan(start.firstWord));
    expect(reader(tester).panelsShown, isTrue, reason: 'still open');

    // A tap anywhere hides them and does not turn the page.
    await tapAt(tester, 0.95);
    expect(reader(tester).panelsShown, isFalse);
    expect(reader(tester).page.firstWord, page.firstWord);
    expect(statusBar, [false, true, false]);

    // Back closes the panels first, then the book.
    await tapAt(tester, 0.5);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(reader(tester).panelsShown, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderView), findsNothing);
    expect(statusBar.last, isTrue, reason: 'the library shows it');
    await closeApp(tester);
  });

  testWidgets('a swipe down closes the settings panel, a short pull does '
      'not', (tester) async {
    await pumpApp(tester);
    await openBook(tester);
    Future<void> open() async {
      await tapAt(tester, 0.5);
      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();
      expect(reader(tester).settingsShown, isTrue);
    }

    await open();
    final panel = find.byType(ReadingSettingsPanel);
    final top = tester.getTopLeft(panel) + const Offset(200, 8);
    await tester.timedDragFrom(
      top,
      const Offset(0, 30),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(reader(tester).settingsShown, isTrue, reason: 'a short pull');

    await tester.dragFrom(top, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(reader(tester).settingsShown, isFalse, reason: 'by the grip');

    await open();
    await tester.fling(find.text('Шрифт'), const Offset(0, 200), 1500);
    await tester.pumpAndSettle();
    expect(reader(tester).settingsShown, isFalse, reason: 'past the list top');
  });

  testWidgets('the settings panel changes the text at once, in the same '
      'place', (tester) async {
    await pumpApp(tester);
    await openBook(tester);
    for (var i = 0; i < 4; i++) {
      await tapAt(tester, 0.95);
    }
    final start = reader(tester).page.firstWord;
    await tapAt(tester, 0.5);
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(reader(tester).settingsShown, isTrue);
    expect(find.text('Библиотека'), findsNothing, reason: 'panels give way');

    Future<void> pick(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      final page = reader(tester).page;
      expect(page.firstWord, lessThanOrEqualTo(start), reason: label);
      expect(page.endWord, greaterThan(start), reason: label);
    }

    await pick('Lora');
    await pick('Свободный');
    await pick('Широкие');
    await pick('По ширине');
    await pick('Шалфей');
    await pick('Ночь');
    final style = reader(tester).layout.style;
    expect(style.fontFamily, 'Lora');
    expect(style.lineHeight, 1.7);
    expect(style.align, TextAlign.justify);
    expect(
      Theme.of(tester.element(find.byType(ReaderView))).brightness,
      Brightness.dark,
    );
    final settings = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    ).read(readingSettingsProvider);
    expect(settings.margins, PageMargins.wide);
    expect(settings.palette, ReadingPalette.sage);
    expect(settings.night, NightMode.night);

    // A tap on the page above it closes it without turning; so does back.
    final page = reader(tester).page.firstWord;
    final size = tester.getSize(find.byType(ReaderView));
    await tester.tapAt(Offset(size.width * 0.95, size.height * 0.2));
    await settle(tester);
    expect(reader(tester).settingsShown, isFalse);
    expect(reader(tester).panelsShown, isFalse);
    expect(reader(tester).page.firstWord, page);
    await tapAt(tester, 0.5);
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(reader(tester).settingsShown, isFalse);
    expect(find.byType(ReaderView), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('the table of contents opens a chapter at its start', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    await tapAt(tester, 0.95);
    final start = reader(tester).page.firstWord;

    // Back from the table of contents changes nothing.
    await tapAt(tester, 0.5);
    await tester.tap(find.byTooltip('Оглавление'));
    await tester.pumpAndSettle();
    final lines = tester.widget<ContentsScreen>(find.byType(ContentsScreen));
    expect(lines.current, 0, reason: 'chapter 1 is lit');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(reader(tester).page.firstWord, start);
    expect(reader(tester).panelsShown, isTrue);

    await tester.tap(find.byTooltip('Оглавление'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Глава 3'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ContentsScreen), findsNothing);
    expect(reader(tester).layout.sectionIndex, 2);
    final first = reader(tester).page.firstWord;
    expect(reader(tester).layout.pageOfWord(first), 0, reason: 'its start');
    expect(reader(tester).panelsShown, isFalse);
    expect(await tester.runAsync(savedWord), first);

    // The bottom panel names the chapter; the list lights it.
    await tapAt(tester, 0.5);
    expect(find.text('Глава 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Оглавление'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ContentsScreen>(find.byType(ContentsScreen)).current,
      2,
    );
    await closeApp(tester);
  });

  testWidgets('the slider opens a book page; the place can be returned to', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    await tapAt(tester, 0.95);
    final start = reader(tester).page.firstWord;
    final pagination = reader(tester).pagination;
    expect(pagination.isComplete, isTrue);
    int bookPage() =>
        pagination.pagesBefore(reader(tester).layout.sectionIndex).value +
        reader(tester).layout.pageOfWord(reader(tester).page.firstWord) +
        1;
    expect(bookPage(), 2);
    final target = pagination.pagesBefore(2).value + 2;

    // While dragged: the page and chapter it would open; nothing moves.
    await tapAt(tester, 0.5);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 2);
    expect(slider.max, pagination.pageCount.value);
    slider.onChangeStart!(target.toDouble());
    slider.onChanged!(target.toDouble());
    await tester.pump();
    expect(find.text('Глава 3'), findsOneWidget);
    expect(
      find.text('стр. $target / ${pagination.pageCount.value}'),
      findsOneWidget,
    );
    expect(reader(tester).page.firstWord, start);

    slider.onChangeEnd!(target.toDouble());
    await tester.pumpAndSettle();
    expect(reader(tester).layout.sectionIndex, 2);
    expect(bookPage(), target);
    expect(reader(tester).panelsShown, isTrue, reason: 'to drag again');
    expect(await tester.runAsync(savedWord), reader(tester).page.firstWord);

    // A second jump still offers the first place.
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(5);
    await tester.pumpAndSettle();
    expect(bookPage(), 5);
    await tester.tap(find.text('Вернуться на стр. 2'));
    await tester.pumpAndSettle();
    expect(reader(tester).page.firstWord, start);
    expect(find.textContaining('Вернуться'), findsNothing);

    // Turning a page forgets it.
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(7);
    await tester.pumpAndSettle();
    expect(find.text('Вернуться на стр. 2'), findsOneWidget);
    await tapAt(tester, 0.5);
    await tapAt(tester, 0.95);
    await tapAt(tester, 0.5);
    expect(bookPage(), 8);
    expect(find.textContaining('Вернуться'), findsNothing);

    // The table of contents gives chapter start pages.
    await tester.tap(find.byTooltip('Оглавление'));
    await tester.pumpAndSettle();
    final contents = tester.widget<ContentsScreen>(find.byType(ContentsScreen));
    final starts = contents.chapterStarts!();
    expect(starts[0], (value: 1, exact: true));
    expect(starts[2], (value: target - 1, exact: true));
    expect(find.text('${target - 1}'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('A− and A+ stop at the smallest and largest size', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    await tapAt(tester, 0.5);
    OutlinedButton button(String label) => tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(OutlinedButton),
      ),
    );
    for (var i = 0; i < ReadingSettings.fontSizes.length; i++) {
      if (button('A+').onPressed == null) break;
      await tester.tap(find.text('A+'));
      await tester.pumpAndSettle();
    }
    expect(reader(tester).layout.style.fontSize, 32);
    expect(button('A+').onPressed, isNull);
    for (var i = 0; i < ReadingSettings.fontSizes.length; i++) {
      if (button('A−').onPressed == null) break;
      await tester.tap(find.text('A−'));
      await tester.pumpAndSettle();
    }
    expect(reader(tester).layout.style.fontSize, 14);
    expect(button('A−').onPressed, isNull);
    await closeApp(tester);
  });

  /// Long-presses word [word] of the current page.
  Future<void> longPressWord(WidgetTester tester, int word) async {
    final state = reader(tester);
    final box = state.layout
        .wordBoxes(state.layout.pageOfWord(word), word)
        .first;
    final page = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.size == state.layout.pageSize,
    );
    await tester.longPressAt(tester.getTopLeft(page) + box.center);
    await settle(tester);
    await tester.pumpAndSettle();
  }

  /// A tap in the middle of speed reading: start or pause.
  Future<void> tapRsvp(WidgetTester tester) async {
    await tester.tapAt(tester.getCenter(find.byType(RsvpScreen)));
    await tester.pump();
  }

  RsvpScreenState rsvp(WidgetTester tester) =>
      tester.state<RsvpScreenState>(find.byType(RsvpScreen));

  testWidgets('a long press reads from the word; leaving lights the last one', (
    tester,
  ) async {
    // The status bar is hidden: the page keeps its room, speed reading
    // does not.
    tester.view.viewPadding = const FakeViewPadding(top: 144);
    tester.view.padding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    await openBook(tester);
    await tapAt(tester, 0.95);
    final start = reader(tester).page.firstWord + 5;

    await longPressWord(tester, start);
    final engine = rsvp(tester).engine;
    // Opens paused on the pressed word, with the controls.
    expect(engine.isPlaying, isFalse);
    expect(engine.wordIndex, start);
    expect(find.text('Коснитесь экрана, чтобы начать'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(engine.wordIndex, start);
    // Above it, the text before it, ending with the word itself.
    final tokens = rsvp(tester).widget.opened.tokens;
    final pauseText = find.text(
      textBefore(tokens, start) + tokens.textOf(start),
      findRichText: true,
    );
    expect(pauseText, findsOneWidget);

    // A tap starts: 300 wpm by default = 200 ms per word on average,
    // slower at the start and on stops (smart pace).
    await tapRsvp(tester);
    expect(engine.isPlaying, isTrue);
    expect(pauseText, findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(engine.wordIndex, inInclusiveRange(start + 4, start + 12));

    // A tap pauses and shows the controls.
    await tapRsvp(tester);
    expect(engine.isPlaying, isFalse);
    expect(find.text('Коснитесь экрана, чтобы продолжить'), findsOneWidget);
    final last = engine.wordIndex;
    await tester.pump(const Duration(seconds: 1));
    expect(engine.wordIndex, last);
    expect(find.text('300 сл/мин'), findsOneWidget);
    await tester.tap(find.byTooltip('Быстрее'));
    await tester.pump();
    expect(find.text('325 сл/мин'), findsOneWidget);
    await settle(tester);
    expect(
      await tester.runAsync<String?>(
        () => SettingsRepository(db).get(SettingKeys.speedWpm),
      ),
      '325',
    );
    expect(await tester.runAsync(savedWord), last, reason: 'saved on pause');

    // Another tap continues.
    await tapRsvp(tester);
    expect(engine.isPlaying, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tapRsvp(tester);
    final stopped = engine.wordIndex;
    expect(stopped, greaterThan(last));

    await tester.tap(find.byTooltip('Выйти из скорочтения'));
    await tester.pumpAndSettle();
    expect(find.byType(RsvpScreen), findsNothing);
    final page = reader(tester).page;
    expect(page.firstWord, lessThanOrEqualTo(stopped));
    expect(page.endWord, greaterThan(stopped));
    await settle(tester);
    expect(reader(tester).litWord, stopped);
    expect(await tester.runAsync(savedWord), stopped);

    // The normal page of the word, no shift (owner, 2026-10-22).
    final layout = reader(tester).layout;
    expect(page.firstWord, layout.pages[layout.pageOfWord(stopped)].firstWord);
    expect(find.textContaining('≈ '), findsNothing);
    // Forward and back from there: no words lost or repeated.
    final firstWords = [page.firstWord];
    for (var i = 0; i < 3; i++) {
      final before = reader(tester).page;
      await tapAt(tester, 0.95);
      expect(reader(tester).page.firstWord, before.endWord);
      firstWords.add(before.endWord);
    }
    // Back to the book start.
    for (var i = 0; reader(tester).page.firstWord > 0; i++) {
      final before = reader(tester).page;
      if (i < 3) expect(before.firstWord, firstWords[3 - i]);
      await tapAt(tester, 0.05);
      expect(reader(tester).page.endWord, before.firstWord);
    }
    expect(firstWords.first, greaterThan(0), reason: 'pages before it');

    // The speed set before is kept; system back while playing also returns
    // to the page of the word.
    await longPressWord(tester, reader(tester).page.firstWord);
    expect(find.text('325 сл/мин'), findsOneWidget);
    expect((rsvp(tester).engine.timing as SmartPace).wordsPerMinute, 325);
    await tapRsvp(tester);
    expect(find.text('325 сл/мин'), findsNothing, reason: 'playing');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RsvpScreen), findsNothing);
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('the top bar button reads from the page; back and swipes', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    await tapAt(tester, 0.95);
    await tapAt(tester, 0.95);
    final first = reader(tester).page.firstWord;
    final tokens = reader(tester).widget.opened.tokens;

    await tapAt(tester, 0.5);
    await tester.tap(find.text('Скорочтение'));
    await settle(tester);
    await tester.pumpAndSettle();
    final engine = rsvp(tester).engine;
    expect(engine.isPlaying, isFalse, reason: 'opens paused');
    expect(engine.wordIndex, first);
    await tapRsvp(tester);
    expect(engine.isPlaying, isTrue);

    // A few seconds in, a swipe right goes back by a sentence and plays on.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final at = engine.wordIndex;
    await tester.fling(find.byType(RsvpScreen), const Offset(300, 0), 1000);
    expect(engine.wordIndex, sentenceBack(tokens, at));
    expect(engine.isPlaying, isTrue);

    // A swipe up: faster, the speed shows for a moment.
    await tester.fling(find.byType(RsvpScreen), const Offset(0, -300), 1000);
    await tester.pump();
    expect(find.text('325 сл/мин'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('325 сл/мин'), findsNothing);
    await tester.fling(find.byType(RsvpScreen), const Offset(0, 300), 1000);
    await tester.pump();
    expect(find.text('300 сл/мин'), findsOneWidget);

    // Paused: the button goes back too and the place is saved.
    await tapRsvp(tester);
    final paused = engine.wordIndex;
    await tester.tap(find.text('Назад на предложение'));
    await tester.pump();
    expect(engine.wordIndex, sentenceBack(tokens, paused));
    expect(engine.isPlaying, isFalse);
    await settle(tester);
    expect(await tester.runAsync(savedWord), engine.wordIndex);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('the phrase mode shows phrases; leaving lights all of one', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.runAsync(
      () => SettingsRepository(db).set(SettingKeys.speedMode, 'phrase'),
    );
    await openBook(tester);
    await tapAt(tester, 0.95);
    final start = reader(tester).page.firstWord + 5;

    await longPressWord(tester, start);
    final screen = rsvp(tester);
    final engine = screen.engine;
    final tokens = screen.widget.opened.tokens;
    expect(screen.widget.mode, SpeedMode.phrase);
    final steps = engine.steps as PhraseSteps;
    expect(steps.maxChars, inInclusiveRange(12, 24));
    // Opens on the phrase of the pressed word.
    expect(engine.wordIndex, steps.startOf(start));
    expect(engine.wordIndex, lessThanOrEqualTo(start));
    expect(engine.unitEnd, greaterThan(start));

    RsvpWordPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is RsvpWordPainter,
                  ),
                )
                .painter!
            as RsvpWordPainter;
    String shown() => phraseText(tokens, engine.wordIndex, engine.unitEnd);
    // The whole phrase, with no marked letter; on pause the text before it
    // ends with it.
    expect(painter().text, shown());
    expect(painter().orp, isNull);
    expect(
      find.text(
        textBefore(tokens, engine.wordIndex) + shown(),
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tapRsvp(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tapRsvp(tester);
    final word = engine.wordIndex;
    final end = engine.unitEnd;
    expect(word, greaterThan(start));
    expect(end - word, inInclusiveRange(1, PhraseSteps.maxWords));
    expect(painter().text, shown());

    // Its own pace is kept apart from the word mode's.
    await tester.tap(find.byTooltip('Быстрее'));
    await tester.pump();
    await settle(tester);
    expect(
      await tester.runAsync<String?>(
        () =>
            SettingsRepository(db)
                .get(SettingKeys.speedWpmOf(SpeedMode.phrase)),
      ),
      '325',
    );
    expect(
      await tester.runAsync<String?>(
        () => SettingsRepository(db).get(SettingKeys.speedWpm),
      ),
      isNull,
    );

    await tester.tap(find.byTooltip('Выйти из скорочтения'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(reader(tester).litWord, word);
    expect(reader(tester).litEnd, end);
    expect(await tester.runAsync(savedWord), word);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('the pause panel switches word and phrase in place', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.runAsync(
      () =>
          SettingsRepository(db)
              .set(SettingKeys.speedWpmOf(SpeedMode.phrase), '400'),
    );
    await openBook(tester);
    await tapAt(tester, 0.95);
    final start = reader(tester).page.firstWord + 7;

    await longPressWord(tester, start);
    final engine = rsvp(tester).engine;
    expect(engine.steps, isA<WordSteps>());
    expect(find.text('300 сл/мин'), findsOneWidget);

    // To phrases: the phrase of the current word, at the phrase pace.
    await tester.tap(find.text('Фраза'));
    await settle(tester);
    await tester.pump();
    final phrases = engine.steps as PhraseSteps;
    expect(engine.wordIndex, phrases.startOf(start));
    expect(engine.unitEnd, greaterThan(start));
    expect(find.text('400 сл/мин'), findsOneWidget);
    expect((rsvp(tester).engine.timing as SmartPace).wordsPerMinute, 400);
    expect(
      await tester.runAsync<String?>(
        () => SettingsRepository(db).get(SettingKeys.speedMode),
      ),
      'phrase',
    );

    // Reads on in phrases, then back to words from the phrase's first word.
    await tapRsvp(tester);
    await tester.pump(const Duration(seconds: 2));
    await tapRsvp(tester);
    final phrase = engine.wordIndex;
    expect(phrase, greaterThan(start));
    await tester.tap(find.text('Слово'));
    await settle(tester);
    await tester.pump();
    expect(engine.steps, isA<WordSteps>());
    expect(engine.wordIndex, phrase);
    expect(engine.unitEnd, phrase + 1);
    expect(find.text('300 сл/мин'), findsOneWidget);
    expect(await tester.runAsync(savedWord), phrase);

    // "Подсветка" leaves for the book page: the highlight on a pause there.
    await tester.tap(find.text('Подсветка'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.byType(RsvpScreen), findsNothing);
    final guide = reader(tester).guide!;
    expect(guide.word, phrase);
    expect(guide.isPlaying, isFalse);
    expect(reader(tester).page.firstWord, lessThanOrEqualTo(phrase));
    expect(reader(tester).page.endWord, greaterThan(phrase));
    expect(reader(tester).litWord, isNull);
    expect(
      await tester.runAsync<String?>(
        () => SettingsRepository(db).get(SettingKeys.speedMode),
      ),
      'guide',
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('without "Pro" speed reading is words only', (tester) async {
    await pumpApp(tester, pro: false);
    await tester.runAsync(
      () => SettingsRepository(db).set(SettingKeys.speedMode, 'phrase'),
    );
    await openBook(tester);
    await tapAt(tester, 0.95);
    await longPressWord(tester, reader(tester).page.firstWord + 5);

    expect(rsvp(tester).widget.mode, SpeedMode.word);
    expect(rsvp(tester).engine.steps, isA<WordSteps>());
    expect(find.byType(SegmentedButton<SpeedMode>), findsNothing);

    await tester.tap(find.byTooltip('Выйти из скорочтения'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  /// Speed reading pushed over the reader from [word], fast, and started.
  Future<void> speedReadFrom(WidgetTester tester, int word) async {
    final opened = reader(tester).widget.opened;
    unawaited(
      Navigator.of(tester.element(find.byType(ReaderView))).push<RsvpExit>(
        MaterialPageRoute(
          builder: (_) => RsvpScreen(
            opened: opened,
            startWord: word,
            wordsPerMinute: SpeedLimits.max,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapRsvp(tester);
  }

  testWidgets('a new chapter pauses with its title; the book end leads out', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    final tokens = reader(tester).widget.opened.tokens;
    final second = tokens.firstWordOfSection(1);

    await speedReadFrom(tester, second - 3);
    await tester.pump(const Duration(seconds: 2));
    final engine = rsvp(tester).engine;
    expect(engine.isStopped, isTrue);
    expect(engine.wordIndex, second);
    expect(find.text('Новая глава'), findsOneWidget);
    expect(find.text('Глава 2'), findsOneWidget);

    await tester.tap(find.text('Старт'));
    await tester.pump();
    expect(engine.isPlaying, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(engine.wordIndex, greaterThan(second));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(await finishedAt(tester), isNull);
    await speedReadFrom(tester, tokens.length - 3);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Книга закончилась'), findsOneWidget);
    await settle(tester);
    expect(await finishedAt(tester), isNotNull, reason: 'read to the end');
    await tester.tap(find.text('К тексту'));
    await tester.pumpAndSettle();
    expect(find.byType(RsvpScreen), findsNothing);
    await settle(tester);
    expect(await tester.runAsync(savedWord), tokens.length - 1);
    await closeApp(tester);
  });

  testWidgets('the leading highlight goes over the page and turns it', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.runAsync(
      () => SettingsRepository(db).set(SettingKeys.speedMode, 'guide'),
    );
    await openBook(tester);
    final tokens = reader(tester).widget.opened.tokens;
    final start = reader(tester).page.firstWord + 3;

    // A long press starts the saved mode: on the page, on a pause.
    await longPressWord(tester, start);
    final guide = reader(tester).guide!;
    expect(find.byType(RsvpScreen), findsNothing);
    expect(find.byType(GuideLayer), findsOneWidget);
    expect((guide.word, guide.isPlaying), (start, false));
    expect(find.text('Коснитесь экрана, чтобы начать'), findsOneWidget);

    // A tap in the middle starts; 250 wpm by default.
    await tapAt(tester, 0.5);
    expect(guide.isPlaying, isTrue);
    expect(find.byType(GuidePanel), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(guide.word, inInclusiveRange(start + 3, start + 12));

    // Right after the last word of the page, the next one opens.
    final first = reader(tester).page;
    for (var i = 0; i < 600 && reader(tester).page == first; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final next = reader(tester).page;
    expect(next.firstWord, first.endWord);
    expect(guide.word, next.firstWord);
    await settle(tester);
    expect(await tester.runAsync(savedWord), next.firstWord);

    // A tap pauses; the place is saved.
    await tapAt(tester, 0.5);
    expect(guide.isPlaying, isFalse);
    expect(find.text('Коснитесь экрана, чтобы продолжить'), findsOneWidget);
    final paused = guide.word;
    await tester.pump(const Duration(seconds: 1));
    expect(guide.word, paused);
    expect(await tester.runAsync(savedWord), paused);

    // On a pause the page turns; going on starts from its first word.
    await tapAt(tester, 0.95);
    final turned = reader(tester).page;
    expect(turned.firstWord, next.endWord);
    await tapAt(tester, 0.5);
    expect(guide.word, turned.firstWord);
    expect(guide.isPlaying, isTrue);

    // Swipes while playing: right goes back by a sentence, up is faster.
    await tester.pump(const Duration(seconds: 2));
    final at = guide.word;
    await tester.fling(find.byType(ReaderView), const Offset(300, 0), 1000);
    expect(guide.word, sentenceBack(tokens, at));
    expect(guide.isPlaying, isTrue);
    expect(reader(tester).page.firstWord, lessThanOrEqualTo(guide.word));
    await tester.fling(find.byType(ReaderView), const Offset(0, -300), 1000);
    await tester.pump();
    expect(find.text('275 сл/мин'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('275 сл/мин'), findsNothing);
    await settle(tester);
    expect(
      await tester.runAsync<String?>(
        () =>
            SettingsRepository(db).get(SettingKeys.speedWpmOf(SpeedMode.guide)),
      ),
      '275',
    );

    // Leaving: the word stays lit for a moment, the place on it.
    await tapAt(tester, 0.5);
    final last = guide.word;
    await tester.tap(find.text('Выйти из подсветки'));
    await tester.pump();
    expect(reader(tester).guide, isNull);
    expect(find.byType(GuideLayer), findsNothing);
    expect(reader(tester).litWord, last);
    await settle(tester);
    expect(await tester.runAsync(savedWord), last);
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('the highlight pause panel: back, speed, settings, and modes '
      'there and back keep the word', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(
      () => SettingsRepository(db).set(SettingKeys.speedMode, 'guide'),
    );
    await openBook(tester);
    final tokens = reader(tester).widget.opened.tokens;
    await tapAt(tester, 0.95);
    final start = reader(tester).page.firstWord + 7;
    await longPressWord(tester, start);
    final guide = reader(tester).guide!;
    expect(find.byType(GuidePanel), findsOneWidget);
    expect(find.text('250 сл/мин'), findsOneWidget);

    // Speed − on a pause: the pause stays, the speed is saved.
    await tester.tap(find.byTooltip('Медленнее'));
    await tester.pump();
    expect(find.text('225 сл/мин'), findsOneWidget);
    expect(guide.isPlaying, isFalse);
    await settle(tester);
    expect(
      await tester.runAsync<String?>(
        () =>
            SettingsRepository(db).get(SettingKeys.speedWpmOf(SpeedMode.guide)),
      ),
      '225',
    );

    // Back by a sentence, still on a pause.
    await tester.tap(find.byTooltip('Назад на предложение'));
    await tester.pump();
    final word = sentenceBack(tokens, start);
    expect((guide.word, guide.isPlaying), (word, false));
    await settle(tester);
    expect(await tester.runAsync(savedWord), word);

    // The settings over the pause: a larger font keeps the word on the page;
    // a tap on the page closes them, the pause panel is back.
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadingSettingsPanel), findsOneWidget);
    expect(find.byType(GuidePanel), findsNothing);
    await tester.tap(find.byTooltip('Шрифт больше'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(guide.word, word);
    expect(reader(tester).page.firstWord, lessThanOrEqualTo(word));
    expect(reader(tester).page.endWord, greaterThan(word));
    final size = tester.getSize(find.byType(ReaderView));
    await tester.tapAt(Offset(size.width / 2, size.height / 8));
    await tester.pumpAndSettle();
    expect(find.byType(ReadingSettingsPanel), findsNothing);
    expect(find.byType(GuidePanel), findsOneWidget);
    expect(guide.isPlaying, isFalse);

    // To words: speed reading from the highlighted word, saved as the mode.
    await tester.tap(find.text('Слово'));
    await tester.pumpAndSettle();
    expect(rsvp(tester).widget.mode, SpeedMode.word);
    expect(rsvp(tester).engine.wordIndex, word);
    expect(
      await tester.runAsync<String?>(
        () => SettingsRepository(db).get(SettingKeys.speedMode),
      ),
      'word',
    );

    // And back: the highlight on a pause at the same word.
    await tester.tap(find.text('Подсветка'));
    await tester.pumpAndSettle();
    await settle(tester);
    final back = reader(tester).guide!;
    expect((back.word, back.isPlaying), (word, false));
    expect(find.text('225 сл/мин'), findsOneWidget);

    // To phrases: the phrase of the word.
    await tester.tap(find.text('Фраза'));
    await tester.pumpAndSettle();
    await settle(tester);
    await tester.pump();
    final engine = rsvp(tester).engine;
    expect(engine.steps, isA<PhraseSteps>());
    expect(engine.wordIndex, (engine.steps as PhraseSteps).startOf(word));

    await tester.tap(find.byTooltip('Выйти из скорочтения'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('the highlight pauses before a new chapter and ends the book', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    final tokens = reader(tester).widget.opened.tokens;
    final second = tokens.firstWordOfSection(1);

    await reader(tester).guideFrom(second - 3);
    await settle(tester);
    await tapAt(tester, 0.5);
    await tester.pump(const Duration(seconds: 3));
    final guide = reader(tester).guide!;
    expect((guide.isStopped, guide.word), (true, second));
    expect(reader(tester).page.firstWord, lessThanOrEqualTo(second));
    expect(reader(tester).page.endWord, greaterThan(second));
    expect(find.text('Новая глава'), findsOneWidget);
    await tester.tap(find.byTooltip('Старт'));
    await tester.pump();
    expect(guide.isPlaying, isTrue);
    // The title's first word starts a page and the gentle start: ~1.1 s.
    await tester.pump(const Duration(seconds: 2));
    expect(guide.word, greaterThan(second));
    await tapAt(tester, 0.5);

    expect(await finishedAt(tester), isNull);
    await reader(tester).guideFrom(tokens.length - 3);
    await settle(tester);
    await tapAt(tester, 0.5);
    await tester.pump(const Duration(seconds: 3));
    expect(reader(tester).guide!.isFinished, isTrue);
    expect(find.text('Книга закончилась'), findsOneWidget);
    await settle(tester);
    expect(await finishedAt(tester), isNotNull, reason: 'read to the end');
    await tester.tap(find.text('К тексту'));
    await tester.pump();
    expect(reader(tester).guide, isNull);
    await settle(tester);
    expect(await tester.runAsync(savedWord), tokens.length - 1);
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('the last page marks the book read; turning back keeps it', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    final words = reader(tester).widget.opened.tokens.length;

    // A slider jump to the end is only a look.
    final pages = reader(tester).pagination.pageCount.value;
    await tapAt(tester, 0.5);
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(pages.toDouble());
    await tester.pumpAndSettle();
    expect(reader(tester).page.endWord, words);
    expect(await finishedAt(tester), isNull);
    await tester.tap(find.textContaining('Вернуться'));
    await tester.pumpAndSettle();
    await tapAt(tester, 0.5);

    for (var i = 0; i < 200 && reader(tester).page.endWord < words; i++) {
      expect(await finishedAt(tester), isNull, reason: 'page $i');
      await tapAt(tester, 0.95);
    }
    expect(reader(tester).page.endWord, words);
    final finished = await finishedAt(tester);
    expect(finished, isNotNull);

    await tapAt(tester, 0.05);
    await tapAt(tester, 0.05);
    expect(reader(tester).page.endWord, lessThan(words));
    expect(await finishedAt(tester), finished);
    await closeApp(tester);
  });

  testWidgets('a long press between words does nothing', (tester) async {
    await pumpApp(tester);
    await openBook(tester);
    final size = tester.getSize(find.byType(ReaderView));
    // Below the page text, in the footer row's left part.
    await tester.longPressAt(Offset(size.width / 2, size.height - 4));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(RsvpScreen), findsNothing);
    await closeApp(tester);
  });

  testWidgets('the book page counts the pages the reader shows; queued goes '
      'away when the book is read on, not when it is opened', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(() => repo.setStatusMark(bookId, StatusMark.queued));
    await openBook(tester);
    await settle(tester);
    Future<StatusMark?> mark() async =>
        (await tester.runAsync(() => repo.findById(bookId)))!.statusMark;
    expect(await mark(), StatusMark.queued, reason: 'opening is not reading');

    for (var i = 0; i < 4; i++) {
      await tapAt(tester, 0.95);
    }
    expect(await mark(), isNull);

    final pagination = reader(tester).pagination;
    expect(pagination.isComplete, isTrue);
    final last = LastLayout.decode(
      await tester.runAsync<String?>(
        () => SettingsRepository(db).get(SettingKeys.readerLastLayout),
      ),
    )!;
    final words = reader(tester).widget.opened.tokens.length;
    expect(last.wordsPerPage, words / pagination.pageCount.value);

    // The book page builds the key from the settings the same way.
    final style = pageStyleOf(
      const ReadingSettings(),
      system: TextScaler.noScaling,
      color: const Color(0xFF000000),
    );
    expect(last.styleKey, styleKeyOf(style: style, pageSize: last.pageSize));
    final book = (await tester.runAsync(() => repo.findById(bookId)))!;
    final pages = bookPagesOf(
      words: book.wordCount,
      positionWord: book.positionWord,
      style: style,
      pageSize: last.pageSize,
      cached: PageCache(store.pagesDir(bookId)).peek(
        layoutKeyOf(
          style: style,
          pageSize: last.pageSize,
          parserVersion: book.parserVersion,
        ),
        words: book.wordCount,
      ),
      last: last,
    );
    expect(pages.exact, isTrue);
    expect(pages.total, pagination.pageCount.value);
    expect(
      pages.current,
      pagination.pagesBefore(reader(tester).layout.sectionIndex).value +
          reader(tester).layout.pageOfWord(reader(tester).page.firstWord) +
          1,
    );
    expect(pages.current, 5);
    await tapAt(tester, 0.5);
    expect(
      find.text('стр. ${pages.current} / ${pages.total}${percent(tester)}'),
      findsOneWidget,
    );
    await closeApp(tester);
  });

  testWidgets('stage 10: the page of the word after words, then back and '
      'forward on a pause: the first word of a page lasts longer', (
    tester,
  ) async {
    tester.view.viewPadding = const FakeViewPadding(top: 144);
    tester.view.padding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    await openBook(tester);
    final tokens = reader(tester).widget.opened.tokens;
    for (var i = 0; i < 60 && reader(tester).layout.sectionIndex < 1; i++) {
      await tapAt(tester, 0.95);
    }
    await tapAt(tester, 0.95);
    expect(reader(tester).layout.sectionIndex, 1);
    final start = reader(tester).page.firstWord + 6;

    await longPressWord(tester, start);
    await tapRsvp(tester);
    await tester.pump(const Duration(seconds: 2));
    await tapRsvp(tester);
    final stopped = rsvp(tester).engine.wordIndex;
    expect(stopped, greaterThan(start));
    await tester.tap(find.text('Подсветка'));
    await tester.pumpAndSettle();
    await settle(tester);

    // The guide starts on the stopped word, on its page.
    final guide = reader(tester).guide!;
    expect(guide.word, stopped);
    expect(reader(tester).page.firstWord, lessThanOrEqualTo(stopped));
    expect(reader(tester).page.endWord, greaterThan(stopped));
    expect(guide.page.first, reader(tester).page.firstWord);

    // Back to the previous chapter and forward again, on a pause.
    for (var i = 0; i < 60 && reader(tester).layout.sectionIndex > 0; i++) {
      await tapAt(tester, 0.05);
    }
    expect(reader(tester).layout.sectionIndex, 0);
    for (var i = 0; i < 60 && reader(tester).layout.sectionIndex < 1; i++) {
      await tapAt(tester, 0.95);
    }
    for (var i = 0; i < 60 && reader(tester).page.firstWord <= stopped; i++) {
      await tapAt(tester, 0.95);
    }
    final page = reader(tester).page;
    expect(page.firstWord, greaterThan(stopped));
    expect(guide.isPlaying, isFalse);

    await tapAt(tester, 0.5);
    expect(guide.isPlaying, isTrue);
    expect(guide.word, page.firstWord);
    // 250 wpm; the gentle start (1/0.6) and the page start (1.8) apply.
    final pace = SmartPace(tokens, 250);
    final expected =
        pace.durationOf(page.firstWord).inMicroseconds *
        PaceRules.pageStart /
        0.6 /
        1000;
    final plain = pace.durationOf(page.firstWord).inMicroseconds / 0.6 / 1000;
    var elapsed = 0;
    while (guide.word == page.firstWord && elapsed < 5000) {
      await tester.pump(const Duration(milliseconds: 10));
      elapsed += 10;
    }
    expect(elapsed, closeTo(expected, 40), reason: 'plain would be $plain');
    expect(elapsed, greaterThan(plain + 20));

    await tapAt(tester, 0.5);
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('stage 12: a tap on a footnote label opens the note, not a '
      'page turn or the panels; the page stays', (tester) async {
    final base = sampleBook(sections: 2, paragraphs: 14);
    final first = base.sections.first;
    final book = BookContent(
      meta: base.meta,
      sections: [
        Section(
          title: first.title,
          blocks: [
            const ParagraphBlock(
              text: 'Он отозвался1, и ушёл.',
              spans: [Span(12, 13, SpanKind.noteRef, noteId: 'n1')],
            ),
            ...first.blocks,
          ],
        ),
        ...base.sections.skip(1),
      ],
      notes: const {
        'n1': Note(
          label: '1',
          blocks: [ParagraphBlock(text: 'Сноска.')],
        ),
      },
    );
    await pumpApp(tester, book: book);
    await openBook(tester);
    final state = reader(tester);
    final tokens = state.widget.opened.tokens;
    final said = [
      for (var i = 0; i < tokens.length; i++)
        if (tokens.textOf(i).startsWith('отозвался')) i,
    ].single;
    final page = state.page;
    final box = state.layout.wordBoxes(state.layout.pageOfWord(said), said);
    final origin = tester.getTopLeft(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.size == state.layout.pageSize,
      ),
    );
    await tester.tapAt(origin + box.first.topRight + const Offset(4, 0));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(NoteSheet), findsOneWidget);
    expect(find.text('Сноска.', findRichText: true), findsOneWidget);
    expect(reader(tester).panelsShown, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NoteSheet), findsNothing);
    expect(reader(tester).page, same(page));
    expect(reader(tester).panelsShown, isFalse);
    await closeApp(tester);
  });

  /// [sampleBook] (it has pictures of its own) with picture `1.jpg` after
  /// paragraph 5 of chapter 1 and at the start of chapter 2.
  BookContent bookWithPictures() {
    final base = sampleBook(sections: 3, paragraphs: 14);
    const picture = ImageBlock(assetId: '1.jpg', width: 600, height: 900);
    final first = base.sections[0];
    final second = base.sections[1];
    return BookContent(
      meta: base.meta,
      sections: [
        Section(
          title: first.title,
          blocks: [...first.blocks.take(6), picture, ...first.blocks.skip(6)],
        ),
        Section(title: second.title, blocks: [picture, ...second.blocks]),
        ...base.sections.skip(2),
      ],
    );
  }

  testWidgets('stage 12: speed reading pauses on a picture; a tap goes on, '
      'to the chapter start if one follows', (tester) async {
    await pumpApp(tester, book: bookWithPictures());
    await openBook(tester);
    final tokens = reader(tester).widget.opened.tokens;
    final [inside, second] = [
      for (var w = 0; w < tokens.length; w++)
        if (tokens.imagesBefore(w).any((i) => i.image.assetId == '1.jpg')) w,
    ];
    expect(tokens.flagsOf(second) & TokenFlags.sectionStart, isNonZero);

    await speedReadFrom(tester, inside - 3);
    await tester.pump(const Duration(seconds: 2));
    final engine = rsvp(tester).engine;
    expect((engine.isStopped, engine.wordIndex), (true, inside));
    expect(find.byType(PagePicture), findsOneWidget);
    expect(find.text('Коснитесь экрана, чтобы продолжить'), findsOneWidget);
    expect(find.byType(SpeedStepper), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(engine.wordIndex, inside, reason: 'waits for a tap');
    await tapRsvp(tester);
    expect(engine.isPlaying, isTrue);
    expect(find.byType(PagePicture), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(engine.wordIndex, greaterThan(inside));

    // A picture before a chapter: the picture, then the chapter start.
    engine.seek(second - 3);
    await tester.pump(const Duration(seconds: 2));
    expect((engine.isStopped, engine.wordIndex), (true, second));
    expect(find.byType(PagePicture), findsOneWidget);
    expect(find.text('Новая глава'), findsNothing);
    await tapRsvp(tester);
    expect(engine.isStopped, isTrue);
    expect(find.byType(PagePicture), findsNothing);
    expect(find.text('Новая глава'), findsOneWidget);
    await tester.tap(find.text('Старт'));
    await tester.pump();
    expect(engine.isPlaying, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await closeApp(tester);
  });

  testWidgets('stage 12: the highlight stops on the page of a picture with no '
      'panel; a tap goes on', (tester) async {
    await pumpApp(tester, book: bookWithPictures());
    await openBook(tester);
    final tokens = reader(tester).widget.opened.tokens;
    final [inside, second] = [
      for (var w = 0; w < tokens.length; w++)
        if (tokens.imagesBefore(w).any((i) => i.image.assetId == '1.jpg')) w,
    ];
    expect(tokens.flagsOf(second) & TokenFlags.sectionStart, isNonZero);

    await reader(tester).guideFrom(inside - 3);
    await settle(tester);
    await tapAt(tester, 0.5);
    await tester.pump(const Duration(seconds: 3));
    final guide = reader(tester).guide!;
    expect((guide.isStopped, guide.word), (true, inside));
    expect(find.byType(GuidePanel), findsNothing);
    expect(find.byType(PagePicture), findsOneWidget);
    await tapAt(tester, 0.9);
    expect(guide.isPlaying, isTrue, reason: 'any tap goes on');
    await tester.pump(const Duration(seconds: 2));
    expect(guide.word, greaterThan(inside));
    expect(reader(tester).page.endWord, greaterThan(guide.word));
    await tapAt(tester, 0.5);

    // Before a chapter: the picture, then its first page and the panel.
    await reader(tester).guideFrom(second - 3);
    await settle(tester);
    await tapAt(tester, 0.5);
    await tester.pump(const Duration(seconds: 3));
    final next = reader(tester).guide!;
    expect((next.isStopped, next.word), (true, second));
    expect(find.byType(GuidePanel), findsNothing);
    expect(find.byType(PagePicture), findsOneWidget);
    await tapAt(tester, 0.5);
    expect(next.isPlaying, isFalse);
    expect(find.text('Новая глава'), findsOneWidget);
    expect(reader(tester).page.firstWord, second);
    await tester.tap(find.byTooltip('Старт'));
    await tester.pump();
    expect(next.isPlaying, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(next.word, greaterThan(second));
    await tapAt(tester, 0.5);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('stage 12: a new book opens on its cover; a lost picture is a '
      'frame with an icon', (tester) async {
    final base = sampleBook(sections: 2, paragraphs: 14);
    final book = BookContent(
      meta: base.meta,
      sections: [
        Section(
          title: base.sections.first.title,
          blocks: [
            const ImageBlock(assetId: '1.jpg', width: 600, height: 900),
            ...base.sections.first.blocks,
          ],
        ),
        ...base.sections.skip(1),
      ],
    );
    await pumpApp(tester, book: book);
    await openBook(tester);
    expect(reader(tester).page.hasWords, isFalse, reason: 'the cover');
    expect(find.byType(PageImages), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    for (
      var i = 0;
      i < 50 && find.byIcon(Icons.broken_image_outlined).evaluate().isEmpty;
      i++
    ) {
      await settle(tester);
    }
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);

    // A tap on the picture opens it over the whole screen, not the panels.
    await tapAt(tester, 0.5);
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsNothing);
    expect(reader(tester).panelsShown, isFalse);

    // On to the text: the place is its first word; back to the cover.
    await tapAt(tester, 0.95);
    expect(reader(tester).page.hasWords, isTrue);
    expect(reader(tester).page.firstWord, 0);
    expect(find.byType(Image), findsNothing);
    await tapAt(tester, 0.05);
    expect(reader(tester).page.hasWords, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('stage 10: a wordless last page (separators) on a guide pause', (
    tester,
  ) async {
    final base = sampleBook(sections: 1, paragraphs: 14);
    final last = base.sections.last;
    final book = BookContent(
      meta: base.meta,
      sections: [
        Section(
          title: last.title,
          blocks: [
            ...last.blocks,
            for (var i = 0; i < 80; i++) const SeparatorBlock(),
          ],
        ),
      ],
    );
    await pumpApp(tester, book: book);
    await openBook(tester);
    final tokens = reader(tester).widget.opened.tokens;
    final pages = reader(tester).layout.pages;
    expect(pages.last.hasWords, isFalse, reason: 'the book ends on a picture');

    await reader(tester).guideFrom(tokens.length - 3);
    await settle(tester);
    final guide = reader(tester).guide!;
    for (var i = 0; i < 20 && reader(tester).page.endWord < tokens.length;) {
      await tapAt(tester, 0.95);
      i++;
    }
    // On to the pictures: pages without words.
    for (var i = 0; i < 10; i++) {
      await tapAt(tester, 0.95);
      expect(tester.takeException(), isNull);
    }
    expect(reader(tester).page.hasWords, isFalse);
    expect(guide.word, lessThan(tokens.length));

    // Back and forward over them, then go on.
    await tapAt(tester, 0.05);
    await tapAt(tester, 0.95);
    expect(tester.takeException(), isNull);
    await tapAt(tester, 0.5);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    await settle(tester);
    expect(await tester.runAsync(savedWord), lessThan(tokens.length));
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('stage 10: a wrapped word has marks on both lines', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    final tokens = reader(tester).widget.opened.tokens;
    final long = [
      for (var i = 0; i < tokens.length; i++)
        if (tokens.textOf(i).startsWith('Сверх')) i,
    ].first;
    await reader(tester).guideFrom(long);
    await settle(tester);
    final layout = reader(tester).layout;
    final boxes = layout.wordBoxes(
      reader(tester).layout.pageOfWord(long),
      long,
    );
    expect(boxes.length, greaterThan(1), reason: 'the word is wrapped');
    expect(boxes.first.top, lessThan(boxes.last.top));
    expect(find.byType(GuideLayer), findsOneWidget);
    // It plays over the wrapped word and on.
    await tapAt(tester, 0.5);
    await tester.pump(const Duration(seconds: 2));
    expect(reader(tester).guide!.word, greaterThan(long));
    expect(tester.takeException(), isNull);
    await tapAt(tester, 0.5);
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  testWidgets('stage 10: without Pro a saved guide opens as words', (
    tester,
  ) async {
    await pumpApp(tester, pro: false);
    await tester.runAsync(
      () => SettingsRepository(db).set(SettingKeys.speedMode, 'guide'),
    );
    await openBook(tester);
    await longPressWord(tester, reader(tester).page.firstWord + 5);
    expect(rsvp(tester).widget.mode, SpeedMode.word);
    expect(find.byType(SegmentedButton<SpeedMode>), findsNothing);
    expect(find.text('Подсветка'), findsNothing);
    expect(find.text('Фраза'), findsNothing);
    await tester.tap(find.byTooltip('Выйти из скорочтения'));
    await tester.pumpAndSettle();
    expect(reader(tester).guide, isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await closeApp(tester);
  });

  /// Time (ms) and words read by eye, written so far.
  Future<(int, int)> pageStats(WidgetTester tester) async {
    await settle(tester);
    final rows = await tester.runAsync(() => StatsRepository(db).readingDays());
    final pages = rows!.where((r) => r.mode == ReadingMode.page);
    return (
      pages.fold(0, (sum, r) => sum + r.activeMs),
      pages.fold(0, (sum, r) => sum + r.words),
    );
  }

  void lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
    for (final state in states) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  testWidgets('stage 13: a page counts only while it is seen', (tester) async {
    await pumpApp(tester);
    await openBook(tester);
    final first = reader(tester).page;
    wait(10);
    await tapAt(tester, 0.95);
    final second = reader(tester).page;
    expect(first.endWord - first.firstWord, greaterThan(20));
    expect(second.endWord - second.firstWord, greaterThan(20));

    // The panels and the background stop the time.
    await tapAt(tester, 0.5);
    expect(reader(tester).panelsShown, isTrue);
    wait(100);
    await tapAt(tester, 0.5);
    expect(reader(tester).panelsShown, isFalse);
    wait(10);
    lifecycle(tester, [AppLifecycleState.inactive, AppLifecycleState.hidden]);
    expect(await pageStats(tester), (
      10000,
      first.endWord - first.firstWord,
    ), reason: 'written on hiding');
    wait(500);
    lifecycle(tester, [AppLifecycleState.inactive, AppLifecycleState.resumed]);
    wait(5);
    // Control Center over the app (inactive, not hidden) stops it too.
    lifecycle(tester, [AppLifecycleState.inactive]);
    wait(300);
    lifecycle(tester, [AppLifecycleState.resumed]);
    wait(5);
    // Leafing back and forth (under 2 s) counts nothing.
    await tapAt(tester, 0.05);
    wait(1);
    await tapAt(tester, 0.95);
    wait(5);
    await closeApp(tester);

    expect(await pageStats(tester), (
      10000 + 20000 + 5000,
      first.endWord - first.firstWord + 2 * (second.endWord - second.firstWord),
    ));
  });

  testWidgets('stage 13: speed reading takes the page over at the word', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    await tapAt(tester, 0.95);
    final page = reader(tester).page;
    final start = page.firstWord + 30;
    expect(page.endWord, greaterThan(start + 20));
    wait(10);
    await longPressWord(tester, start);
    // The time in speed reading is not the page's.
    wait(100);
    await tester.tap(find.byTooltip('Выйти из скорочтения'));
    await tester.pumpAndSettle();
    expect(reader(tester).page.firstWord, page.firstWord);
    final end = reader(tester).litEnd;
    wait(10);
    await closeApp(tester);

    expect(await pageStats(tester), (20000, 30 + page.endWord - end));
  });

  /// Speed reading rows written so far: time and words by mode, and the
  /// pace rows of [mode].
  Future<
    ({
      Map<ReadingMode, (int, int)> reading,
      Map<int, (int, int, int, int)> pace,
    })
  >
  speedStats(WidgetTester tester, SpeedMode mode) async {
    await settle(tester);
    final stats = StatsRepository(db);
    final rows = (await tester.runAsync(stats.readingDays))!;
    final pace = (await tester.runAsync(() => stats.paceDays(mode: mode)))!;
    return (
      reading: {
        for (final r in rows)
          if (r.mode != ReadingMode.page) r.mode: (r.activeMs, r.words),
      },
      pace: {
        for (final r in pace) r.wpm: (r.words, r.activeMs, r.backs, r.pauses),
      },
    );
  }

  /// [seconds] of playing: the meters' clock goes with the frames.
  Future<void> play(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      wait(1);
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('stage 13: speed reading counts playing time, words, backs and '
      'pauses before going on', (tester) async {
    await pumpApp(tester);
    await openBook(tester);
    await tapAt(tester, 0.95);
    final start = reader(tester).page.firstWord + 5;
    await longPressWord(tester, start);
    final engine = rsvp(tester).engine;
    wait(30); // paused at the start: not counted

    await tapRsvp(tester);
    await play(tester, 3);
    await tapRsvp(tester);
    final paused = engine.wordIndex;
    expect(paused, greaterThan(start));
    wait(10);
    await tester.tap(find.byTooltip('Быстрее'));
    await tester.pump();
    await tapRsvp(tester);
    await play(tester, 1);
    await tapRsvp(tester);
    final stopped = engine.wordIndex;
    expect(stopped, greaterThan(paused));
    // Back on a pause; the pause before leaving is no signal.
    await tester.tap(find.text('Назад на предложение'));
    await tester.pump();
    wait(10);
    await tester.tap(find.byTooltip('Выйти из скорочтения'));
    await tester.pumpAndSettle();
    await closeApp(tester);

    final stats = await speedStats(tester, SpeedMode.word);
    expect(stats.reading, {ReadingMode.word: (4000, stopped - start)});
    expect(stats.pace, {
      300: (paused - start, 3000, 0, 1),
      325: (stopped - paused, 1000, 1, 0),
    });
  });

  testWidgets('stage 13: the highlight counts as speed reading, not as the '
      'page', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(
      () => SettingsRepository(db).set(SettingKeys.speedMode, 'guide'),
    );
    await openBook(tester);
    await tapAt(tester, 0.95);
    final start = reader(tester).page.firstWord + 5;
    wait(10);
    await longPressWord(tester, start);
    final guide = reader(tester).guide!;
    wait(30); // on a pause: neither page nor highlight

    await tapAt(tester, 0.5);
    expect(guide.isPlaying, isTrue);
    await play(tester, 2);
    await tester.tapAt(tester.getCenter(find.byType(ReaderView)));
    await tester.pump();
    expect(guide.isPlaying, isFalse);
    final paused = guide.word;
    await tester.tap(find.byTooltip('Назад на предложение'));
    await tester.pump();
    // The app goes to the background while playing: no pause signal.
    await tapAt(tester, 0.5);
    await play(tester, 1);
    lifecycle(tester, [AppLifecycleState.inactive, AppLifecycleState.hidden]);
    await tester.pump();
    expect(guide.isPlaying, isFalse);
    final furthest = max(paused, guide.word);
    wait(100);
    lifecycle(tester, [AppLifecycleState.inactive, AppLifecycleState.resumed]);
    await closeApp(tester);

    final stats = await speedStats(tester, SpeedMode.guide);
    final words = stats.reading[ReadingMode.guide]!.$2;
    expect(stats.reading.keys, [ReadingMode.guide]);
    expect(stats.reading[ReadingMode.guide]!.$1, 3000);
    // Words read again after «back» are not added.
    expect(words, furthest - start);
    expect(stats.pace, {250: (words, 3000, 1, 1)});
    expect(await pageStats(tester), (
      10000,
      5,
    ), reason: 'the page up to the word');
  });

  testWidgets('stage 13: a chapter stop is neither time nor a pause', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    final second = reader(tester).widget.opened.tokens.firstWordOfSection(1);
    await speedReadFrom(tester, second - 3);
    await play(tester, 2);
    final engine = rsvp(tester).engine;
    expect(engine.isStopped, isTrue);
    wait(100);
    await tester.tap(find.text('Старт'));
    await tester.pump();
    await play(tester, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await closeApp(tester);

    final stats = await speedStats(tester, SpeedMode.word);
    expect(stats.reading[ReadingMode.word]!.$1, inInclusiveRange(1000, 3000));
    expect(stats.pace[SpeedLimits.max]!.$4, 0, reason: 'no pauses');
  });

  testWidgets('stage 13: the time left line opens the sheet; the setting '
      'hides it', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(
      () => StatsRepository(db).add(
        reading: [
          for (final day in [20261023, 20261022, 20261020])
            ReadingDelta(
              day: day,
              bookId: bookId,
              mode: ReadingMode.page,
              dayPart: 2,
              activeMs: 30 * 60000,
              words: 7350,
              pageSpeeds: const {24: 12},
            ),
        ],
      ),
    );
    await openBook(tester);
    await tapAt(tester, 0.5);
    await settle(tester);
    final line = find.textContaining('до конца книги');
    expect(line, findsOneWidget);
    expect(
      tester.widget<Text>(line).data,
      allOf(startsWith('≈ '), contains('до конца главы ·')),
      reason: 'the time to the chapter end first',
    );

    await tester.tap(line);
    await tester.pumpAndSettle();
    expect(find.byType(BookStatsSheet), findsOneWidget);
    expect(find.text('Эта книга'.toUpperCase()), findsOneWidget);
    expect(find.text('245'), findsOneWidget, reason: 'the median by eye');
    expect(
      find.text('скорость уточняется'),
      findsOneWidget,
      reason: 'no speed reading yet',
    );
    expect(find.text('1 ч 30 мин'), findsOneWidget, reason: 'time spent');
    expect(find.textContaining('дочитаете'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BookStatsSheet), findsNothing);
    expect(reader(tester).panelsShown, isTrue, reason: 'the panels stay');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    );
    final notifier = container.read(readingSettingsProvider.notifier);
    notifier.set(
      container.read(readingSettingsProvider).copyWith(showStats: false),
    );
    await tester.pumpAndSettle();
    expect(line, findsNothing);
    await closeApp(tester);
  });

  testWidgets('stage 13: a new book has the line at once, at a stand-in '
      'speed', (tester) async {
    await pumpApp(tester);
    await openBook(tester);
    await tapAt(tester, 0.5);
    await settle(tester);
    expect(find.textContaining('до конца книги'), findsOneWidget);
    await tester.tap(find.textContaining('до конца книги'));
    await tester.pumpAndSettle();
    expect(find.text('скорость уточняется'), findsNWidgets(2));
    expect(find.textContaining('дочитаете'), findsNothing);
    await closeApp(tester);
  });

  testWidgets('14.14: the strip scrolls across chapters; its top row gives '
      'the page and the place, kept when it goes off', (tester) async {
    await pumpApp(tester);
    await openBook(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    );
    final notifier = container.read(readingSettingsProvider.notifier);
    void strip({required bool on}) => notifier.set(
      container.read(readingSettingsProvider).copyWith(verticalScroll: on),
    );
    strip(on: true);
    await tester.pumpAndSettle();
    expect(find.byType(CustomScrollView), findsOne);
    expect(reader(tester).page.firstWord, 0);
    final pages = reader(tester).layout.pages.length;

    final height = tester.getSize(find.byType(ReaderView)).height;
    var page = 0;
    for (var i = 0; i < 40 && reader(tester).layout.sectionIndex == 0; i++) {
      await tester.drag(
        find.byType(CustomScrollView),
        Offset(0, -height * 0.8),
      );
      await tester.pumpAndSettle();
      await settle(tester);
      final shown = reader(tester).layout.pages.indexOf(reader(tester).page);
      if (reader(tester).layout.sectionIndex == 0) {
        expect(shown, greaterThanOrEqualTo(page), reason: 'no page skipped');
        page = shown;
      }
    }
    expect(page, pages - 1);
    final r = reader(tester);
    expect(r.layout.sectionIndex, greaterThan(0), reason: 'next chapter');
    final saved = await tester.runAsync(savedWord);
    expect(saved, inInclusiveRange(r.page.firstWord, r.page.endWord - 1));
    final number = r.pagination.pagesBefore(r.layout.sectionIndex).value + 1;
    expect(
      find.textContaining('стр. ${number + r.layout.pages.indexOf(r.page)} /'),
      findsOne,
    );

    await tapAt(tester, 0.5);
    expect(reader(tester).panelsShown, isTrue);
    await tapAt(tester, 0.5);
    expect(reader(tester).panelsShown, isFalse);

    strip(on: false);
    await tester.pumpAndSettle();
    expect(find.byType(CustomScrollView), findsNothing);
    final shown = reader(tester).page;
    expect(saved, inInclusiveRange(shown.firstWord, shown.endWord - 1));
    await closeApp(tester);
  });

  testWidgets('14.14: side taps scroll the strip by a screen less a line; a '
      'long press reads from a page below; a tap on a moving strip stops it', (
    tester,
  ) async {
    await pumpApp(tester);
    await openBook(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    );
    container
        .read(readingSettingsProvider.notifier)
        .set(
          container.read(readingSettingsProvider).copyWith(verticalScroll: true),
        );
    await tester.pumpAndSettle();
    final strip = find.byType(CustomScrollView);
    double offset() =>
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    final window = tester.getSize(strip).height - readerTopMargin;
    final line = reader(tester).layout.style.bodyLine;

    final start = offset();
    await tapAt(tester, 0.95);
    final step = offset() - start;
    // The row cut at the bottom comes up whole (a gap may be skipped).
    expect(step, inInclusiveRange(window - line - 1, window + line));
    await tapAt(tester, 0.05);
    expect(offset(), closeTo(start, 1), reason: 'back to the book start');

    // Page 0 at the top, page 1 below it: a long press reads from there.
    await tester.drag(strip, const Offset(0, -300));
    await tester.pumpAndSettle();
    final chapter = reader(tester).layout;
    expect(chapter.pages.indexOf(reader(tester).page), 0);
    final word = chapter.pages[1].firstWord;
    final box = chapter.wordBoxes(1, word).first;
    final tile = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == chapter.pageText(1),
      ),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.size == chapter.pageSize,
      ),
    );
    await tester.longPressAt(tester.getTopLeft(tile) + box.center);
    await settle(tester);
    await tester.pumpAndSettle();
    expect(rsvp(tester).widget.startWord, word);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await settle(tester);

    await tester.fling(strip, const Offset(0, -200), 3000);
    await tester.pump(const Duration(milliseconds: 50));
    final moving = offset();
    await tester.pump(const Duration(milliseconds: 50));
    expect(offset(), greaterThan(moving), reason: 'still moving');
    final held = offset();
    await tapAt(tester, 0.95);
    await tester.pumpAndSettle();
    expect(offset(), closeTo(held, 1), reason: 'the tap only stopped it');
    await closeApp(tester);
  });

  testWidgets('14.14: in the strip A+ A+ A− A− and the mode keep the top '
      'row; speed reading comes back to its word; the end marks the book '
      'read', (tester) async {
    await pumpApp(tester);
    await openBook(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    );
    final notifier = container.read(readingSettingsProvider.notifier);
    Future<void> change(ReadingSettings Function(ReadingSettings) edit) async {
      notifier.set(edit(container.read(readingSettingsProvider)));
      await tester.pumpAndSettle();
    }

    await change((s) => s.copyWith(verticalScroll: true));
    final strip = find.byType(CustomScrollView);
    for (var i = 0; i < 5; i++) {
      await tester.drag(strip, const Offset(0, -470));
      await tester.pumpAndSettle();
    }
    final word = reader(tester).placeWord;
    expect(word, greaterThan(reader(tester).page.firstWord), reason: 'mid-page');
    const scale = TextScaler.noScaling;
    await change((s) => s.larger(scale));
    expect(reader(tester).placeWord, word);
    await change((s) => s.larger(scale));
    await change((s) => s.smaller(scale));
    await change((s) => s.smaller(scale));
    expect(reader(tester).placeWord, word, reason: 'the same top row');
    await change((s) => s.copyWith(verticalScroll: false));
    await change((s) => s.copyWith(verticalScroll: true));
    expect(reader(tester).placeWord, word, reason: 'the mode keeps it');

    // Speed reading from the top row comes back with its row at the top.
    await tester.tap(find.byType(CustomScrollView), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Скорочтение'));
    await settle(tester);
    await tester.pumpAndSettle();
    final read = rsvp(tester).widget.startWord;
    await tapRsvp(tester);
    await tester.pump(const Duration(seconds: 3));
    await tapRsvp(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await settle(tester);
    final back = reader(tester).placeWord;
    expect(back, greaterThan(read));
    expect(reader(tester).litWord, back);

    expect(await finishedAt(tester), isNull);
    for (var i = 0; i < 30 && await finishedAt(tester) == null; i++) {
      await tester.fling(strip, const Offset(0, -500), 5000);
      await tester.pumpAndSettle();
      await settle(tester);
    }
    expect(await finishedAt(tester), isNotNull, reason: 'scrolled to the end');
    await closeApp(tester);
  });

  testWidgets('14.14: the highlight in the strip: no finger scroll while it '
      'plays, a whole screen on when its row leaves, the top row after a '
      'scroll on a pause', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(
      () => SettingsRepository(db).set(SettingKeys.speedMode, 'guide'),
    );
    await openBook(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    );
    container
        .read(readingSettingsProvider.notifier)
        .set(
          container.read(readingSettingsProvider).copyWith(verticalScroll: true),
        );
    await tester.pumpAndSettle();
    final strip = find.byType(CustomScrollView);
    double offset() =>
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    final window = tester.getSize(strip).height - readerTopMargin;
    final line = reader(tester).layout.style.bodyLine;

    await tapAt(tester, 0.5);
    await tester.tap(find.text('Скорочтение'));
    await settle(tester);
    await tester.pumpAndSettle();
    final guide = reader(tester).guide!;
    expect(guide.word, reader(tester).placeWord);
    await tapAt(tester, 0.5);
    expect(guide.isPlaying, isTrue);

    final start = offset();
    await tester.drag(strip, const Offset(0, -200));
    await tester.pump();
    expect(offset(), start, reason: 'the finger does not scroll');
    for (var i = 0; i < 1200 && offset() == start; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(offset() - start, inInclusiveRange(window - 2 * line, window + line));
    final top = reader(tester).placeWord;
    expect(guide.word, inInclusiveRange(top, top + 15), reason: 'its row on top');

    await tapAt(tester, 0.5);
    expect(guide.isPlaying, isFalse);
    for (var i = 0; i < 2; i++) {
      await tester.drag(strip, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(guide.word, reader(tester).placeWord, reason: 'came to the top');
    await closeApp(tester);
  });
}
