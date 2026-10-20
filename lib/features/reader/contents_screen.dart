import 'dart:math';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/book/model/table_of_contents.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/layout/book_pagination.dart';
import 'package:flutter/material.dart';

/// The table of contents; pops with the section index of the tapped line.
///
/// Laid out as in a printed book: titles in the book's [fontFamily], dots
/// up to the page number on the right; a long title has its dots and
/// number on its last line.
class ContentsScreen extends StatefulWidget {
  const ContentsScreen({
    required this.lines,
    required this.current,
    this.fontFamily,
    this.pageOf,
    this.pageUpdates,
    super.key,
  });

  final List<ContentsLine> lines;

  /// The line of the chapter being read: lit and in view from the start.
  final int? current;

  final String? fontFamily;

  /// The book page a section starts on (from 1), maybe an estimate while
  /// the book is being split; no numbers if null.
  final PageNumber Function(int section)? pageOf;

  /// Tells when [pageOf] may give other numbers.
  final Listenable? pageUpdates;

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
    final colors = context.readingColors;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.readerContents),
        backgroundColor: colors.surface,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const lineHeight = ContentsScreen.lineHeight;
          final height = constraints.maxHeight;
          // The current line a quarter of the way down, if the list allows.
          final top = (widget.current ?? 0) * lineHeight - height / 4;
          final end = max(0.0, widget.lines.length * lineHeight - height);
          _scroll ??= ScrollController(initialScrollOffset: top.clamp(0, end));
          final updates = widget.pageUpdates;
          return updates == null
              ? _list(context)
              : ListenableBuilder(
                  listenable: updates,
                  builder: (context, _) => _list(context),
                );
        },
      ),
    );
  }

  Widget _list(BuildContext context) {
    final lines = widget.lines;
    final current = widget.current;
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final text = Theme.of(context).textTheme.bodyLarge?.copyWith(
      height: 1.25,
      fontFamily: widget.fontFamily,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final pageOf = widget.pageOf;
    String? number(int section) {
      if (pageOf == null) return null;
      final page = pageOf(section);
      return page.exact ? '${page.value}' : l10n.readerApproxNumber(page.value);
    }

    // The widest number: titles keep clear of its column.
    final numbers = [for (final line in lines) number(line.sectionIndex)];
    final widest = numbers.fold<String?>(
      null,
      (w, n) => n != null && n.length > (w?.length ?? 0) ? n : w,
    );
    return ListView.builder(
      controller: _scroll,
      itemExtent: ContentsScreen.lineHeight,
      itemCount: lines.length,
      itemBuilder: (context, i) {
        final line = lines[i];
        final selected = i == current;
        final style = (text ?? const TextStyle()).copyWith(
          color: selected ? colors.accent : colors.text,
          fontWeight: selected ? FontWeight.w600 : null,
        );
        return Semantics(
          selected: selected,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(line.sectionIndex),
            child: Ink(
              color: selected ? colors.accent.withValues(alpha: 0.12) : null,
              padding: EdgeInsetsDirectional.only(
                start: 16.0 + 16 * min(line.level, 4),
                end: 16,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _ContentsLineText(
                  title:
                      line.title ??
                      l10n.readerChapterNumber(line.sectionIndex + 1),
                  number: numbers[i],
                  widestNumber: widest,
                  style: style,
                  dotColor: colors.textSecondary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A title of up to two lines, then dots and the page number on its last
/// line.
class _ContentsLineText extends StatelessWidget {
  const _ContentsLineText({
    required this.title,
    required this.number,
    required this.widestNumber,
    required this.style,
    required this.dotColor,
  });

  final String title;
  final String? number;
  final String? widestNumber;
  final TextStyle style;
  final Color dotColor;

  /// Room between the title, the dots and the number.
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final number = this.number;
    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (number == null) return titleText;
    return LayoutBuilder(
      builder: (context, constraints) {
        final direction = Directionality.of(context);
        final scaler = MediaQuery.textScalerOf(context);
        TextPainter measure(String text, {double? width}) => TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: width == null ? 1 : 2,
          ellipsis: width == null ? null : '…',
        )..layout(maxWidth: width ?? double.infinity);
        final width = constraints.maxWidth;
        final column = measure(widestNumber ?? number);
        final numberText = measure(number);
        final titleWidth = max(0.0, width - column.width - _gap * 2);
        final titleLayout = measure(title, width: titleWidth);
        final lastLine = titleLayout.computeLineMetrics().lastOrNull;
        final numberLine = numberText.computeLineMetrics().firstOrNull;
        final height = titleLayout.height;
        final baseline = lastLine?.baseline ?? height;
        final numberTop = baseline - (numberLine?.baseline ?? 0);
        final dotsFrom = (lastLine?.width ?? 0) + _gap;
        final dotsTo = width - numberText.width - _gap;
        column.dispose();
        numberText.dispose();
        titleLayout.dispose();
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(width: titleWidth, child: titleText),
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotsPainter(
                    from: dotsFrom,
                    to: dotsTo,
                    baseline: baseline,
                    size: scaler.scale(style.fontSize ?? 16),
                    color: dotColor,
                    textDirection: direction,
                  ),
                ),
              ),
              PositionedDirectional(
                end: 0,
                top: numberTop,
                child: Text(number, style: style, maxLines: 1),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Leader dots on [baseline] between [from] and [to] (from the start
/// edge), on a grid from the end edge, the same for every line (whatever
/// its indent), so that they line up.
class _DotsPainter extends CustomPainter {
  _DotsPainter({
    required this.from,
    required this.to,
    required this.baseline,
    required this.size,
    required this.color,
    required this.textDirection,
  });

  final double from;
  final double to;
  final double baseline;

  /// Font size: the dots and their spacing follow it.
  final double size;
  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size area) {
    final step = size * 0.45;
    final radius = size * 0.06;
    final dot = Paint()..color = color;
    final y = baseline - radius;
    final end = area.width;
    for (var x = end - ((end - to) / step).ceil() * step; x >= from; x -= step) {
      final dx = textDirection == TextDirection.ltr ? x : area.width - x;
      canvas.drawCircle(Offset(dx, y), radius, dot);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.from != from ||
      old.to != to ||
      old.baseline != baseline ||
      old.size != size ||
      old.color != color ||
      old.textDirection != textDirection;
}
