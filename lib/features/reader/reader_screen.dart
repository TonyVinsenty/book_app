import 'dart:async';
import 'dart:math';

import 'package:book_app/app/notice.dart';
import 'package:book_app/app/pro.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/page_texture.dart';
import 'package:book_app/book/model/table_of_contents.dart';
import 'package:book_app/data/book_opener.dart';
import 'package:book_app/data/book_pages.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/features/reader/contents_screen.dart';
import 'package:book_app/features/reader/font_size_button.dart';
import 'package:book_app/features/reader/settings_panel.dart';
import 'package:book_app/features/speed/rsvp_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/layout/book_pagination.dart';
import 'package:book_app/layout/chapter_layout.dart';
import 'package:book_app/layout/page_cache.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:book_app/platform/screen_channel.dart';
import 'package:book_app/platform/system_bars.dart';
import 'package:book_app/speed/speed_mode.dart';
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
        showNotice(context, l10n.readerReopenFailed);
        Navigator.of(context).pop();
      });
    }
    final opened = ref.watch(openedBookProvider(bookId));
    return PopScope(
      // The library offers to go back to a book that opened.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && opened.hasValue) {
          ref.read(leftBookProvider.notifier).set(bookId);
        }
      },
      child: Scaffold(
        backgroundColor: context.readingColors.background,
        body: TexturedPage(
          child: switch (opened) {
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
        ),
      ),
    );
  }
}

/// Pages of an opened book. Taps on the left and right thirds turn pages,
/// the middle shows the panels over the page (and the status bar), any tap
/// hides them; swipes turn pages too. A long press on a word starts speed
/// reading from it.
class ReaderView extends ConsumerStatefulWidget {
  const ReaderView({super.key, required this.opened});

  final OpenedBook opened;

  @override
  ConsumerState<ReaderView> createState() => ReaderViewState();
}

