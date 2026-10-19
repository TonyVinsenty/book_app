import 'dart:async';

import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/book_opener.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/layout/chapter_layout.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Normal reading: one page at a time (ADR 0003).
class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key, required this.bookId});

  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opened = ref.watch(openedBookProvider(bookId));
    return Scaffold(
      backgroundColor: context.readingColors.background,
      body: switch (opened) {
        AsyncData(:final value) => ReaderView(opened: value),
        AsyncError() => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              AppLocalizations.of(context).readerOpenFailed,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Pages of an opened book. Taps on the left and right thirds turn pages,
/// the middle shows or hides the top bar; swipes turn pages too.
class ReaderView extends ConsumerStatefulWidget {
  const ReaderView({super.key, required this.opened});

  final OpenedBook opened;

  @override
  ConsumerState<ReaderView> createState() => ReaderViewState();
}

class ReaderViewState extends ConsumerState<ReaderView> {
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

  @visibleForTesting
  ChapterLayout get layout => _layoutOf(_section);

  @visibleForTesting
  ChapterPage get page => layout.pages[_page];

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
                child: Padding(
                  padding: _margin,
                  child: Column(
                    children: [
                      Semantics(
                        container: true,
                        label: chapter.pageText(_page),
                        child: CustomPaint(
                          size: pageSize,
                          painter: _PagePainter(chapter, _page),
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
                        const SizedBox(width: 16),
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
  _PagePainter(this.chapter, this.page);

  final ChapterLayout chapter;
  final int page;

  @override
  void paint(Canvas canvas, Size size) => chapter.paintPage(canvas, page);

  @override
  bool shouldRepaint(_PagePainter old) =>
      old.chapter != chapter || old.page != page;
}
