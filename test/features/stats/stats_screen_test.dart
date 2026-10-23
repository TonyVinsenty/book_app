import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/data/speed_settings.dart';
import 'package:book_app/data/stats_seed.dart';
import 'package:book_app/features/stats/book_stats_sheet.dart';
import 'package:book_app/features/stats/charts/reading_calendar.dart';
import 'package:book_app/features/stats/charts/speed_line_chart.dart';
import 'package:book_app/features/stats/charts/stacked_bars.dart';
import 'package:book_app/features/stats/stats_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/stats/book_stats.dart';
import 'package:book_app/stats/stats_calc.dart';
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

  testWidgets('a little reading: speeds and the pace are being found out', (
    tester,
  ) async {
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
    expect(
      find.text('Линия появится, когда наберётся больше чтения.'),
      findsOneWidget,
    );
    expect(
      find.text('Почитайте на разных скоростях — подскажем комфортный темп.'),
      findsOneWidget,
    );
    // 300 words at 200 a minute by eye: 1 min 30 s against 1 min.
    expect(find.text('< 1 мин'), findsOneWidget);
    expect(find.textContaining('среднюю для взрослого'), findsOneWidget);
  });

  testWidgets('made-up months: saved time, speeds, line, the pace button', (
    tester,
  ) async {
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
    expect(find.text('Обычно'), findsOneWidget);
    expect(find.byType(SpeedLineChart), findsOneWidget);
    expect(find.text('8 недель назад'), findsOneWidget);
    expect(find.text('скорость уточняется'), findsNothing);
    expect(find.text('Минуты по дням'), findsOneWidget);
    expect(find.text('Страницы по дням'), findsOneWidget);
    expect(find.byType(StackedBars), findsNWidgets(2));
    expect(find.textContaining('Октябрь · '), findsOneWidget);
    expect(find.byType(ReadingCalendar), findsOneWidget);
    expect(find.text('Итоги · 2026 год'), findsOneWidget);
    expect(find.text('за чтением'), findsOneWidget);

    final comfortable = comfortablePace(seed.pace)!;
    final button = find.text('Поставить ${comfortable.wpm} сл/мин');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await settle(tester);
    await settle(tester);
    expect(button, findsNothing);
    expect(
      await tester.runAsync(
        () =>
            SpeedSettings(SettingsRepository(db))
                .wordsPerMinute(comfortable.mode),
      ),
      comfortable.wpm,
    );

    await tester.tap(find.text('Год'));
    await tester.pump();
    expect(find.textContaining('за 2026 год'), findsOneWidget);
    expect(find.text('12 месяцев назад'), findsOneWidget);
    expect(find.text('Минуты по месяцам'), findsOneWidget);
    expect(find.text('Страницы по месяцам'), findsOneWidget);
    // Months by three letters under the bars (14.2, A6).
    expect(find.text('Июн'), findsWidgets);
    expect(find.text('Июл'), findsWidgets);

    await tester.tap(find.text('Неделя'));
    await tester.pump();
    expect(find.text('Минуты по дням'), findsOneWidget);
    expect(find.text('Пт'), findsNWidgets(3));
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
