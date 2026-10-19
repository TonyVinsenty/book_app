import 'dart:async';
import 'dart:io';

import 'package:book_app/app/app.dart';
import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/features/speed/rsvp_screen.dart';
import 'package:book_app/platform/screen_channel.dart';
import 'package:book_app/speed/pause_text.dart';
import 'package:book_app/speed/rewind.dart';
import 'package:book_app/speed/timing.dart';
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
  late AppDatabase db;

  /// Calls to keep the screen on (true) or let it dim (false).
  late List<bool> keepScreenOn;

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
    db = AppDatabase(
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
      if (reopen) await repo.markOpened(bookId);
    });
    if (lostFiles) Directory('${temp.path}/books').deleteSync(recursive: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bookRepositoryProvider.overrideWithValue(repo),
          keepScreenOnProvider.overrideWithValue((on) async {
            keepScreenOn.add(on);
          }),
        ],
        child: BookApp(reopenBookId: reopen ? bookId : null),
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
    expect(keepScreenOn, [true, false]);
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
    expect(find.byType(ListTile), findsOneWidget);
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
    expect(find.byType(ListTile), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('a lost book opened by hand shows the way back', (tester) async {
    await pumpApp(tester, lostFiles: true);
    await tester.tap(find.byType(ListTile));
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

    await change((s) => s.copyWith(font: BookFont.lora));
    await change((s) => s.copyWith(lineHeight: 1.8));
    await change((s) => s.copyWith(margins: PageMargins.wide));
    await change((s) => s.copyWith(align: BookAlign.justify));
    await change((s) => s.copyWith(palette: ReadingPalette.sage));
    await change((s) => s.copyWith(night: NightMode.night));
    await change((_) => const ReadingSettings());
    expect(reader(tester).page.firstWord, start.firstWord);
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
      await tester.runAsync(
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

    // The word is painted in the middle of its painter's area.
    final wordY = tester
        .getCenter(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is RsvpWordPainter,
          ),
        )
        .dy;
    await tester.tap(find.byTooltip('Выйти из скорочтения'));
    await tester.pumpAndSettle();
    expect(find.byType(RsvpScreen), findsNothing);
    final page = reader(tester).page;
    expect(page.firstWord, lessThanOrEqualTo(stopped));
    expect(page.endWord, greaterThan(stopped));
    await settle(tester);
    expect(reader(tester).litWord, stopped);
    expect(await tester.runAsync(savedWord), stopped);

    // The word's line is where speed reading showed the word; the page
    // number is approximate and pages go on from the shifted one.
    final layout = reader(tester).layout;
    expect(layout.isShifted, isTrue);
    final box = layout.wordBoxes(layout.pageOfWord(stopped), stopped).first;
    final pageTop = tester
        .getTopLeft(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.size == layout.pageSize,
          ),
        )
        .dy;
    expect(
      (pageTop + box.center.dy - wordY).abs(),
      lessThanOrEqualTo(layout.style.bodyLine),
    );
    expect(find.textContaining('≈ '), findsOneWidget);
    // Forward and back from the shifted page: no words lost or repeated.
    final firstWords = [page.firstWord];
    for (var i = 0; i < 3; i++) {
      final before = reader(tester).page;
      await tapAt(tester, 0.95);
      expect(reader(tester).page.firstWord, before.endWord);
      firstWords.add(before.endWord);
    }
    // Back to the book start, past the shifted page.
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

  /// Speed reading pushed over the reader from [word], fast, and started.
  Future<void> speedReadFrom(WidgetTester tester, int word) async {
    final opened = reader(tester).widget.opened;
    unawaited(
      Navigator.of(tester.element(find.byType(ReaderView))).push<int>(
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

    await speedReadFrom(tester, tokens.length - 3);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Книга закончилась'), findsOneWidget);
    await tester.tap(find.text('К тексту'));
    await tester.pumpAndSettle();
    expect(find.byType(RsvpScreen), findsNothing);
    await settle(tester);
    expect(await tester.runAsync(savedWord), tokens.length - 1);
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
}
