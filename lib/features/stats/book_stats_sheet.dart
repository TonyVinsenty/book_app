import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/features/stats/stats_format.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/stats/book_stats.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Opens the sheet "This book" over the reader (ADR 0009 п. 6).
Future<void> showBookStatsSheet(
  BuildContext context, {
  required String title,
  required BookStats stats,
  required int wordsLeft,
  required double progress,
  required DateTime today,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: context.readingColors.background,
  builder: (_) => BookStatsSheet(
    title: title,
    stats: stats,
    wordsLeft: wordsLeft,
    progress: progress,
    today: today,
  ),
);

/// Time left and the likely day the book is finished, the two speeds, the
/// time spent on it and what speed reading saved.
class BookStatsSheet extends StatelessWidget {
  const BookStatsSheet({
    super.key,
    required this.title,
    required this.stats,
    required this.wordsLeft,
    required this.progress,
    required this.today,
  });

  final String title;
  final BookStats stats;

  /// Words from the shown page to the book's end.
  final int wordsLeft;

  /// The share read, 0–1.
  final double progress;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final text = Theme.of(context).textTheme;
    final secondary = text.bodySmall?.copyWith(color: colors.textSecondary);
    final finish = stats.finishOn(wordsLeft, today);
    final saved = stats.saved;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.bookStatsTitle.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  title,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            _Tile(
              children: [
                Text(l10n.bookStatsLeft, style: secondary),
                Text(
                  l10n.bookStatsLeftTime(
                    formatDuration(l10n, stats.left(wordsLeft)),
                  ),
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: l10n.bookStatsProgress((progress * 100).floor()),
                  child: ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: colors.accent,
                      backgroundColor: colors.textSecondary.withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ),
                ),
                if (finish != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    finish == DateUtils.dateOnly(today)
                        ? l10n.bookStatsFinishToday
                        : l10n.bookStatsFinish(_date(context, finish)),
                    style: secondary,
                  ),
                ],
              ],
            ),
            _Pair(
              _Speed(
                label: l10n.statsEyeReading,
                wpm: stats.eyeSpeed.known ? stats.eyeSpeed.wpm : null,
              ),
              _Speed(label: l10n.statsSpeedReading, wpm: stats.playSpeed),
            ),
            _Pair(
              _Value(
                label: l10n.bookStatsSpent,
                value: formatDuration(l10n, stats.spent),
              ),
              _Value(
                label: l10n.statsSaved,
                value: formatDuration(l10n, saved.saved),
                note: saved.actual > Duration.zero && !saved.faster
                    ? l10n.statsNotFaster
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «2 ноября»; with the year when it is not this one.
  String _date(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return (date.year == today.year
            ? DateFormat.MMMMd(locale)
            : DateFormat.yMMMMd(locale))
        .format(date);
  }
}

class _Pair extends StatelessWidget {
  const _Pair(this.first, this.second);

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Expanded(child: first),
        Expanded(child: second),
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.readingColors.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: children,
        ),
      ),
    ),
  );
}

/// A speed in words per minute; null — not known yet.
class _Speed extends StatelessWidget {
  const _Speed({required this.label, required this.wpm});

  final String label;
  final int? wpm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final text = Theme.of(context).textTheme;
    final secondary = text.bodySmall?.copyWith(color: colors.textSecondary);
    final wpm = this.wpm;
    return _Tile(
      children: [
        Text(label, style: secondary),
        if (wpm == null)
          Text(l10n.statsSpeedUnknown, style: text.bodyMedium)
        else ...[
          Text('$wpm', style: _mid(text)),
          Text(l10n.statsWpm, style: secondary),
        ],
      ],
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.readingColors;
    final text = Theme.of(context).textTheme;
    final secondary = text.bodySmall?.copyWith(color: colors.textSecondary);
    return _Tile(
      children: [
        Text(label, style: secondary),
        Text(value, style: _mid(text)),
        if (note case final note?) Text(note, style: secondary),
      ],
    );
  }
}

TextStyle? _mid(TextTheme text) =>
    text.headlineSmall?.copyWith(fontWeight: FontWeight.w800);
