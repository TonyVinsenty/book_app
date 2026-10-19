import 'dart:async';

import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/book_opener.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/features/speed/rsvp_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/layout/chapter_layout.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:book_app/speed/timing.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Normal reading: one page at a time (ADR 0003).
class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key, required this.bookId, this.reopened = false});

  final int bookId;

  /// Opened on start, not by the user: if the book fails, go back to the
  /// library with a short message instead of an error page.
  final bool reopened;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (reopened) {
      ref.listen(openedBookProvider(bookId), (_, next) {
        if (next is! AsyncError) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.readerReopenFailed)));
        Navigator.of(context).pop();
      });
    }
    final opened = ref.watch(openedBookProvider(bookId));
    return Scaffold(
      backgroundColor: context.readingColors.background,
      body: switch (opened) {
        AsyncData(:final value) => ReaderView(opened: value),
        AsyncError() => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.readerOpenFailed, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.readerBackToLibrary),
                ),
              ],
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Pages of an opened book. Taps on the left and right thirds turn pages,
/// the middle shows or hides the top bar; swipes turn pages too. A long
/// press on a word starts speed reading from it.
class ReaderView extends ConsumerStatefulWidget {
  const ReaderView({super.key, required this.opened});

  final OpenedBook opened;

  @override
  ConsumerState<ReaderView> createState() => ReaderViewState();
}

