import 'dart:io';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// How far a book is read, as the library shows it.
final class ReadMark {
  const ReadMark({required this.percent, required this.finished});

  /// Null for a book never opened.
  final int? percent;

  /// Read to the end (or marked so): shown instead of the percent.
  final bool finished;

  bool get isEmpty => !finished && percent == null;
}

/// "42 %" with a short bar, or "✓ Прочитано"; nothing for an unopened book.
class ReadMarkLine extends StatelessWidget {
  const ReadMarkLine({super.key, required this.mark, this.barWidth = 64});

  final ReadMark mark;

  /// Null: the bar takes the free width.
  final double? barWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final style = Theme.of(context).textTheme.labelMedium;
    if (mark.finished) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 16, color: colors.accent),
          const SizedBox(width: 4),
          Text(
            l10n.libraryFinished,
            style: style?.copyWith(
              color: colors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    final percent = mark.percent;
    if (percent == null) return const SizedBox.shrink();
    final bar = _Bar(share: percent / 100);
    return Row(
      mainAxisSize: barWidth == null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (barWidth == null) Expanded(child: bar),
        if (barWidth == null) const SizedBox(width: 10),
        Text(
          l10n.libraryPercent(percent),
          style: style?.copyWith(color: colors.textSecondary),
        ),
        if (barWidth case final width?) ...[
          const SizedBox(width: 8),
          SizedBox(width: width, child: bar),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.share});

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
      color: Color.alphaBlend(
        colors.accent.withValues(alpha: 0.22),
        colors.background,
      ),
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

/// One book of the list: cover, title (up to two lines), authors, how far
/// it is read. Every row is at least as tall as the cover.
class BookTile extends StatelessWidget {
  const BookTile({
    super.key,
    required this.onTap,
    required this.coverFile,
    required this.title,
    required this.authors,
    required this.mark,
    this.titleFont,
  });

  static const coverWidth = 52.0;
  static const coverHeight = 76.0;

  final VoidCallback onTap;
  final File? coverFile;
  final String title;

  /// Empty when unknown.
  final String authors;
  final ReadMark mark;
  final String? titleFont;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.readingColors;
    return InkWell(
      onTap: onTap,
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
                  if (!mark.isEmpty) ...[
                    const SizedBox(height: 4),
                    ReadMarkLine(mark: mark),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One book of the grid: a cover with the percent or the "read" mark on
/// it, two lines of title and one of authors.
class BookGridTile extends StatelessWidget {
  const BookGridTile({
    super.key,
    required this.onTap,
    required this.coverFile,
    required this.title,
    required this.authors,
    required this.mark,
    this.titleFont,
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
      4;

  final VoidCallback onTap;
  final File? coverFile;
  final String title;
  final String authors;
  final ReadMark mark;
  final String? titleFont;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final percent = mark.percent;
    return InkWell(
      onTap: onTap,
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
                  if (mark.finished)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Semantics(
                        label: l10n.libraryFinished,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 15,
                            color: colors.background,
                          ),
                        ),
                      ),
                    )
                  else if (percent != null && percent > 0) ...[
                    Positioned(
                      right: 6,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          l10n.libraryPercent(percent),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 4,
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 4,
                        color: colors.accent,
                        backgroundColor: const Color(0x40000000),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: _gap),
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
            ],
          );
        },
      ),
    );
  }
}

/// "Продолжить": the book read last, large, over the shelves.
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.onTap,
    required this.coverFile,
    required this.title,
    required this.authors,
    required this.mark,
    this.titleFont,
  });

  static const _coverWidth = 84.0;
  static const _coverHeight = 120.0;

  final VoidCallback onTap;
  final File? coverFile;
  final String title;
  final String authors;
  final ReadMark mark;
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
                        ReadMarkLine(
                          mark: mark.isEmpty
                              ? const ReadMark(percent: 0, finished: false)
                              : mark,
                          barWidth: null,
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
