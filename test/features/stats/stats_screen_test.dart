import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/stats_seed.dart';
import 'package:book_app/features/stats/book_stats_sheet.dart';
import 'package:book_app/features/stats/charts/reading_calendar.dart';
import 'package:book_app/features/stats/charts/stacked_bars.dart';
import 'package:book_app/features/stats/stats_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/stats/book_stats.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final today = DateTime(2026, 10, 23, 20);
  final seed = seedStats(today: today, bookIds: [1]);
  late AppDatabase db;

  setUp(() {
    // Left open: closing under fake time hangs.
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    List<ReadingDelta> reading = const [],
    List<PaceDelta> pace = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          readingDaysProvider.overrideWithValue(AsyncData(reading)),
          paceDaysProvider.overrideWithValue(AsyncData(pace)),
          statsClockProvider.overrideWithValue(() => today),
        ],
        child: MaterialApp(
          theme: buildAppTheme(ReadingPalette.paper, night: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('nothing read: the empty state leads to the books', (
    tester,
  ) async {
    var opened = 0;
    await pump(tester, Scaffold(body: StatsView(onOpenBooks: () => opened++)));
    expect(find.text('Здесь появятся ваши цифры'), findsOneWidget);
    expect(find.text('Месяц'), findsNothing);
    await tester.tap(find.text('Открыть книгу'));
    expect(opened, 1);
  });

  testWidgets('a little reading: the year speeds are being found out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 9000);
    addTearDown(tester.view.reset);
    await pump(
      tester,
      const StatsScreen(),
      reading: [
        ReadingDelta(
          day: 20261020,
          bookId: 1,
          mode: ReadingMode.word,
          dayPart: 0,
          activeMs: 60000,
          words: 300,
        ),
      ],
    );
    expect(find.text('Статистика'), findsOneWidget);
    expect(find.text('скорость уточняется'), findsNWidgets(2));
    // 300 words at 200 a minute by eye: 1 min 30 s against 1 min.
    expect(find.text('< 1 мин'), findsOneWidget);
    expect(find.textContaining('среднюю для взрослого'), findsOneWidget);
  });

  testWidgets('the first cards come up one after another', (tester) async {
    tester.view.physicalSize = const Size(1080, 9000);
    addTearDown(tester.view.reset);
    await pump(
      tester,
      const StatsScreen(),
      reading: seed.reading,
      pace: seed.pace,
    );
    List<double> opacities() => [
      for (final o in tester.widgetList<Opacity>(
        find.descendant(
          of: find.byType(StatsView),
          matching: find.byType(Opacity),
        ),
      ))
        o.opacity,
    ];
    await tester.pump(const Duration(milliseconds: 150));
    final early = opacities();
    expect(early, hasLength(3));
    expect(early.first, greaterThan(early[2]), reason: 'the top one is ahead');
    expect(early[2], lessThan(1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacities(), everyElement(1.0));
  });

  testWidgets('made-up months: saved time, the calendar, the year; the bars '
      'of the week and the year', (tester) async {
    tester.view.physicalSize = const Size(1080, 9000);
    addTearDown(tester.view.reset);
    await pump(
      tester,
      const StatsScreen(),
      reading: seed.reading,
      pace: seed.pace,
    );
    expect(find.text('Скорочтение сэкономило'), findsOneWidget);
    expect(find.textContaining('за октябрь'), findsOneWidget);
    expect(find.textContaining('Без скорочтения эти страницы'), findsOneWidget);
    expect(find.textContaining('в скорочтении'), findsNothing);
    expect(find.byType(StackedBars), findsNothing, reason: 'the calendar');
    expect(find.textContaining('Октябрь · '), findsOneWidget);
    expect(find.byType(ReadingCalendar), findsOneWidget);
    expect(find.text('Итоги · 2026 год'), findsOneWidget);
    expect(find.text('Книг прочитано'), findsOneWidget);
    expect(find.text('Время чтения'), findsOneWidget);
    expect(find.text('Страниц прочитано'), findsOneWidget);
    expect(find.text('Средняя скорость'), findsNWidgets(2));
    expect(find.textContaining(' сл/мин'), findsNWidgets(2));

    // A day of the calendar tells its time and pages.
    await tester.tap(
      find.descendant(
        of: find.byType(ReadingCalendar),
        matching: find.text('23'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('23 октября · '), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Год'));
    await tester.pumpAndSettle();
    expect(find.textContaining('за 2026 год'), findsOneWidget);
    expect(find.text('Чтение по месяцам'), findsOneWidget);
    expect(find.byType(ReadingCalendar), findsNothing);
    // Months by three letters under the bars (14.2, A6).
    expect(find.text('Июн'), findsOneWidget);
    expect(find.text('Часы'), findsOneWidget);
    await tester.tap(find.text('Страницы'));
    await tester.pumpAndSettle();
    expect(
      find.text('Страница — 250 слов, как в бумажной книге.'),
      findsNWidgets(2),
    );

    await tester.tap(find.text('Неделя'));
    await tester.pumpAndSettle();
    expect(find.text('Чтение по дням'), findsOneWidget);
    expect(find.text('Минуты'), findsOneWidget);
    expect(find.text('Пт'), findsOneWidget);
  });

  testWidgets('the sheet about the book opens the whole statistics', (
    tester,
  ) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showBookStatsSheet(
              context,
              title: 'Книга',
              stats: BookStats.of(
                1,
                rows: const [],
                today: today,
                setWpmOf: (_) => 300,
              ),
              wordsLeft: 1000,
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
    await tester.tap(find.text('Статистика чтения'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Эта книга'.toUpperCase()), findsOneWidget);
  });
}
