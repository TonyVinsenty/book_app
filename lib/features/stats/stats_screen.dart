import 'package:book_app/app/pill_tabs.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/stats_seed.dart';
import 'package:book_app/features/library/book_shelf.dart';
import 'package:book_app/features/stats/charts/chart_colors.dart';
import 'package:book_app/features/stats/charts/speed_line_chart.dart';
import 'package:book_app/features/stats/stats_format.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/stats_calc.dart';
import 'package:book_app/stats/stats_overview.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (rows, pace) = (
      ref.watch(readingDaysProvider).value,
      ref.watch(paceDaysProvider).value,
    );
    if (rows == null || pace == null) return const SizedBox.shrink();
    final overview = StatsOverview.of(
      _period,
      rows: rows,
      pace: pace,
      today: ref.read(statsClockProvider)(),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
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
        const SizedBox(height: 12),
        _SavedCard(overview),
        const SizedBox(height: 12),
        _SpeedCard(overview),
        const SizedBox(height: 12),
        _PaceCard(overview.pace),
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
            Text(l10n.statsSavedAverage, style: secondary),
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
