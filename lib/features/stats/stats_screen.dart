import 'dart:async';

import 'package:book_app/app/pill_tabs.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/stats_seed.dart';
import 'package:book_app/features/library/book_shelf.dart';
import 'package:book_app/features/stats/charts/chart_colors.dart';
import 'package:book_app/features/stats/charts/reading_calendar.dart';
import 'package:book_app/features/stats/charts/stacked_bars.dart';
import 'package:book_app/features/stats/stats_format.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/stats/stats_calc.dart';
import 'package:book_app/stats/stats_overview.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The statistics over the reader, from "Статистика чтения" in the sheet about
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

class _StatsViewState extends ConsumerState<StatsView>
    with SingleTickerProviderStateMixin {
  var _period = StatsPeriod.month;

  /// The first cards come up one after another when the screen opens
  /// (owner, 14.3: «Каскад»).
  late final _appear = AnimationController(
    vsync: this,
    duration: _Appear.total,
  );
  var _appeared = false;

  @override
  void dispose() {
    _appear.dispose();
    super.dispose();
  }

  /// Called by build; starts after the frame, not while building.
  void _playAppear() {
    if (_appeared) return;
    _appeared = true;
    final still = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (still) {
        _appear.value = 1;
      } else {
        unawaited(_appear.forward());
      }
    });
  }

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
    final rows = ref.watch(readingDaysProvider).value;
    if (rows == null) return const SizedBox.shrink();
    final today = ref.read(statsClockProvider)();
    final overview = StatsOverview.of(
      _period,
      rows: rows,
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
    _playAppear();
    final cards = [
      _SavedCard(overview),
      if (_period == StatsPeriod.month)
        _CalendarCard(overview.calendar, today: today)
      else
        _BarsCard(overview),
      _YearCard(overview.year, year: today.year),
    ];
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
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) =>
                  _Appear(animation: _appear, index: i, child: cards[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// A card of the cascade: fades in and rises by 10 dp, 240 ms, 50 ms after
/// the one above; past the sixth at once (mockup `page-turn.html`).
class _Appear extends StatelessWidget {
  const _Appear({
    required this.animation,
    required this.index,
    required this.child,
  });

  static const _one = 240;
  static const _step = 50;
  static const _cards = 6;
  static const total = Duration(milliseconds: _one + _step * (_cards - 1));

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (index >= _cards) return child;
    final ms = total.inMilliseconds;
    final start = index * _step / ms;
    final curve = Interval(
      start,
      start + _one / ms,
      curve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final shown = curve.transform(animation.value);
        return Opacity(
          opacity: shown,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - shown)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// "Скорочтение сэкономило": the time, the period, the time it would have
/// taken by eye and the time it took.
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
        _inPhrase(DateFormat.LLLL(locale).format(overview.from), locale),
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
          [period, l10n.statsReadingDays(overview.readingDays)].join(' · '),
          style: secondary,
        ),
        if (read) ...[
          const SizedBox(height: 8),
          Text(
            l10n.statsSavedSentence(
              formatDuration(l10n, saved.usual),
              formatDuration(l10n, saved.actual),
            ),
            style: text.bodyMedium,
          ),
          if (!saved.faster) Text(l10n.statsNotFaster, style: secondary),
          if (!overview.eyeSpeed.known)
            Text(l10n.statsSavedAverage(fallbackPageWpm), style: secondary),
        ],
      ],
    );
  }
}

/// "Чтение по дням" of the week or "по месяцам" of the year: a bar each,
/// stacked by mode, its value over it; time or pages by the switch.
class _BarsCard extends StatefulWidget {
  const _BarsCard(this.overview);

  final StatsOverview overview;

  @override
  State<_BarsCard> createState() => _BarsCardState();
}

