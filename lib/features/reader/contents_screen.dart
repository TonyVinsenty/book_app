import 'dart:math';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/book/model/table_of_contents.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// The table of contents; pops with the section index of the tapped line.
class ContentsScreen extends StatefulWidget {
  const ContentsScreen({required this.lines, required this.current, super.key});

  final List<ContentsLine> lines;

  /// The line of the chapter being read: lit and in view from the start.
  final int? current;

  /// Every line is two lines of text tall at most, so the current one can
  /// be scrolled to before anything is built.
  static const lineHeight = 56.0;

  @override
  State<ContentsScreen> createState() => _ContentsScreenState();
}

class _ContentsScreenState extends State<ContentsScreen> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const lineHeight = ContentsScreen.lineHeight;
    final lines = widget.lines;
    final current = widget.current;
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final text = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.25);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.readerContents),
        backgroundColor: colors.surface,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          // The current line a quarter of the way down, if the list allows.
          final top = (current ?? 0) * lineHeight - height / 4;
          final end = max(0.0, lines.length * lineHeight - height);
          _scroll ??= ScrollController(initialScrollOffset: top.clamp(0, end));
          return ListView.builder(
            controller: _scroll,
            itemExtent: lineHeight,
            itemCount: lines.length,
            itemBuilder: (context, i) {
              final line = lines[i];
              final selected = i == current;
              return Semantics(
                selected: selected,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(line.sectionIndex),
                  child: Ink(
                    color: selected
                        ? colors.accent.withValues(alpha: 0.12)
                        : null,
                    padding: EdgeInsetsDirectional.only(
                      start: 16.0 + 16 * min(line.level, 4),
                      end: 16,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        line.title ??
                            l10n.readerChapterNumber(line.sectionIndex + 1),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text?.copyWith(
                          color: selected ? colors.accent : colors.text,
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
