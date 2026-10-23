import 'dart:io';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/library_view.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// The status of a book and how far it is read, as the library shows it.
final class ReadMark {
  const ReadMark({required this.status, this.percent = 0});

  ReadMark.of(BookRow book)
    : status = statusOf(book),
      percent = percentRead(book) ?? 0;

  final BookStatus status;
  final int percent;
}

/// "• Новая", "Читаю · 42 %", "На очереди", "Брошена" or "✓ Прочитано":
/// always words, not only a color.
class BookStatusLabel extends StatelessWidget {
  const BookStatusLabel({super.key, required this.mark});

  static const fontSize = 12.5;
  static const lineHeight = 1.3;

  final ReadMark mark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final on =
        mark.status == BookStatus.reading || mark.status == BookStatus.finished;
    final color = on ? colors.accent : colors.textSecondary;
    final (Widget? sign, String text) = switch (mark.status) {
      BookStatus.notStarted => (
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: colors.orp, shape: BoxShape.circle),
        ),
        l10n.statusNew,
      ),
      BookStatus.reading => (null, l10n.statusReading(mark.percent)),
      BookStatus.queued => (
        Icon(Icons.schedule, size: 14, color: color),
        l10n.statusQueued,
      ),
      BookStatus.abandoned => (
        Icon(Icons.pause_circle_outline, size: 14, color: color),
        l10n.statusAbandoned,
      ),
      BookStatus.finished => (
        Icon(Icons.check, size: 14, color: color),
        l10n.statusFinished,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sign != null) ...[sign, const SizedBox(width: 5)],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              height: lineHeight,
              fontWeight: on ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// How much of a book is read, as a thin bar.
class ReadBar extends StatelessWidget {
  const ReadBar({super.key, required this.share});

  static const height = 5.0;

  final double share;

  @override
  Widget build(BuildContext context) {
    final colors = context.readingColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: share,
          minHeight: height,
          color: colors.accent,
          backgroundColor: colors.text.withValues(alpha: 0.14),
        ),
      ),
    );
  }
}

/// A cover decoded at the size it is shown; a book without one (or with a
/// broken one) gets a tile with the first letter of its title.
/// Hues of covers drawn for books without one (owner, 14.6 B1).
const _placeholderHues = [30.0, 150.0, 260.0, 200.0, 340.0, 60.0];

/// A pastel of its own for a book without a cover, picked by the title and
/// laid over [background]: the same book is always the same color.
Color placeholderTint(String title, Color background) {
  final sum = title.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7fffffff);
  final hue = _placeholderHues[sum % _placeholderHues.length];
  final pastel = HSLColor.fromAHSL(1, hue, 0.45, 0.55).toColor();
  return Color.alphaBlend(pastel.withValues(alpha: 0.32), background);
}

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.file,
    required this.title,
    required this.width,
    required this.height,
    this.titleFont,
    this.badges = const [],
  });

  final File? file;
  final String title;
  final double width;
  final double height;
  final String? titleFont;

  /// Drawn over the cover (grid: percent, "read" mark).
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final file = this.file;
    final placeholder = _placeholder(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file == null)
              placeholder
            else
              Image.file(
                file,
                fit: BoxFit.cover,
                // Covers are portrait: decoded by height, they fill the box.
                cacheHeight: (height * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => placeholder,
              ),
            // A thin frame: bright covers do not glow at the edge, a
            // placeholder does not melt into the page (14.2, A9).
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: context.readingColors.text.withValues(alpha: 0.14),
                ),
              ),
            ),
            ...badges,
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = context.readingColors;
    final letter = title.trim().characters.firstOrNull?.toUpperCase() ?? '';
    return ColoredBox(
      color: placeholderTint(title, colors.background),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontFamily: titleFont,
            fontSize: width * 0.45,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
      ),
    );
  }
}

/// One book of the list: cover, title (up to two lines), authors, the
/// status. Every row is at least as tall as the cover.
class BookTile extends StatelessWidget {
  const BookTile({
    super.key,
    required this.onTap,
    this.onLongPress,
    required this.coverFile,
    required this.title,
    required this.authors,
    required this.mark,
    this.titleFont,
    this.picked,
  });

  /// 2:3, as in the grid (14.2, A16).
  static const coverWidth = 56.0;
  static const coverHeight = 84.0;

  final VoidCallback onTap;

  /// Opens the book menu.
  final VoidCallback? onLongPress;
  final File? coverFile;
  final String title;

  /// Empty when unknown.
  final String authors;
  final ReadMark mark;
  final String? titleFont;