class ReaderViewState extends ConsumerState<ReaderView>
    with SingleTickerProviderStateMixin {
  static const _margin = EdgeInsets.fromLTRB(24, 20, 24, 0);
  static const _footerHeight = 36.0;

  /// Chapters laid out for the current page size and style.
  final _layouts = <int, ChapterLayout>{};
  Size? _pageSize;
  PageStyle? _style;

  late int _section;
  int _page = 0;

  /// The word the current page is kept on when the layout changes.
  late int _word;
  bool _barShown = false;

  /// The word speed reading stopped on: lit for about a second, then fades
  /// (ADR 0004 п. 10).
  int? _litWord;
  late final AnimationController _lit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @visibleForTesting
  ChapterLayout get layout => _layoutOf(_section);

  @visibleForTesting
  ChapterPage get page => layout.pages[_page];

  @visibleForTesting
  int? get litWord => _litWord;

  @override
  void initState() {
    super.initState();
    final tokens = widget.opened.tokens;
    _word = widget.opened.wordIndex;
    _section = tokens.isEmpty ? 0 : tokens[_word].sectionIndex;
    unawaited(
      ref.read(bookRepositoryProvider).markOpened(widget.opened.book.id),
    );
  }

  @override
  void dispose() {
    _lit.dispose();
    _clearLayouts();
    super.dispose();
  }

  void _clearLayouts() {
    for (final layout in _layouts.values) {
      layout.dispose();
    }
    _layouts.clear();
  }

  ChapterLayout _layoutOf(int section) {
    final cached = _layouts[section];
    if (cached != null) return cached;
    // Keep only the neighbours of the chapter being read.
    _layouts.removeWhere((s, layout) {
      final far = (s - section).abs() > 1;
      if (far) layout.dispose();
      return far;
    });
    return _layouts[section] = ChapterLayout.build(
      tokens: widget.opened.tokens,
      sectionIndex: section,
      style: _style!,
      pageSize: _pageSize!,
    );
  }

  /// New page size or style: lay out again and find the same word.
  void _relayoutIfNeeded(Size pageSize, PageStyle style) {
    if (pageSize == _pageSize && style == _style) return;
    _clearLayouts();
    _pageSize = pageSize;
    _style = style;
    _page = _layoutOf(_section).pageOfWord(_word);
  }

  void _next() {
    final sections = widget.opened.tokens.content.sections.length;
    if (_page + 1 < layout.pages.length) return _show(_section, _page + 1);
    for (var s = _section + 1; s < sections; s++) {
      if (_layoutOf(s).pages.isNotEmpty) return _show(s, 0);
    }
  }

  void _previous() {
    if (_page > 0) return _show(_section, _page - 1);
    for (var s = _section - 1; s >= 0; s--) {
      final pages = _layoutOf(s).pages;
      if (pages.isNotEmpty) return _show(s, pages.length - 1);
    }
  }

  void _show(int section, int pageIndex) {
    final shown = _layoutOf(section).pages[pageIndex];
    setState(() {
      _section = section;
      _page = pageIndex;
      _word = shown.firstWord;
    });
    if (!shown.hasWords) return;
    unawaited(
      ref
          .read(bookRepositoryProvider)
          .savePosition(
            widget.opened.book.id,
            widget.opened.tokens.positionOf(shown.firstWord),
          ),
    );
  }

  Future<void> _onLongPress(LongPressStartDetails details) async {
    final word = layout.wordAt(_page, details.localPosition - _margin.topLeft);
    if (word == null) return;
    unawaited(HapticFeedback.selectionClick());
    await _speedRead(word);
  }

  /// Speed reading from [word]; back on the page of the last word shown.
  Future<void> _speedRead(int word) async {
    final saved = await ref
        .read(settingsRepositoryProvider)
        .get(SettingKeys.speedWpm);
    if (!mounted) return;
    final last = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => RsvpScreen(
          opened: widget.opened,
          startWord: word,
          wordsPerMinute: int.tryParse(saved ?? '') ?? SpeedLimits.initial,
        ),
      ),
    );
    if (mounted && last != null) _showWord(last);
  }

  /// Opens the page with [word], lights it and keeps the place on it.
  void _showWord(int word) {
    final section = widget.opened.tokens[word].sectionIndex;
    setState(() {
      _section = section;
      _page = _layoutOf(section).pageOfWord(word);
      _word = word;
      _litWord = word;
      _barShown = false;
    });
    unawaited(_lit.forward(from: 0));
    unawaited(
      ref
          .read(bookRepositoryProvider)
          .savePosition(
            widget.opened.book.id,
            widget.opened.tokens.positionOf(word),
          ),
    );
  }

  void _onTapUp(TapUpDetails details, double width) {
    final x = details.localPosition.dx;
    if (x < width / 3) {
      _previous();
    } else if (x > width * 2 / 3) {
      _next();
    } else {
      setState(() => _barShown = !_barShown);
    }
  }

  void _onSwipe(DragEndDetails details) {
    final speed = details.primaryVelocity ?? 0;
    if (speed < -200) _next();
    if (speed > 200) _previous();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.readingColors;
    final l10n = AppLocalizations.of(context);
    final style = PageStyle(
      fontFamily: BookFont.literata.family,
      color: colors.text,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final secondary = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: colors.textSecondary);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pageSize = Size(
            constraints.maxWidth - _margin.horizontal,
            constraints.maxHeight - _margin.vertical - _footerHeight,
          );
          _relayoutIfNeeded(pageSize, style);
          final chapter = layout;
          final title = widget.opened.tokens.content.sections[_section].title;
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onTapUp(d, constraints.maxWidth),
                onHorizontalDragEnd: _onSwipe,
                onLongPressStart: _onLongPress,
                child: Padding(
                  padding: _margin,
                  child: Column(
                    children: [
                      Semantics(
                        container: true,
                        label: chapter.pageText(_page),
                        child: CustomPaint(
                          size: pageSize,
                          painter: _PagePainter(
                            chapter,
                            _page,
                            lit: _litWord == null
                                ? const []
                                : chapter.wordBoxes(_page, _litWord!),
                            litColor: colors.highlight,
                            litAnimation: _lit,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: _footerHeight,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title ?? '',
                                style: secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              l10n.readerPageOfChapter(
                                _page + 1,
                                chapter.pages.length,
                              ),
                              style: secondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_barShown)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    color: colors.surface,
                    elevation: 2,
                    child: Row(
                      children: [
                        const BackButton(),
                        Expanded(
                          child: Text(
                            widget.opened.book.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.speed),
                          label: Text(l10n.readerSpeedRead),
                          onPressed: () => _speedRead(page.firstWord),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PagePainter extends CustomPainter {
  _PagePainter(
    this.chapter,
    this.page, {
    required this.lit,
    required this.litColor,
    required this.litAnimation,
  }) : super(repaint: litAnimation);

  final ChapterLayout chapter;
  final int page;

  /// Boxes of the lit word on this page.
  final List<Rect> lit;
  final Color litColor;

  /// Full for the first 70%, then fades out.
  final AnimationController litAnimation;

  double get _litOpacity {
    if (!litAnimation.isAnimating) return 0;
    final t = litAnimation.value;
    return t < 0.7 ? 1 : (1 - t) / 0.3;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = _litOpacity;
    if (opacity > 0) {
      final paint = Paint()..color = litColor.withValues(alpha: opacity);
      for (final box in lit) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(box.inflate(2), const Radius.circular(4)),
          paint,
        );
      }
    }
    chapter.paintPage(canvas, page);
  }

  @override
  bool shouldRepaint(_PagePainter old) =>
      old.chapter != chapter ||
      old.page != page ||
      !listEquals(old.lit, lit) ||
      old.litColor != litColor;
}
