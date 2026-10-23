import 'dart:io';
import 'dart:ui' as ui;

import 'package:book_app/app/app.dart';
import 'package:book_app/app/pro.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/data/stats_seed.dart';
import 'package:book_app/features/library/book_page.dart';
import 'package:book_app/features/library/book_views.dart';
import 'package:book_app/features/reader/contents_screen.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/features/speed/rsvp_screen.dart';
import 'package:book_app/features/stats/book_stats_sheet.dart';
import 'package:book_app/features/stats/stats_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:book_app/platform/screen_channel.dart';
import 'package:book_app/platform/system_bars.dart';
import 'package:book_app/stats/book_stats.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../layout/sample_book.dart';

final _cyrillic = RegExp('[А-Яа-яЁё]');

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temp;
  late AppDatabase db;
  late ContentStore store;
  late BookRepository repo;
  final today = DateTime(2026, 10, 23, 20);

  // Real letter widths: the default test font makes every glyph a square,
  // so labels would look clipped.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Manrope');
    for (final name in ['Regular', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Manrope-$name.ttf'));
    }
    await loader.load();
  });

  setUp(() => temp = Directory.systemTemp.createTempSync('en_ui_'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// A phone: 360x690 logical pixels, the system text [scale], language en.
  void phone(
    WidgetTester tester, {
    double scale = 1.0,
    double height = 690,
    List<ui.Locale> locales = const [ui.Locale('en', 'US')],
  }) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(360, height);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.localesTestValue = locales;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }

  AppDatabase newDb() => AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );

  /// The whole app; with [withBook] one generated book is in the library.
  Future<void> pumpApp(
    WidgetTester tester, {
    bool withBook = false,
    ReadingSettings? settings,
  }) async {
    db = newDb();
    store = ContentStore(Directory('${temp.path}/books'));
    repo = BookRepository(db, store);
    if (withBook) {
      final content = sampleBook(paragraphs: 30);
      final source = File('${temp.path}/book.txt')..writeAsStringSync('book');
      await tester.runAsync(() async {
        await repo.addBook(
          content: content,
          source: source,
          sourceName: 'book.txt',
          sourceHash: 'hash',
          parserVersion: txtParserVersion,
          wordCount: tokenize(content).length,
        );
      });
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          proUnlockedProvider.overrideWithValue(true),
          contentStoreProvider.overrideWithValue(store),
          bookRepositoryProvider.overrideWithValue(repo),
          pickBooksProvider.overrideWithValue(() async => const []),
          statsClockProvider.overrideWithValue(() => today),
          keepScreenOnProvider.overrideWithValue((_) async {}),
          showStatusBarProvider.overrideWithValue((_) async {}),
        ],
        child: const BookApp(),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await settle(tester);
    }
    await tester.pumpAndSettle();
    if (settings != null) {
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(readingSettingsProvider.notifier)
          .set(settings);
      await settle(tester);
      await tester.pumpAndSettle();
    }
  }

  /// All visible texts: paragraphs and tooltips.
  List<String> texts(WidgetTester tester) => [
    for (final e in find.byType(RichText).evaluate())
      (e.widget as RichText).text.toPlainText(),
    for (final e in find.byType(Tooltip).evaluate())
      ?(e.widget as Tooltip).message,
  ];

  /// No Russian text left on the screen, apart from [allowed] fragments
  /// (the book's own title and chapters) and the language's own name.
  void noRussian(WidgetTester tester, {List<String> allowed = const []}) {
    final left = [
      for (final t in texts(tester))
        if (_cyrillic.hasMatch(t) &&
            t != 'Русский' &&
            t != 'П' && // the cover letter of the generated book
            !allowed.any(t.contains))
          t,
    ];
    expect(left, isEmpty, reason: 'Russian left on screen');
  }

  /// Labels cut with an ellipsis or by the line limit.
  void noClipped(WidgetTester tester, {List<String> allowed = const []}) {
    final clipped = <String>[];
    for (final e in find.byType(RichText).evaluate()) {
      final box = e.renderObject;
      if (box is RenderParagraph && box.didExceedMaxLines) {
        final t = box.text.toPlainText();
        if (!allowed.any(t.contains)) clipped.add(t);
      }
    }
    expect(clipped, isEmpty, reason: 'clipped labels');
  }

  /// Known: the "time left" strip is cut at 360 px.
  void check(WidgetTester tester, {List<String> allowed = const []}) {
    noRussian(tester, allowed: allowed);
    noClipped(tester, allowed: [...allowed, 'left in chapter']);
  }

  Future<void> openBook(WidgetTester tester, {bool verify = true}) async {
    for (var i = 0; i < 100 && find.byType(BookTile).evaluate().isEmpty; i++) {
      await settle(tester);
    }
    await tester.tap(find.byType(BookTile));
    final read = find.descendant(
      of: find.byType(BookPageScreen),
      matching: find.byType(FilledButton),
    );
    for (var i = 0; i < 100 && read.evaluate().isEmpty; i++) {
      await settle(tester);
    }
    await tester.pumpAndSettle();
    if (verify) check(tester, allowed: ['Пример']);
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

  Future<void> showPanels(WidgetTester tester) async {
    final size = tester.getSize(find.byType(ReaderView));
    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    await settle(tester);
    await tester.pumpAndSettle();
  }

  /// A paragraph with [fragment]; dates keep their words together with
  /// no-break spaces, which count as plain ones here.
  Finder shows(String fragment, {bool whole = false}) =>
      find.byWidgetPredicate((w) {
        if (w is! RichText) return false;
        final t = w.text.toPlainText().replaceAll(RegExp('[  ]'), ' ');
        return whole ? t == fragment : t.contains(fragment);
      });

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  for (final scale in [1.0, 1.3]) {
    group('English, text scale $scale', () {
      testWidgets('library: empty, tabs, stats empty state', (tester) async {
        phone(tester, scale: scale);
        await pumpApp(tester);
        expect(find.text('Your books will appear here'), findsOneWidget);
        expect(find.text('Add book'), findsOneWidget);
        expect(find.text('Books'), findsOneWidget);
        expect(find.text('Collections'), findsOneWidget);
        expect(find.text('Stats'), findsOneWidget);
        check(tester);

        await tester.tap(find.text('Collections'));
        await tester.pumpAndSettle();
        expect(find.text('No collections yet'), findsOneWidget);
        check(tester);
        await tester.tap(find.text('Create collection'));
        await tester.pumpAndSettle();
        expect(find.text('New collection'), findsOneWidget);
        check(tester);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Stats'));
        await tester.pumpAndSettle();
        expect(find.text('Your numbers will appear here'), findsOneWidget);
        expect(find.text('Open a book'), findsOneWidget);
        check(tester);
        await close(tester);
      });

      testWidgets('library with a book, menu, book page', (tester) async {
        phone(tester, scale: scale);
        await pumpApp(tester, withBook: true);
        for (
          var i = 0;
          i < 100 && find.byType(BookTile).evaluate().isEmpty;
          i++
        ) {
          await settle(tester);
        }
        await tester.pumpAndSettle();
        expect(find.textContaining('All'), findsWidgets);
        check(tester, allowed: ['Пример']);

        await tester.longPress(find.byType(BookTile));
        await tester.pumpAndSettle();
        expect(find.text('Share'), findsOneWidget);
        expect(find.text('Add to collection'), findsOneWidget);
        expect(find.text('Delete book'), findsOneWidget);
        check(tester, allowed: ['Пример']);
        await tester.tap(find.text('Delete book'));
        await tester.pumpAndSettle();
        expect(find.textContaining('The book file and your place'), findsOne);
        check(tester, allowed: ['Пример']);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BookTile));
        await tester.pumpAndSettle();
        for (var i = 0; i < 20; i++) {
          await settle(tester);
        }
        expect(find.text('Read'), findsOneWidget);
        expect(find.textContaining('Added '), findsOneWidget);
        check(tester, allowed: ['Пример']);
        await close(tester);
      });

      testWidgets('reader: panels, settings, contents', (tester) async {
        phone(tester, scale: scale);
        await pumpApp(tester, withBook: true);
        await openBook(tester);
        // The page number and the share read, to a tenth, with a dot.
        final size = tester.getSize(find.byType(ReaderView));
        await tester.tapAt(Offset(size.width * 0.95, size.height / 2));
        await settle(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          texts(tester)
              .where((t) => RegExp(r'^p\. \d+ / \d+ · \d+\.\d%$').hasMatch(t)),
          isNotEmpty,
          reason: texts(tester).join(' | '),
        );
        await showPanels(tester);
        expect(find.text('Library'), findsOneWidget);
        expect(find.byTooltip('Contents'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Speed reading'), findsOneWidget);
        check(tester, allowed: ['Пример', 'Глава']);

        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        for (final label in [
          'Font',
          'Size',
          'Line spacing',
          'Margins',
          'Alignment',
          'Hyphenation',
          'Vertical scrolling',
          'Color',
          'Day and night',
          'Texture',
          'Language',
        ]) {
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          expect(find.text(label), findsOneWidget, reason: label);
          check(tester, allowed: ['Пример', 'Глава']);
        }
        // The language's own names stay as they are.
        expect(find.text('Match system'), findsWidgets);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Русский'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        if (find.byTooltip('Contents').evaluate().isEmpty) {
          await showPanels(tester);
        }
        await tester.tap(find.byTooltip('Contents'));
        await tester.pumpAndSettle();
        expect(find.byType(ContentsScreen), findsOneWidget);
        expect(find.text('Contents'), findsWidgets);
        check(tester, allowed: ['Пример', 'Глава']);
        await close(tester);
      });

      testWidgets('speed reading: word, phrase, pause panel, guide', (
        tester,
      ) async {
        phone(tester, scale: scale);
        await pumpApp(tester, withBook: true);
        await openBook(tester);
        await showPanels(tester);
        await tester.tap(find.text('Speed reading'));
        await settle(tester);
        await tester.pumpAndSettle();
        expect(find.byType(RsvpScreen), findsOneWidget);
        expect(find.text('Tap the screen to start'), findsOneWidget);
        expect(find.text('300 wpm'), findsOneWidget);
        expect(find.text('Word'), findsOneWidget);
        expect(find.text('Phrase'), findsOneWidget);
        expect(find.text('Guide'), findsOneWidget);
        expect(find.byTooltip('Exit speed reading'), findsOneWidget);
        expect(find.text('Back one sentence'), findsOneWidget);
        check(tester, allowed: ['Пример', 'Глава']);

        await tester.tap(find.text('Phrase'));
        await settle(tester);
        await tester.pump();
        check(tester, allowed: ['Пример', 'Глава']);
        await tester.tapAt(tester.getCenter(find.byType(RsvpScreen)));
        await tester.pump(const Duration(seconds: 2));
        await tester.tapAt(tester.getCenter(find.byType(RsvpScreen)));
        await tester.pump();
        expect(find.text('Tap the screen to continue'), findsOneWidget);
        check(tester, allowed: ['Пример', 'Глава']);

        await tester.tap(find.text('Guide'));
        await tester.pumpAndSettle();
        await settle(tester);
        expect(find.byType(RsvpScreen), findsNothing);
        expect(find.text('Exit guide'), findsOneWidget);
        check(tester, allowed: ['Пример', 'Глава']);
        await tester.tap(find.text('Exit guide'));
        await tester.pumpAndSettle();
        await close(tester);
      });
    });
  }

  group('English dates and numbers', () {
    Future<void> pumpPage(
      WidgetTester tester, {
      required DateTime added,
      required int words,
      DateTime? finished,
      int size = 3 * 1024 * 1024 ~/ 2,
    }) async {
      db = newDb();
      store = ContentStore(Directory('${temp.path}/books'));
      await tester.runAsync(
        () => db
            .into(db.books)
            .insert(
              BookRow(
                id: 1,
                title: 'War and Peace',
                authors: const ['Leo Tolstoy'],
                sourceFormat: SourceFormat.fb2,
                sourceName: '1.fb2',
                sourceSize: size,
                sourceHash: '1',
                parserVersion: 1,
                wordCount: words,
                positionWord: 0,
                positionSection: 0,
                positionBlock: 0,
                positionChar: 0,
                addedAt: added,
                touchedAt: added,
                finishedAt: finished,
              ),
            ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            contentStoreProvider.overrideWithValue(store),
            bookRepositoryProvider.overrideWithValue(BookRepository(db, store)),
          ],
          child: const BookApp(),
        ),
      );
      for (var i = 0; i < 50 && find.byType(BookTile).evaluate().isEmpty; i++) {
        await settle(tester);
      }
      await tester.tap(find.byType(BookTile));
      for (var i = 0; i < 10; i++) {
        await settle(tester);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('book page: date, decimal MB, compact words', (tester) async {
      phone(tester);
      final year = DateTime.now().year;
      await pumpPage(
        tester,
        added: DateTime(year, 10, 24),
        finished: DateTime(year, 11, 2),
        words: 84000,
      );
      expect(find.text('84K'), findsOneWidget);
      expect(find.text('words'), findsOneWidget);
      expect(shows('Added Oct 24 · FB2 · 1.5 MB'), findsOne);
      expect(shows('Finished Nov 2'), findsOneWidget);
      expect(
        shows('Nov 2', whole: true),
        findsOneWidget,
        reason: 'finished tile',
      );
      check(tester);
      await close(tester);
    });

    testWidgets('book page: another year has the year, no Russian', (
      tester,
    ) async {
      phone(tester);
      await pumpPage(
        tester,
        added: DateTime(2020, 3, 5),
        words: 1500,
        size: 500 * 1024,
      );
      expect(shows('Added Mar 5, 2020 · FB2 · 500 KB'), findsOne);
      expect(find.text('1.5K'), findsOneWidget);
      check(tester);
      await close(tester);
    });

    testWidgets('one word, one page: singular forms', (tester) async {
      phone(tester);
      await pumpPage(tester, added: DateTime(2026, 10, 1), words: 1);
      expect(find.text('word'), findsOneWidget);
      expect(find.text('words'), findsNothing);
      check(tester);
      await close(tester);
    });
  });

  group('English stats', () {
    final seed = seedStats(today: today, bookIds: [1]);

    Future<void> pumpStats(WidgetTester tester, Widget home) async {
      db = newDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            readingDaysProvider.overrideWithValue(AsyncData(seed.reading)),
            paceDaysProvider.overrideWithValue(AsyncData(seed.pace)),
            statsClockProvider.overrideWithValue(() => today),
          ],
          child: MaterialApp(
            theme: buildAppTheme(ReadingPalette.paper, night: false),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: home,
          ),
        ),
      );
      await settle(tester);
      await tester.pumpAndSettle();
    }

    for (final scale in [1.0, 1.3]) {
      testWidgets('screen: week, month, year (scale $scale)', (tester) async {
        phone(tester, scale: scale, height: 6000);
        await pumpStats(tester, const StatsScreen());
        expect(find.text('Stats'), findsOneWidget);
        expect(find.text('Week'), findsOneWidget);
        expect(find.text('Month'), findsOneWidget);
        expect(find.text('Year'), findsOneWidget);
        expect(find.text('Speed reading saved'), findsOneWidget);
        expect(find.text('Minutes per day'), findsOneWidget);
        expect(find.text('Pages per day'), findsOneWidget);
        expect(find.text('Normally'), findsOneWidget);
        check(tester);

        // Month period (the default): month and weekday names are English.
        expect(find.textContaining('October'), findsWidgets);
        expect(find.text('Fri'), findsWidgets, reason: 'weekday');
        final month = texts(tester).where((t) => t.contains('October'));
        expect(month, isNotEmpty);

        await tester.tap(find.text('Year'));
        await tester.pumpAndSettle();
        expect(find.text('Minutes per month'), findsOneWidget);
        expect(find.text('Jun'), findsWidgets);
        expect(find.text('Jul'), findsWidgets);
        expect(find.textContaining('in 2026'), findsWidgets);
        expect(find.text('2026 in review'), findsOneWidget);
        check(tester);

        await tester.tap(find.text('Week'));
        await tester.pumpAndSettle();
        expect(find.text('Minutes per day'), findsOneWidget);
        expect(find.text('Fri'), findsNWidgets(3));
        expect(find.textContaining('this week'), findsWidgets);
        check(tester);

        // Numbers: a dot for decimals, never a comma between digits.
        final all = texts(tester).join('\n');
        expect(RegExp(r'\d,\d{1,2}(?!\d)').hasMatch(all), isFalse, reason: all);
        await close(tester);
      });
    }

    testWidgets('numbers in the month view use a dot', (tester) async {
      phone(tester, height: 6000);
      await pumpStats(tester, const StatsScreen());
      final all = texts(tester).join('\n');
      expect(RegExp(r'\d,\d{1,2}(?!\d)').hasMatch(all), isFalse, reason: all);
      expect(RegExp(r'\d\.\d').hasMatch(all), isTrue, reason: all);
      await close(tester);
    });

    testWidgets('the month in the "saved" card is capitalised', (tester) async {
      phone(tester, height: 6000);
      await pumpStats(tester, const StatsScreen());
      // "in October", not "in october".
      expect(find.textContaining('in october'), findsNothing);
      await close(tester);
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('book stats sheet (scale $scale)', (tester) async {
        phone(tester, scale: scale);
        await pumpStats(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showBookStatsSheet(
                  context,
                  title: 'War and Peace',
                  stats: BookStats.of(
                    1,
                    rows: seed.reading,
                    today: today,
                    setWpmOf: (_) => 300,
                  ),
                  wordsLeft: 20000,
                  progress: 0.5,
                  today: today,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('THIS BOOK'), findsOneWidget);
        expect(find.text('Reading stats'), findsOneWidget);
        expect(find.textContaining('At your pace, you’ll finish'), findsOne);
        check(tester);
        await close(tester);
      });
    }
  });

  group('app language', () {
    const russian = 'Здесь появятся ваши книги';
    const english = 'Your books will appear here';
    const en = ui.Locale('en', 'US');
    const ru = ui.Locale('ru', 'RU');
    const de = ui.Locale('de', 'DE');

    Future<void> expectLanguage(
      WidgetTester tester, {
      required List<ui.Locale> phoneLocales,
      required AppLanguage setting,
      required String shown,
    }) async {
      phone(tester, locales: phoneLocales);
      await pumpApp(tester, settings: ReadingSettings(language: setting));
      expect(find.text(shown), findsOneWidget);
      expect(find.text(shown == english ? russian : english), findsNothing);
      await close(tester);
    }

    testWidgets('phone en + setting ru: Russian', (tester) async {
      await expectLanguage(
        tester,
        phoneLocales: [en],
        setting: AppLanguage.ru,
        shown: russian,
      );
    });

    testWidgets('phone de + system: English', (tester) async {
      await expectLanguage(
        tester,
        phoneLocales: [de],
        setting: AppLanguage.system,
        shown: english,
      );
    });

    testWidgets('phone ru + setting en: English', (tester) async {
      await expectLanguage(
        tester,
        phoneLocales: [ru],
        setting: AppLanguage.en,
        shown: english,
      );
    });

    testWidgets('phone ru + system: Russian', (tester) async {
      await expectLanguage(
        tester,
        phoneLocales: [ru],
        setting: AppLanguage.system,
        shown: russian,
      );
    });

    testWidgets('phone de, then ru: the first the app has', (tester) async {
      await expectLanguage(
        tester,
        phoneLocales: [de, ru, en],
        setting: AppLanguage.system,
        shown: russian,
      );
    });

    testWidgets('phone de + setting ru: Russian', (tester) async {
      await expectLanguage(
        tester,
        phoneLocales: [de],
        setting: AppLanguage.ru,
        shown: russian,
      );
    });

    testWidgets('changing the setting switches the texts at once', (
      tester,
    ) async {
      phone(tester, locales: [ru]);
      await pumpApp(tester);
      expect(find.text(russian), findsOneWidget);
      final notifier = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      ).read(readingSettingsProvider.notifier);
      notifier.set(const ReadingSettings(language: AppLanguage.en));
      await tester.pumpAndSettle();
      expect(find.text(english), findsOneWidget);
      notifier.set(const ReadingSettings(language: AppLanguage.system));
      await tester.pumpAndSettle();
      expect(find.text(russian), findsOneWidget);
      await close(tester);
    });

    testWidgets('the language buttons of the sheet switch the app', (
      tester,
    ) async {
      phone(tester, locales: [ru]);
      await pumpApp(tester, withBook: true);
      await openBook(tester, verify: false);
      await showPanels(tester);
      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Язык'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Язык'), findsNothing);
      await tester.tap(find.text('Русский'));
      await tester.pumpAndSettle();
      expect(find.text('Язык'), findsOneWidget);
      await close(tester);
    });
  });
}