  /// Not null while books are checked for a collection: a mark on the right.
  final bool? picked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.readingColors;
    return PickSemantics(
      picked: picked,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              BookCover(
                file: coverFile,
                title: title,
                width: coverWidth,
                height: coverHeight,
                titleFont: titleFont,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: titleFont,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (authors.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        authors,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(child: BookStatusLabel(mark: mark)),
                        if (mark.status == BookStatus.reading) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 56,
                            child: ReadBar(share: mark.percent / 100),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (picked case final picked?) ...[
                const SizedBox(width: 12),
                PickMark(picked: picked),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One book of the grid: a cover (with a progress bar while reading), two
/// lines of title, one of authors and the status.
class BookGridTile extends StatelessWidget {
  const BookGridTile({
    super.key,
    required this.onTap,
    this.onLongPress,
    required this.coverFile,
    required this.title,
    required this.authors,
    required this.mark,
    this.titleFont,
    this.picked,
  });

  static const _titleSize = 14.0;
  static const _titleHeight = 1.25;
  static const _authorSize = 12.0;
  static const _authorHeight = 1.3;
  static const _gap = 6.0;

  /// Height of a tile [width] wide: the cover is 2:3, the text below it
  /// grows with the system text size.
  static double heightFor(double width, TextScaler scaler) =>
      width * 1.5 +
      _gap +
      scaler.scale(_titleSize) * _titleHeight * 2 +
      scaler.scale(_authorSize) * _authorHeight +
      2 +
      scaler.scale(BookStatusLabel.fontSize) * BookStatusLabel.lineHeight +
      4;

  final VoidCallback onTap;

  /// Opens the book menu.
  final VoidCallback? onLongPress;
  final File? coverFile;
  final String title;
  final String authors;
  final ReadMark mark;
  final String? titleFont;

  /// Not null while books are checked for a collection: a mark on the
  /// cover, a frame around a checked one.
  final bool? picked;

  @override
  Widget build(BuildContext context) {
    final colors = context.readingColors;
    return PickSemantics(
      picked: picked,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(
                  file: coverFile,
                  title: title,
                  width: width,
                  height: width * 1.5,
                  titleFont: titleFont,
                  badges: [
                    if (mark.status == BookStatus.reading)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 4,
                        child: LinearProgressIndicator(
                          value: mark.percent / 100,
                          minHeight: 4,
                          color: colors.accent,
                          backgroundColor: const Color(0x40000000),
                        ),
                      ),
                    if (picked == true)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.accent, width: 3),
                          ),
                        ),
                      ),
                    if (picked case final picked?)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: PickMark(picked: picked, onCover: true),
                      ),
                  ],
                ),
                const SizedBox(height: _gap),
                // The status stays on one line across a row (14.2, A9).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: titleFont,
                          fontSize: _titleSize,
                          height: _titleHeight,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (authors.isNotEmpty)
                        Text(
                          authors,
                          style: TextStyle(
                            fontSize: _authorSize,
                            height: _authorHeight,
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const Spacer(),
                      BookStatusLabel(mark: mark),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A book checked or not for a collection; read out as a checkbox.
class PickSemantics extends StatelessWidget {
  const PickSemantics({super.key, required this.picked, required this.child});

  final bool? picked;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      picked == null ? child : Semantics(checked: picked, child: child);
}

/// The round check of a book being put in a collection.
class PickMark extends StatelessWidget {
  const PickMark({super.key, required this.picked, this.onCover = false});

  final bool picked;

  /// Over a cover: on a light disc, so it shows on any picture.
  final bool onCover;

  @override
  Widget build(BuildContext context) {
    final colors = context.readingColors;
    final icon = Icon(
      picked ? Icons.check_circle : Icons.radio_button_unchecked,
      size: 28,
      color: picked ? colors.accent : colors.textSecondary,
    );
    if (!onCover) return icon;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        shape: BoxShape.circle,
      ),
      child: icon,
    );
  }
}

/// "Продолжить": the book read last, large, over the shelves.
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.onTap,
    this.onLongPress,
    required this.coverFile,
    required this.title,
    required this.authors,
    required this.percent,
    this.titleFont,
  });

  static const _coverWidth = 84.0;
  static const _coverHeight = 120.0;

  final VoidCallback onTap;

  /// Opens the book menu.
  final VoidCallback? onLongPress;
  final File? coverFile;
  final String title;
  final String authors;
  final int percent;
  final String? titleFont;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.readingColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: BookCover(
                      file: coverFile,
                      title: title,
                      width: _coverWidth,
                      height: _coverHeight,
                      titleFont: titleFont,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.libraryContinue.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: titleFont,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (authors.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            authors,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const Spacer(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: ReadBar(share: percent / 100)),
                            const SizedBox(width: 10),
                            Text(
                              l10n.libraryPercent(percent),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