class ReaderViewState extends ConsumerState<ReaderView>
    with SingleTickerProviderStateMixin {
  /// Page margins from the reading settings (the bottom one is the footer).
  EdgeInsets _margin = EdgeInsets.zero;

  /// Chapters laid out for the current page size and style.
  final _layouts = <int, ChapterLayout>{};
  Size? _pageSize;
  PageStyle? _style;

  /// Pages of the whole book for this page size and layout, and their
  /// saved copies.
  BookPagination? _pagination;
  late final PageCache _pageCache = PageCache(
    ref.read(contentStoreProvider).pagesDir(widget.opened.book.id),
  );

  /// Saves the pages when the app goes to the background (it may be closed
  /// there without [dispose]).
  late final AppLifecycleListener _lifecycle;

  /// The word whose line goes where speed reading showed it, on the next
  /// build (it knows the screen size then).
  int? _shiftTo;

  late int _section;
  int _page = 0;

  /// The book has been read on here ([_readOn]).
  bool _readingOn = false;

  /// The last [_saveLastLayout] write: the next one waits for it.
  Future<void> _layoutSaved = Future.value();

  /// The book page (from 1) the slider is being dragged to.
  double? _dragPage;

  /// The place before the first slider jump and its page number, offered
  /// back until the page is changed some other way.
  ({int section, int word, String page})? _returnTo;

  /// The table of contents (or the chapters of a book without one).
  late final List<ContentsLine> _contents = contentsOf(
    widget.opened.tokens.content,
  );

  /// The word the current page is kept on when the layout changes.
  late int _word;
  bool _panelsShown = false;

  /// The settings panel replaces the panels (the status bar stays).
  bool _settingsShown = false;

  /// The largest top inset seen at this screen size: the status bar comes
  /// and goes with the panels, and the page must not move (ADR 0003,
  /// addendum 2 п. 3).
  double _topInset = 0;
  Size? _screenSize;

  /// The words speed reading stopped on, [_litWord]..[_litEnd]: lit for
  /// about a second, then fade (ADR 0004 п. 10).
  int? _litWord;
  int _litEnd = 0;
  late final AnimationController _lit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Kept from [initState]: `ref` is not usable in [dispose].
  late final KeepScreenOn _keepScreenOn;
  late final ShowStatusBar _showStatusBar;

  @visibleForTesting
  ChapterLayout get layout => _layoutOf(_section);

  @visibleForTesting
  ChapterPage get page => layout.pages[_page];

  @visibleForTesting
  BookPagination get pagination => _pagination!;

  @visibleForTesting
  int? get litWord => _litWord;

  @visibleForTesting
  int get litEnd => _litEnd;

  @visibleForTesting
  bool get panelsShown => _panelsShown;

  @visibleForTesting
  bool get settingsShown => _settingsShown;

  @override
  void initState() {
    super.initState();
    final tokens = widget.opened.tokens;
    _word = widget.opened.wordIndex;
    _section = tokens.isEmpty ? 0 : tokens[_word].sectionIndex;
    unawaited(
      ref.read(bookRepositoryProvider).markOpened(widget.opened.book.id),
    );
    // The screen stays on while the book is open, speed reading included.
    _keepScreenOn = ref.read(keepScreenOnProvider);
    unawaited(_keepScreenOn(true));
    _showStatusBar = ref.read(showStatusBarProvider);
    unawaited(_showStatusBar(false));
    _lifecycle = AppLifecycleListener(onHide: () => _pagination?.flush());
  }

  @override
  void dispose() {
    unawaited(_keepScreenOn(false));
    unawaited(_showStatusBar(true));
    _lit.dispose();
    _lifecycle.dispose();
    _clearLayouts();
    _pagination?.dispose();
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
    final layout = ChapterLayout.build(
      tokens: widget.opened.tokens,
      sectionIndex: section,
      style: _style!,
      pageSize: _pageSize!,
    );
    _pagination!.addChapter(section, [
      for (final page in layout.pages) page.firstWord,
    ]);
    return _layouts[section] = layout;
  }

  /// New page size or style: lay out again and find the same word. The
  /// book is split again only if the pages change (not for a new color).
  void _relayoutIfNeeded(Size pageSize, PageStyle style) {
    if (pageSize == _pageSize && style == _style) return;
    _clearLayouts();
    if (pageSize != _pageSize || !(_style?.sameLayoutAs(style) ?? false)) {
      _pagination?.dispose();
      final tokens = widget.opened.tokens;
      final key = layoutKeyOf(
        style: style,
        pageSize: pageSize,
        parserVersion: widget.opened.book.parserVersion,
      );
      _pagination = BookPagination(
        tokens: tokens,
        style: style,
        pageSize: pageSize,
        cached: _pageCache.load(
          key,
          sections: tokens.content.sections.length,
          words: tokens.length,
        ),
        save: (chapters) => _pageCache.save(key, chapters),
      )..addListener(_onPagination);
      unawaited(_saveLastLayout(_pagination!, pageSize, style));
    }
    _pageSize = pageSize;
    _style = style;
    _page = _layoutOf(_section).pageOfWord(_word);
  }

  void _onPagination() {
    final pagination = _pagination!;
    if (pagination.isComplete) {
      final (pageSize, style) = (_pageSize!, _style!);
      _layoutSaved = _layoutSaved.then(
        (_) => _saveLastLayout(pagination, pageSize, style),
      );
      unawaited(_layoutSaved);
    }
    if (mounted) setState(() {});
  }

  /// Remembers this page and look for the book page (ADR 0005, addendum
  /// 3), with the words per page once the book is split to the end.
  Future<void> _saveLastLayout(
    BookPagination pagination,
    Size pageSize,
    PageStyle style,
  ) async {
    final settings = ref.read(settingsRepositoryProvider);
    final pages = pagination.pageCount.value;
    final layout = LastLayout.update(
      LastLayout.decode(await settings.get(SettingKeys.readerLastLayout)),
      pageSize: pageSize,
      styleKey: styleKeyOf(style: style, pageSize: pageSize),
      // A short book is mostly half-empty chapter ends: no measure.
      wordsPerPage: pagination.isComplete && pages >= minPagesForDensity
          ? widget.opened.tokens.length / pages
          : null,
    );
    await settings.set(SettingKeys.readerLastLayout, layout.encode());
  }

  /// "Queued" / "abandoned" go away once the book is read on: a page
  /// turned, a jump, speed reading — not opening or a new layout (ADR 0005,
  /// addendum 3).
  void _readOn() {
    if (_readingOn) return;
    _readingOn = true;
    unawaited(
      ref.read(bookRepositoryProvider).clearStatusMark(widget.opened.book.id),
    );
  }

  void _next() {
    final sections = widget.opened.tokens.content.sections.length;
    if (_page + 1 < layout.pages.length) {
      return _show(_section, _page + 1, turned: true);
    }
    for (var s = _section + 1; s < sections; s++) {
      if (_layoutOf(s).pages.isNotEmpty) return _show(s, 0, turned: true);
    }
  }

  void _previous() {
    if (_page > 0) return _show(_section, _page - 1);
    for (var s = _section - 1; s >= 0; s--) {
      final pages = _layoutOf(s).pages;
      if (pages.isNotEmpty) return _show(s, pages.length - 1);
    }
  }

  /// [turned]: reached by turning the page forward, not by a jump.
  void _show(
    int section,
    int pageIndex, {
    bool keepReturn = false,
    bool turned = false,
  }) {
    final shown = _layoutOf(section).pages[pageIndex];
    _readOn();
    _leaveSection(section);
    setState(() {
      _section = section;
      _page = pageIndex;
      _word = shown.firstWord;
      if (!keepReturn) _returnTo = null;
    });
    if (!shown.hasWords) return;
    final books = ref.read(bookRepositoryProvider);
    final id = widget.opened.book.id;
    unawaited(
      books.savePosition(id, widget.opened.tokens.positionOf(shown.firstWord)),
    );
    // The last word of the book is on screen after a page turn: read (ADR
    // 0005, addendum 2). A slider or contents jump is only a look.
    if (turned && shown.endWord >= widget.opened.tokens.length) {
      unawaited(books.markFinished(id));
    }
  }

  /// The first page with words from [section] on (ADR 0003, addendum 2
  /// п. 4: the table of contents moves the place).
  void _goToSection(int section) {
    final sections = widget.opened.tokens.content.sections.length;
    for (var s = section; s < sections; s++) {
      if (_layoutOf(s).pages.isNotEmpty) {
        _setPanels(false);
        return _show(s, 0);
      }
    }
  }

  Future<void> _openContents() async {
    final pagination = _pagination!;
    final section = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ContentsScreen(
          lines: _contents,
          current: currentLineOf(_contents, _section),
          fontFamily: _style?.fontFamily,
          chapterStarts: () => pagination.chapterStarts,
          chapterNumberOf: widget.opened.tokens.chapterNumberOf,
          pageUpdates: pagination,
        ),
      ),
    );
    if (mounted && section != null) _goToSection(section);
  }

  /// Opens book page [number] (from 1) picked with the slider; the place
  /// before the first such jump can be returned to.
  void _jumpToBookPage(int number) {
    final at = _pagination!.locate(number - 1);
    final returnTo =
        _returnTo ??
        (
          section: _section,
          word: _word,
          page: _pageNumbers(AppLocalizations.of(context)).page,
        );
    final sections = widget.opened.tokens.content.sections.length;
    for (var s = at.section; s < sections; s++) {
      final pages = _layoutOf(s).pages.length;
      if (pages == 0) continue;
      // A chapter not split yet: the same share of its real pages.
      final page = s == at.section
          ? min(at.page * pages ~/ at.of, pages - 1)
          : 0;
      if (s == _section && page == _page && _returnTo == null) return;
      _show(s, page, keepReturn: true);
      setState(() => _returnTo = returnTo);
      return;
    }
  }

  /// Pages after this one up to the chapter's end, with the parts of a
  /// long chapter after this one.
  PageNumber _pagesLeftInChapter(ChapterLayout chapter) {
    final left = chapter.pages.length - _page - 1;
    final sections = widget.opened.tokens.content.sections;
    var end = _section + 1;
    while (end < sections.length && sections[end].continued) {
      end++;
    }
    final pagination = _pagination;
    if (end == _section + 1 || pagination == null) {
      return (value: left, exact: true);
    }
    final after = pagination.pagesBefore(end);
    return (
      value: left + after.value - pagination.pagesBefore(_section + 1).value,
      exact: after.exact,
    );
  }

  /// Back to the page read before the slider jumps.
  void _returnBack() {
    // The section is kept with the word: a page without words has the next
    // chapter's first word, or none at the book's end.
    final (:section, :word, page: _) = _returnTo!;
    _show(section, _layoutOf(section).pageOfWord(word));
  }

  Future<void> _onLongPress(LongPressStartDetails details) async {
    final word = layout.wordAt(_page, details.localPosition - _margin.topLeft);
    if (word == null) return;
    unawaited(HapticFeedback.selectionClick());
    await _speedRead(word);
  }

  /// Speed reading from [word]; back on the page of the last word shown.
  Future<void> _speedRead(int word) async {
    _setPanels(false);
    _readOn();
    final settings = ref.read(speedSettingsProvider);
    var mode = await settings.mode(pro: ref.read(proUnlockedProvider));
    // The leading highlight comes in a later step (stage 10).
    if (mode == SpeedMode.guide) mode = SpeedMode.word;
    final wpm = await settings.wordsPerMinute(mode);
    if (!mounted) return;
    final last = await Navigator.of(context).push<RsvpExit>(
      MaterialPageRoute(
        builder: (_) => RsvpScreen(
          opened: widget.opened,
          startWord: word,
          wordsPerMinute: wpm,
          mode: mode,
        ),
      ),
    );
    // Switched to the leading highlight: for now the page of the word
    // (the highlight itself comes in a later step of stage 10).
    if (mounted && last != null) _showWord(last.word, last.end);
  }

  /// The current chapter goes back to the normal split when the reader
  /// moves to [section] (ADR 0003, addendum 1).
  void _leaveSection(int section) {
    final current = _layouts[_section];
    if (section != _section && current != null) {
      _layouts[_section] = current.unshifted();
    }
  }

  /// Opens the page with [word], its line where speed reading showed it,
  /// lights it with the rest of its phrase (up to [end]) and keeps the place
  /// on it.
  void _showWord(int word, int end) {
    final section = widget.opened.tokens[word].sectionIndex;
    _leaveSection(section);
    setState(() {
      _section = section;
      _shiftTo = word;
      _word = word;
      _litWord = word;
      _litEnd = end;
      _returnTo = null;
    });
    _setPanels(false);
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

  /// Shifts the chapter so that the line of [_shiftTo] is [centerY] down
  /// the safe area, where the word was in speed reading.
  void _applyShift(double centerY) {
    final word = _shiftTo;
    if (word == null) return;
    _shiftTo = null;
    final shifted = _layoutOf(_section)
        .shifted(word: word, lineCenterY: centerY - _margin.top);
    _layouts[_section] = shifted;
    _page = shifted.pageOfWord(word);
  }

  /// The panels and the status bar come and go together.
  void _setPanels(bool shown) {
    if (shown == _panelsShown) return;
    setState(() {
      _panelsShown = shown;
      _settingsShown = false;
    });
    unawaited(_showStatusBar(shown));
  }

  void _onTapUp(TapUpDetails details, double width) {
    final x = details.localPosition.dx;
    if (_panelsShown) {
      _setPanels(false);
    } else if (x < width / 3) {
      _previous();
    } else if (x > width * 2 / 3) {
      _next();
    } else {
      _setPanels(true);
    }
  }

  /// A− / A+: the page stays on [_word] (ADR 0003, addendum 2 п. 4).
  void _changeFontSize({required bool larger}) {
    final scale = MediaQuery.textScalerOf(context);
    final settings = ref.read(readingSettingsProvider);
    ref
        .read(readingSettingsProvider.notifier)
        .set(larger ? settings.larger(scale) : settings.smaller(scale));
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
    final settings = ref.watch(readingSettingsProvider);
    // The system text scale only picks the default size (ADR 0003,
    // addendum 2 п. 2); the text itself is not scaled again.
    final style = pageStyleOf(
      settings,
      system: MediaQuery.textScalerOf(context),
      color: colors.text,
      hyphenation: ref.watch(hyphenationProvider),
    );
    final side = settings.margins.side;
    _margin = EdgeInsets.fromLTRB(side, readerTopMargin, side, 0);
    final screenSize = MediaQuery.sizeOf(context);
    if (screenSize != _screenSize) {
      _screenSize = screenSize;
      _topInset = 0;
    }
    final viewPadding = MediaQuery.viewPaddingOf(context);
    _topInset = max(_topInset, viewPadding.top);
    final insets = viewPadding.copyWith(top: _topInset);
    final secondary = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: colors.textSecondary);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      // Back closes the panels first.
      canPop: !_panelsShown,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setPanels(false);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final area = insets.deflateSize(constraints.biggest);
            final pageSize = readerPageOf(area, side);
            _relayoutIfNeeded(pageSize, style);
            // Speed reading shows the word in the middle of a plain safe
            // area: without the status bar, unlike the page's [insets].
            final padding = MediaQuery.paddingOf(context);
            final wordY =
                padding.top +
                (constraints.maxHeight - padding.vertical) / 2 -
                insets.top;
            _applyShift(wordY);
            final chapter = layout;
            final numbers = _pageNumbers(l10n);
            final pageLabel = l10n.readerPageOfBook(
              numbers.page,
              numbers.total,
            );
            return Stack(
              children: [
                Padding(
                  padding: insets,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _onTapUp(d, area.width),
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
                                lit: [
                                  if (_litWord case final lit?)
                                    for (var w = lit; w < _litEnd; w++)
                                      ...chapter.wordBoxes(_page, w),
                                ],
                                litColor: colors.highlight,
                                litAnimation: _lit,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: readerFooterHeight,
                            child: Center(
                              child: Text(pageLabel, style: secondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_settingsShown)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ReadingSettingsPanel(insets: insets),
                  )
                else if (_panelsShown) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _topPanel(context, insets),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _bottomPanel(
                      context,
                      insets,
                      pageLabel: pageLabel,
                      pagesLeft: _pagesLeftInChapter(chapter),
                      fontSize: style.fontSize,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// The page across the book and the pages in it, for «стр. N / M»;
  /// «≈» marks a number not known exactly yet (chapters still being split,
  /// or a shifted page).
  ({String page, String total}) _pageNumbers(AppLocalizations l10n) {
    final pagination = _pagination!;
    final before = pagination.pagesBefore(_section);
    final total = pagination.pageCount;
    final page = before.value + _page + 1;
    return (
      page: _number(l10n, page, exact: before.exact && !layout.isShifted),
      total: _number(l10n, max(total.value, page), exact: total.exact),
    );
  }

  static String _number(
    AppLocalizations l10n,
    int value, {
    required bool exact,
  }) => exact ? '$value' : l10n.readerApproxNumber(value);

  /// «Библиотека» on the left; the table of contents and speed reading on
  /// the right.
  Widget _topPanel(BuildContext context, EdgeInsets insets) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: context.readingColors.surface,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          insets.left + 4,
          insets.top,
          insets.right + 8,
          0,
        ),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.readerLibrary),
                // Not `maybePop`: the open panels hold back the pop.
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.toc),
                tooltip: l10n.readerContents,
                onPressed: _openContents,
              ),
              TextButton.icon(
                icon: const Icon(Icons.speed),
                label: Text(l10n.readerSpeedRead),
                onPressed: () => _speedRead(page.firstWord),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chapter title, page, pages left in the chapter, A− / A+, settings.
  Widget _bottomPanel(
    BuildContext context,
    EdgeInsets insets, {
    required String pageLabel,
    required PageNumber pagesLeft,
    required double fontSize,
  }) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final text = Theme.of(context).textTheme;
    final pagination = _pagination!;
    final total = pagination.pageCount;
    final current = pagination.pagesBefore(_section).value + _page + 1;
    final last = max(total.value, current);
    // While the slider is dragged: the page and chapter it would open.
    final drag = _dragPage?.round();
    final section = drag == null
        ? _section
        : pagination.locate(drag - 1).section;
    final line = switch (currentLineOf(_contents, section)) {
      final i? => _contents[i],
      null => null,
    };
    final title =
        line?.title ??
        widget.opened.tokens.content.sections[section].title ??
        l10n.readerChapterNumber(widget.opened.tokens.chapterNumberOf(section));
    String dragLabel(int page) => l10n.readerPageOfBook(
      _number(l10n, page, exact: pagination.locate(page - 1).exact),
      _number(l10n, last, exact: total.exact),
    );
    final returnTo = _returnTo;
    const sizes = ReadingSettings.fontSizes;
    return Material(
      color: colors.surface,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          insets.left + 16,
          12,
          insets.right + 16,
          insets.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Above the rest: the panel grows up and the slider stays put.
            if (returnTo != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  icon: const Icon(Icons.undo),
                  label: Text(l10n.readerReturnToPage(returnTo.page)),
                  onPressed: _returnBack,
                ),
              ),
            Text(
              title,
              style: text.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              drag == null
                  ? l10n.readerPageAndChapterLeft(
                      pageLabel,
                      pagesLeft.exact
                          ? l10n.readerPagesLeftInChapter(pagesLeft.value)
                          : l10n.readerPagesLeftInChapterApprox(
                              pagesLeft.value,
                            ),
                    )
                  : dragLabel(drag),
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            if (last > 1)
              Semantics(
                label: l10n.readerBookPages,
                child: Slider(
                  value: (_dragPage ?? current.toDouble()).clamp(
                    1,
                    last.toDouble(),
                  ),
                  min: 1,
                  max: last.toDouble(),
                  activeColor: colors.accent,
                  inactiveColor: colors.textSecondary.withValues(alpha: 0.3),
                  semanticFormatterCallback: (v) => dragLabel(v.round()),
                  onChangeStart: (v) => setState(() => _dragPage = v),
                  onChanged: (v) => setState(() => _dragPage = v),
                  onChangeEnd: (v) {
                    setState(() => _dragPage = null);
                    _jumpToBookPage(v.round());
                  },
                ),
              )
            else
              const SizedBox(height: 8),
            Row(
              children: [
                FontSizeButton(
                  larger: false,
                  onPressed: fontSize > sizes.first
                      ? () => _changeFontSize(larger: false)
                      : null,
                ),
                const SizedBox(width: 8),
                FontSizeButton(
                  larger: true,
                  onPressed: fontSize < sizes.last
                      ? () => _changeFontSize(larger: true)
                      : null,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.readerSettings),
                  onPressed: () => setState(() => _settingsShown = true),
                ),
              ],
            ),
          ],
        ),
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

  /// Boxes of the lit words on this page.
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
