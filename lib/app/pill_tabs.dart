import 'package:book_app/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A row of tabs in a pill, the chosen one filled: the library tabs, the
/// statistics periods.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
    this.margin = const EdgeInsets.fromLTRB(16, 6, 16, 4),
  });

  /// Each tab and its name, in order.
  final Map<T, String> tabs;
  final T selected;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colors = context.readingColors;
    Widget tab(T tab, String name) {
      final on = tab == selected;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: Material(
            color: on ? colors.accent : Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: on ? null : () => onChanged(tab),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: on ? colors.background : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          for (final MapEntry(:key, :value) in tabs.entries) tab(key, value),
        ],
      ),
    );
  }
}
