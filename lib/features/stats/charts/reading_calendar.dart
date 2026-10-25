import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/features/stats/charts/chart_colors.dart';
import 'package:book_app/features/stats/stats_format.dart';
import 'package:book_app/stats/stats_overview.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A month from Monday, in the palette accent (owner, 14.6 B4): a day the
/// darker, the longer it was read; today outlined, the days to come only
/// drawn round. Each day has its date; a tap on a day that has come shows
/// [dayText] over it.
class ReadingCalendar extends StatelessWidget {
  const ReadingCalendar({
    super.key,
    required this.days,
    required this.today,
    required this.colors,
    required this.label,
    required this.dayText,
  });

  /// The days of one month, from the 1st.
  final List<DayBar> days;
  final DateTime today;
  final ChartColors colors;

  /// What the screen reader says instead.
  final String label;

  /// What a tap on a day shows.
  final String Function(DayBar day) dayText;

  static const _alpha = [0.0, 0.35, 0.65, 1.0];

  @override
  Widget build(BuildContext context) {
    final reading = context.readingColors;
    final small = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: reading.textSecondary, fontWeight: FontWeight.w600);
    final weekday = DateFormat.E(
      Localizations.localeOf(context).toLanguageTag(),
    );
    // 2024-01-01 is a Monday.
    final names = [
      for (var d = 1; d <= 7; d++)
        capitalized(weekday.format(DateTime(2024, 1, d))),
    ];
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Column(
          spacing: 6,
          children: [
            Row(
              spacing: 5,
              children: [
                for (final name in names)
                  Expanded(
                    child: Text(
                      name,
                      style: small,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
            GridView.count(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 1; i < days.first.from.weekday; i++)
                  const SizedBox(),
                for (final day in days) _day(context, day),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _day(BuildContext context, DayBar day) {
    final reading = context.readingColors;
    final level = day.future ? 0 : calendarLevel(day.totalMs);
    final now = DateUtils.isSameDay(day.from, today);
    final cell = DecoratedBox(
      decoration: BoxDecoration(
        color: level == 0 ? null : colors.eye.withValues(alpha: _alpha[level]),
        borderRadius: BorderRadius.circular(7),
        border: now
            ? Border.all(color: reading.text, width: 2)
            : level == 0
            ? Border.all(
                color: day.future
                    ? colors.line.withValues(alpha: 0.5)
                    : colors.line,
              )
            : null,
      ),
      child: Center(
        child: Text(
          '${day.from.day}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            // On the dark shades, the page color reads best.
            color: level >= 2
                ? reading.background
                : level == 1
                ? reading.text
                : reading.textSecondary.withValues(alpha: day.future ? 0.5 : 1),
          ),
        ),
      ),
    );
    if (day.future) return cell;
    return Tooltip(
      message: dayText(day),
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      showDuration: const Duration(seconds: 3),
      decoration: BoxDecoration(
        color: reading.text,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: reading.background, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: cell,
    );
  }
}
