import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/features/stats/charts/chart_colors.dart';
import 'package:book_app/features/stats/stats_format.dart';
import 'package:book_app/stats/stats_overview.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A month from Monday: a day the darker, the longer it was read; today
/// outlined, the days to come only drawn round.
class ReadingCalendar extends StatelessWidget {
  const ReadingCalendar({
    super.key,
    required this.days,
    required this.today,
    required this.colors,
    required this.label,
  });

  /// The days of one month, from the 1st.
  final List<DayBar> days;
  final DateTime today;
  final ChartColors colors;

  /// What the screen reader says instead.
  final String label;

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
                for (final day in days) _day(day, reading.text),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _day(DayBar day, Color text) {
    final level = day.future ? 0 : calendarLevel(day.totalMs);
    final now = DateUtils.isSameDay(day.from, today);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: level == 0 ? null : colors.play.withValues(alpha: _alpha[level]),
        borderRadius: BorderRadius.circular(7),
        border: now
            ? Border.all(color: text, width: 2)
            : level == 0
            ? Border.all(
                color: day.future
                    ? colors.line.withValues(alpha: 0.5)
                    : colors.line,
              )
            : null,
      ),
    );
  }
}
