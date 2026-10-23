import 'package:book_app/app/pill_tabs.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/stats_seed.dart';
import 'package:book_app/features/library/book_shelf.dart';
import 'package:book_app/features/stats/charts/chart_colors.dart';
import 'package:book_app/features/stats/charts/reading_calendar.dart';
import 'package:book_app/features/stats/charts/speed_line_chart.dart';
import 'package:book_app/features/stats/charts/stacked_bars.dart';
import 'package:book_app/features/stats/stats_format.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/stats_calc.dart';
import 'package:book_app/stats/stats_overview.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The statistics over the reader, from "Вся статистика" in the sheet about
/// the book.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).statsTitle)),
    body: const SafeArea(top: false, child: StatsView()),
  );
}

/// The library tab "Статистика" and the body of [StatsScreen]: the period
/// switch, then the blocks of ADR 0009 п. 6, mockup `docs/design/stats.html`.
class StatsView extends ConsumerStatefulWidget {
  const StatsView({super.key, this.onOpenBooks});

  /// The button of the empty state; none — no button.
  final VoidCallback? onOpenBooks;

  @override
  ConsumerState<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends ConsumerState<StatsView> {
  var _period = StatsPeriod.month;

  /// The cards went up under the period switch: a line under it.
  var _scrolled = false;

  bool _onScroll(ScrollNotification notification) {
    final scrolled = notification.metrics.extentBefore > 0;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (rows, pace) = (
      ref.watch(readingDaysProvider).value,
      ref.watch(paceDaysProvider).value,
    );
    if (rows == null || pace == null) return const SizedBox.shrink();
    final today = ref.read(statsClockProvider)();
    final overview = StatsOverview.of(
      _period,
      rows: rows,
      pace: pace,
      today: today,
      finishedAt: [
        for (final book in ref.watch(booksProvider).value ?? const <BookRow>[])
          book.finishedAt,
      ],
    );
    final debugMenu = kDebugMode ? const _DebugMenu() : null;
    if (overview.empty) {
      return Column(
        children: [
          if (debugMenu != null)
            Align(alignment: AlignmentDirectional.topEnd, child: debugMenu),
          Expanded(
            child: EmptyMessage(
              icon: Icons.bar_chart_rounded,
              title: l10n.statsEmptyTitle,
              hint: l10n.statsEmptyHint,
              action: switch (widget.onOpenBooks) {
                final open? => FilledButton(
                  onPressed: open,
                  child: Text(l10n.statsEmptyAction),
                ),
                null => null,
              },
            ),
          ),
        ],
      );
    }
    // The period switch stays; only the cards go under it (14.2, A5).
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
          children: [
            Expanded(
              child: PillTabs(
                tabs: {
                  StatsPeriod.week: l10n.statsPeriodWeek,
                  StatsPeriod.month: l10n.statsPeriodMonth,
                  StatsPeriod.year: l10n.statsPeriodYear,
                },
                selected: _period,
                onChanged: (period) => setState(() => _period = period),
                margin: EdgeInsets.zero,
              ),
            ),
            ?debugMenu,
          ],
        ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: _scrolled
              ? context.readingColors.text.withValues(alpha: 0.14)
              : Colors.transparent,
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
        _SavedCard(overview),
        const SizedBox(height: 12),
        _SpeedCard(overview),
        const SizedBox(height: 12),
        _PaceCard(overview.pace),
        const SizedBox(height: 12),
        _DaysCard(overview, pages: false),
        const SizedBox(height: 12),
        _DaysCard(overview, pages: true),
        const SizedBox(height: 12),
        _CalendarCard(overview.calendar, today: today),
        const SizedBox(height: 12),
        _YearCard(overview.year, year: today.year),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Скорочтение сэкономило": the time, the period, the two bars.
class _SavedCard extends StatelessWidget {
  const _SavedCard(this.overview);

  final StatsOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final secondary = _secondary(context);
    final saved = overview.saved;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final period = switch (overview.period) {
      StatsPeriod.week => l10n.statsForWeek,
      StatsPeriod.month => l10n.statsForMonth(
        DateFormat.LLLL(locale).format(overview.from).toLowerCase(),
      ),
      StatsPeriod.year => l10n.statsForYear(overview.from.year),
    };
    final read = saved.actual > Duration.zero;
    return _Card(
      title: l10n.statsSavedTitle,
      children: [
        Text(
          formatDuration(l10n, saved.saved),
          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          [
            period,
            l10n.statsReadingDays(overview.readingDays),
            if (overview.speedWords > 0)
              l10n.statsSpeedWords(overview.speedWords),
          ].join(' · '),
          style: secondary,
        ),
        if (read) ...[
          const SizedBox(height: 8),
          _Compare(usual: saved.usual, actual: saved.actual),
          if (!saved.faster) Text(l10n.statsNotFaster, style: secondary),
          const SizedBox(height: 4),
          Text(l10n.statsSavedHow, style: secondary),
          if (!overview.eyeSpeed.known)
            Text(l10n.statsSavedAverage(fallbackPageWpm), style: secondary),
        ],
      ],
    );
  }
}

/// "Обычно" and "У вас" as bars of one scale.
class _Compare extends StatelessWidget {
  const _Compare({required this.usual, required this.actual});

  final Duration usual;
  final Duration actual;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chart = ChartColors.of(context.readingColors);
    final longest = usual > actual ? usual : actual;
    final (usualText, actualText) = (
      formatDuration(l10n, usual),
      formatDuration(l10n, actual),
    );
    Widget bar(String name, Duration time, String value, Color color) => Row(
      spacing: 8,
      children: [
        SizedBox(width: 64, child: Text(name, style: _secondary(context))),
        Expanded(
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: (time.inMilliseconds / longest.inMilliseconds).clamp(
              0.02,
              1,
            ),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Semantics(
      label: l10n.statsCompareLabel(usualText, actualText),
      child: ExcludeSemantics(
        child: Column(
          spacing: 6,
          children: [
            bar(l10n.statsUsual, usual, usualText, chart.eye),
            bar(l10n.statsYours, actual, actualText, chart.play),
          ],
        ),
      ),
    );
  }
}

/// The two speeds and their line by weeks or months.
class _SpeedCard extends StatelessWidget {
  const _SpeedCard(this.overview);

  final StatsOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chart = ChartColors.of(context.readingColors);
    final secondary = _secondary(context);
    final line = overview.line;
    final byMonths = overview.period == StatsPeriod.year;
    String? series(String name, Iterable<int?> values) {
      final known = values.nonNulls;
      if (known.isEmpty) return null;
      return l10n.statsLineSeries(name, known.first, known.last);
    }

    final described = [
      ?series(l10n.statsEyeReading, line.map((p) => p.eye)),
      ?series(l10n.statsSpeedReading, line.map((p) => p.play)),
    ];
    return _Card(
      title: l10n.statsSpeedTitle,
      children: [
        Row(
          children: [
            Expanded(
              child: _Speed(
                name: l10n.statsEyeReading,
                color: chart.eye,
                wpm: overview.eyeSpeed.known ? overview.eyeSpeed.wpm : null,
              ),
            ),
            Expanded(
              child: _Speed(
                name: l10n.statsSpeedReading,
                color: chart.play,
                wpm: overview.playSpeed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (described.isEmpty)
          Text(l10n.statsLineEmpty, style: secondary)
        else ...[
          SpeedLineChart(
            points: line,
            colors: chart,
            label: [
              if (byMonths) l10n.statsLineMonths else l10n.statsLineWeeks,
              ...described,
            ].join(' '),
          ),
          ExcludeSemantics(
            child: Row(
              children: [
                Text(
                  byMonths ? l10n.statsLineMonthsAgo : l10n.statsLineWeeksAgo,
                  style: secondary,
                ),
                const Spacer(),
                Text(l10n.statsLineNow, style: secondary),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A speed with its color in the line; null — not known yet.
class _Speed extends StatelessWidget {
  const _Speed({required this.name, required this.color, required this.wpm});

  final String name;
  final Color color;
  final int? wpm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final wpm = this.wpm;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 6,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: 9),
              ),
              Flexible(child: Text(name, style: _secondary(context))),
            ],
          ),
          if (wpm == null)
            Text(l10n.statsSpeedUnknown, style: text.bodyMedium)
          else
            Text(
              '$wpm',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}

/// The set pace of a speed mode, for the button "Поставить".
final _setWpmProvider = FutureProvider.autoDispose.family<int, SpeedMode>(
  (ref, mode) => ref.watch(speedSettingsProvider).wordsPerMinute(mode),
);

/// "Комфортный темп": the pace, the backs and pauses by step, the button.
class _PaceCard extends ConsumerWidget {
  const _PaceCard(this.pace);

  final ComfortablePace? pace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final secondary = _secondary(context);
    final pace = this.pace;
    if (pace == null) {
      return _Card(
        title: l10n.statsPaceTitle,
        children: [Text(l10n.statsPaceUnknown, style: text.bodyMedium)],
      );
    }
    final faster = pace.rates.keys.where((step) => step > pace.wpm);
    final setWpm = ref.watch(_setWpmProvider(pace.mode)).value;
    return _Card(
      title: l10n.statsPaceTitle,
      children: [
        Text(
          [
            l10n.statsPaceText(pace.wpm, _modeName(l10n, pace.mode)),
            if (faster.isNotEmpty) l10n.statsPaceFaster(faster.first),
          ].join(' '),
          style: text.bodyMedium,
        ),
        const SizedBox(height: 10),
        _PaceBars(pace),
        Text(l10n.statsPaceChart, style: secondary),
        if (setWpm != null && setWpm != pace.wpm) ...[
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              await ref
                  .read(speedSettingsProvider)
                  .setWordsPerMinute(pace.mode, pace.wpm);
              ref.invalidate(_setWpmProvider(pace.mode));
            },
            child: Text(l10n.statsPaceSet(pace.wpm)),
          ),
        ],
      ],
    );
  }

  static String _modeName(AppLocalizations l10n, SpeedMode mode) =>
      switch (mode) {
        SpeedMode.word => l10n.speedModeWord,
        SpeedMode.phrase => l10n.speedModePhrase,
        SpeedMode.guide => l10n.speedModeGuide,
      };
}

/// One bar a step: the comfortable one green, the too fast ones violet.
class _PaceBars extends StatelessWidget {
  const _PaceBars(this.pace);

  final ComfortablePace pace;

  static const _height = 64.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chart = ChartColors.of(context.readingColors);
    final small = Theme.of(context).textTheme.labelSmall;
    final format = NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toLanguageTag(),
      decimalDigits: 1,
    );
    final highest = pace.rates.values.fold(0.0, (a, b) => a > b ? a : b);
    return Semantics(
      label: [
        for (final MapEntry(key: wpm, value: rate) in pace.rates.entries)
          l10n.statsPaceStep(wpm, rate),
      ].join('; '),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 8,
          children: [
            for (final MapEntry(key: wpm, value: rate) in pace.rates.entries)
              Expanded(
                child: Column(
                  spacing: 2,
                  children: [
                    Text(format.format(rate), style: small),
                    Container(
                      height: highest == 0
                          ? 3
                          : (rate / highest * _height).clamp(3, _height),
                      decoration: BoxDecoration(
                        color: wpm == pace.wpm
                            ? chart.play
                            : rate > pace.limit
                            ? chart.fast
                            : chart.eye.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    Text(
                      '$wpm',
                      style: small?.copyWith(
                        fontWeight: wpm == pace.wpm ? FontWeight.w800 : null,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Минуты по дням" or "Страницы по дням": a bar a day of the week or the
/// month, a month of the year; stacks by mode.
class _DaysCard extends StatelessWidget {
  const _DaysCard(this.overview, {required this.pages});

  final StatsOverview overview;
  final bool pages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chart = ChartColors.of(context.readingColors);
    final secondary = _secondary(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final period = overview.period;
    final bars = overview.bars;
    final byMonths = period == StatsPeriod.year;
    Map<ReadingMode, int> partsOf(DayBar bar) => pages ? bar.words : bar.ms;
    String spoken(DayBar bar) => pages
        ? l10n.statsPages(pagesOf(bar.totalWords))
        : formatDuration(l10n, Duration(milliseconds: bar.totalMs));
    final spokenName = switch (period) {
      StatsPeriod.week => DateFormat.EEEE(locale),
      StatsPeriod.month => DateFormat.MMMMd(locale),
      StatsPeriod.year => DateFormat.LLLL(locale),
    };
    final title = switch ((pages, byMonths)) {
      (false, false) => l10n.statsMinutesDays,
      (false, true) => l10n.statsMinutesMonths,
      (true, false) => l10n.statsPagesDays,
      (true, true) => l10n.statsPagesMonths,
    };
    final summary = overview.readingDays == 0
        ? l10n.statsNoReading
        : pages
        ? l10n.statsPagesPerDay(overview.pagesPerDay)
        : l10n.statsPerDay(formatDuration(l10n, overview.perDay));
    final modes = {
      for (final bar in bars)
        for (final MapEntry(:key, :value) in partsOf(bar).entries)
          if (value > 0) key,
    };
    return _Card(
      title: title,
      children: [
        const SizedBox(height: 4),
        StackedBars(
          bars: [for (final bar in bars) bar.future ? null : partsOf(bar)],
          names: [
            for (final bar in bars)
              switch (period) {
                StatsPeriod.week => capitalized(
                  DateFormat.E(locale).format(bar.from),
                ),
                StatsPeriod.month =>
                  bar.from.day == 1 || bar.from.day % 5 == 0
                      ? '${bar.from.day}'
                      : null,
                // Three letters: «И И» could not be told apart (14.2, A6).
                StatsPeriod.year =>
                  l10n.statsMonthsShort.split(' ')[bar.from.month - 1],
              },
          ],
          values: period == StatsPeriod.week
              ? [
                  for (final bar in bars)
                    bar.future
                        ? ''
                        : pages
                        ? '${pagesOf(bar.totalWords)}'
                        : '${(bar.totalMs / 60000).round()}',
                ]
              : null,
          current: bars.lastIndexWhere((bar) => !bar.future),
          colors: chart,
          label: [
            title,
            summary,
            [
              for (final bar in bars)
                if (partsOf(bar).values.any((v) => v > 0))
                  l10n.statsBar(spokenName.format(bar.from), spoken(bar)),
            ].join('; '),
          ].join('. '),
        ),
        if (modes.isNotEmpty) ...[
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final mode in ReadingMode.values)
                  if (modes.contains(mode))
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: chart.ofMode(mode),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const SizedBox.square(dimension: 10),
                        ),
                        Text(_modeName(l10n, mode), style: secondary),
                      ],
                    ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 2),
        ExcludeSemantics(child: Text(summary, style: secondary)),
        if (pages) Text(l10n.statsPagesHow, style: secondary),
      ],
    );
  }

  static String _modeName(AppLocalizations l10n, ReadingMode mode) =>
      switch (mode) {
        ReadingMode.page => l10n.statsModePage,
        ReadingMode.word => l10n.speedModeWord,
        ReadingMode.phrase => l10n.speedModePhrase,
        ReadingMode.guide => l10n.speedModeGuide,
      };
}

/// This month's days, shaded by reading time; no streaks.
class _CalendarCard extends StatelessWidget {
  const _CalendarCard(this.days, {required this.today});

  final List<DayBar> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final month = DateFormat.LLLL(locale).format(days.first.from);
    final read = [
      for (final day in days)
        if (!day.future && day.totalMs > 0) day.from.day,
    ];
    return _Card(
      title:
          '${capitalized(month)} · '
          '${l10n.statsReadingDays(read.length)}',
      children: [
        const SizedBox(height: 4),
        ReadingCalendar(
          days: days,
          today: today,
          colors: ChartColors.of(context.readingColors),
          label: read.isEmpty
              ? l10n.statsCalendarNone(month)
              : l10n.statsCalendarLabel(month, read.join(', ')),
        ),
        const SizedBox(height: 4),
        Text(l10n.statsCalendarHint, style: _secondary(context)),
      ],
    );
  }
}

/// "Итоги": finished books, words, time, saved — of this [year].
class _YearCard extends StatelessWidget {
  const _YearCard(this.totals, {required this.year});

  final YearTotals totals;
  final int year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    Widget item(String value, String unit) => Expanded(
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(unit, style: _secondary(context)),
          ],
        ),
      ),
    );
    return _Card(
      title: l10n.statsYearTitle(year),
      children: [
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            item('${totals.books}', l10n.statsYearBooks(totals.books)),
            item(
              NumberFormat.compact(locale: locale).format(totals.words),
              totals.words < 1000
                  ? l10n.statsYearWords(totals.words)
                  : l10n.statsYearWordsCompact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            item(formatDuration(l10n, totals.time), l10n.statsYearTime),
            item(formatDuration(l10n, totals.saved.saved), l10n.statsYearSaved),
          ],
        ),
      ],
    );
  }
}

/// A block of the screen: its name over the content.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.readingColors.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ...children,
        ],
      ),
    ),
  );
}

/// Made-up statistics, in debug builds only (ADR 0009 п. 8).
class _DebugMenu extends ConsumerWidget {
  const _DebugMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = ref.read(statsRepositoryProvider);
    return PopupMenuButton<bool>(
      tooltip: l10n.debugStatsMenu,
      icon: const Icon(Icons.bug_report_outlined),
      onSelected: (fill) async {
        if (!fill) return stats.clear();
        final books = await ref.read(booksProvider.future);
        await fillWithSeed(
          stats,
          today: ref.read(statsClockProvider)(),
          bookIds: [for (final b in books) b.id],
        );
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: true, child: Text(l10n.debugStatsFill)),
        PopupMenuItem(value: false, child: Text(l10n.debugStatsClear)),
      ],
    );
  }
}

TextStyle? _secondary(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.readingColors.textSecondary);