class _BarsCardState extends State<_BarsCard> {
  var _pages = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chart = ChartColors.of(context.readingColors);
    final secondary = _secondary(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final months = l10n.statsMonthsShort.split(' ')
      ..removeWhere((m) => m.isEmpty);
    final overview = widget.overview;
    final bars = overview.bars;
    final byMonths = overview.period == StatsPeriod.year;
    final pages = _pages;
    Map<ReadingMode, int> partsOf(DayBar bar) => pages ? bar.words : bar.ms;
    // Minutes of a day, hours of a month.
    final hours = NumberFormat('#0.#', locale);
    String valueOf(DayBar bar) => bar.future
        ? ''
        : pages
        ? (bar.totalWords > 0 ? '${pagesOf(bar.totalWords)}' : '')
        : bar.totalMs <= 0
        ? ''
        : byMonths
        ? hours.format(bar.totalMs / 3600000)
        : '${(bar.totalMs / 60000).round()}';
    String spoken(DayBar bar) => pages
        ? l10n.statsPages(pagesOf(bar.totalWords))
        : formatDuration(l10n, Duration(milliseconds: bar.totalMs));
    final spokenName = byMonths
        ? DateFormat.LLLL(locale)
        : DateFormat.EEEE(locale);
    final title = byMonths
        ? l10n.statsReadingByMonths
        : l10n.statsReadingByDays;
    final modes = {
      for (final bar in bars)
        for (final MapEntry(:key, :value) in partsOf(bar).entries)
          if (value > 0) key,
    };
    return _Card(
      title: title,
      trailing: SizedBox(
        width: 190,
        child: PillTabs(
          tabs: {
            false: byMonths ? l10n.statsUnitHours : l10n.statsUnitMinutes,
            true: l10n.statsUnitPages,
          },
          selected: pages,
          onChanged: (value) => setState(() => _pages = value),
          margin: EdgeInsets.zero,
          dense: true,
        ),
      ),
      children: [
        const SizedBox(height: 8),
        StackedBars(
          bars: [for (final bar in bars) bar.future ? null : partsOf(bar)],
          names: [
            for (final bar in bars)
              byMonths
                  // Three letters: «И И» could not be told apart (14.2, A6).
                  ? months.length == 12
                        ? months[bar.from.month - 1]
                        : DateFormat.LLL(locale).format(bar.from)
                  : capitalized(DateFormat.E(locale).format(bar.from)),
          ],
          values: [for (final bar in bars) valueOf(bar)],
          current: bars.lastIndexWhere((bar) => !bar.future),
          colors: chart,
          label: [
            title,
            [
              for (final bar in bars)
                if (partsOf(bar).values.any((v) => v > 0))
                  l10n.statsBar(spokenName.format(bar.from), spoken(bar)),
            ].join('; '),
          ].where((part) => part.isNotEmpty).map(_noFinalPeriod).join('. '),
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
          dayText: (day) {
            final date = DateFormat.MMMMd(locale).format(day.from);
            return day.totalMs <= 0
                ? l10n.statsCalendarDayNone(date)
                : l10n.statsCalendarDay(
                    date,
                    formatDuration(l10n, Duration(milliseconds: day.totalMs)),
                    pagesOf(day.totalWords),
                  );
          },
        ),
        const SizedBox(height: 4),
        Text(l10n.statsCalendarHint, style: _secondary(context)),
      ],
    );
  }
}

/// "Итоги": finished books, time, pages and the two average speeds of this
/// [year], a row each.
class _YearCard extends StatelessWidget {
  const _YearCard(this.totals, {required this.year});

  final YearTotals totals;
  final int year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final chart = ChartColors.of(colors);
    final text = Theme.of(context).textTheme;
    final secondary = _secondary(context);
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    Widget item(String name, String value, {String? kind, Color? color}) =>
        MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: text.bodyMedium),
                      if (kind != null) Text(kind, style: secondary),
                    ],
                  ),
                ),
                Text(
                  value,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
    String speed(int? wpm) =>
        wpm == null ? l10n.statsSpeedUnknown : '$wpm ${l10n.statsWpm}';
    final line = Divider(height: 1, color: chart.line.withValues(alpha: 0.5));
    return _Card(
      title: l10n.statsYearTitle(year),
      children: [
        item(l10n.statsYearBooksRead, '${totals.books}'),
        line,
        item(l10n.statsYearTimeRead, formatDuration(l10n, totals.time)),
        line,
        item(l10n.statsYearPagesRead, number.format(pagesOf(totals.words))),
        line,
        item(
          l10n.statsYearSpeed,
          speed(totals.eyeWpm),
          kind: l10n.statsYearEyeReading,
          color: totals.eyeWpm == null ? null : chart.eye,
        ),
        line,
        item(
          l10n.statsYearSpeed,
          speed(totals.playWpm),
          kind: l10n.statsYearSpeedReading,
          color: totals.playWpm == null ? null : chart.play,
        ),
        const SizedBox(height: 2),
        Text(l10n.statsPagesHow, style: secondary),
      ],
    );
  }
}

/// A block of the screen: its name over the content.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;

  /// By the title, at the end.
  final Widget? trailing;

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
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              ?trailing,
            ],
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

/// A month name inside a phrase: Russian ones are lowercase there.
String _inPhrase(String month, String locale) =>
    locale.startsWith('ru') ? month.toLowerCase() : month;

/// A sentence to be joined with «. ».
String _noFinalPeriod(String text) =>
    text.endsWith('.') ? text.substring(0, text.length - 1) : text;
