import 'package:book_app/features/stats/charts/chart_colors.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:flutter/material.dart';

/// A bar of [StackedBars]: its parts by mode, bottom to top in the order of
/// [ReadingMode]; null — the day has not come yet.
typedef BarParts = Map<ReadingMode, int>?;

/// Bars of days or months, each a stack of the reading modes, one scale for
/// all; a name under each bar, a value over it if given.
class StackedBars extends StatelessWidget {
  const StackedBars({
    super.key,
    required this.bars,
    required this.names,
    required this.colors,
    required this.label,
    this.values,
    this.current,
  });

  final List<BarParts> bars;

  /// Under the bars; null — none under this one.
  final List<String?> names;

  /// Over the bars, as many as [bars]; null — none.
  final List<String>? values;

  /// The bar of today, its name in bold.
  final int? current;

  final ChartColors colors;

  /// What the screen reader says instead.
  final String label;

  static const _height = 72.0;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall;
    int total(BarParts parts) =>
        parts?.values.fold<int>(0, (a, b) => a + b) ?? 0;
    final highest = bars.fold(0, (a, b) => a > total(b) ? a : total(b));
    final values = this.values;
    final gap = bars.length > 12
        ? 2.0
        : bars.length > 7
        ? 4.0
        : 8.0;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: gap,
          children: [
            for (final (i, parts) in bars.indexed)
              Expanded(
                child: Column(
                  spacing: 2,
                  children: [
                    if (values != null)
                      Text(
                        values[i],
                        style: small,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    _bar(parts, total(parts), highest),
                    // Smaller rather than into the next bar's name.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        names[i] ?? '',
                        style: small?.copyWith(
                          fontWeight: i == current ? FontWeight.w800 : null,
                        ),
                        maxLines: 1,
                        softWrap: false,
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

  Widget _bar(BarParts parts, int total, int highest) {
    if (parts == null || total == 0) {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: parts == null
              ? colors.line.withValues(alpha: 0.4)
              : colors.line,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    final height = (total / highest * _height).clamp(3.0, _height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: height,
        child: Column(
          verticalDirection: VerticalDirection.up,
          children: [
            for (final mode in ReadingMode.values)
              if ((parts[mode] ?? 0) > 0)
                Expanded(
                  flex: parts[mode]!,
                  child: ColoredBox(
                    color: colors.ofMode(mode),
                    child: const SizedBox.expand(),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
