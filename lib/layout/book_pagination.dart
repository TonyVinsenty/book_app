import 'dart:async';
import 'dart:math' as math;

import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/layout/chapter_layout.dart';
import 'package:book_app/layout/page_cache.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// Runs [task] later, for tests (see [BookPagination.new]).
typedef IdleScheduler = void Function(VoidCallback task);

/// A number that may be an estimate.
typedef PageNumber = ({int value, bool exact});

/// Pages of the whole book for one layout (ADR 0003, addendum 2 п. 5–6):
/// chapters are split one after another in short portions while the main
/// isolate is idle; chapters not split yet are estimated by their length.
/// Listeners hear of progress now and then and when the book is done.
///
/// A split saved before ([cached], п. 7–8) is taken as is and only the
/// chapters missing from it are split; new results go to [save] now and
/// then, when the book is done and on [dispose].
class BookPagination extends ChangeNotifier {
  BookPagination({
    required this._tokens,
    required this._style,
    required this._pageSize,
    this._schedule,
    this.budget = const Duration(milliseconds: 6),
    ChapterPages? cached,
    this._save,
  }) : _chars = [
         for (final section in _tokens.content.sections)
           section.blocks.fold(
             0,
             (sum, b) => sum + (b is TextBlock ? b.text.length : 0),
           ),
       ] {
    _firstWords = List.filled(_chars.length, null);
    _left = _chars.length;
    if (cached != null) _restore(cached);
    if (!isComplete) _scheduleNext();
  }

  /// Saves at most this often while the book is being split.
  static const saveEvery = Duration(seconds: 5);

  /// A layout left sooner (A+ A+ A+) is not saved unless it is done, so
  /// passing sizes do not push the useful splits out of the cache.
  static const keepAfter = Duration(seconds: 2);

  final BookTokens _tokens;
  final PageStyle _style;
  final Size _pageSize;

  /// Null: when the main isolate is idle ([_scheduleIdle]).
  final IdleScheduler? _schedule;
  Timer? _timer;

  /// Work per portion: short enough not to drop a frame.
  final Duration budget;

  /// Text length of each chapter, for the estimates.
  final List<int> _chars;

  /// First words of each chapter's pages; null until it is split.
  late final List<List<int>?> _firstWords;
  late int _left;
  int _splitChars = 0;
  int _splitPages = 0;

  ChapterPaginator? _current;
  int _nextSection = 0;
  bool _disposed = false;
  final _sinceNotified = Stopwatch()..start();
  final _total = Stopwatch()..start();

  final void Function(ChapterPages chapters)? _save;
  final _sinceSaved = Stopwatch()..start();

  /// Chapters split (or corrected) since the last save.
  bool _unsaved = false;

  bool get isComplete => _left == 0;

  /// First words of the pages of [section], or null if not split yet.
  List<int>? chapterPages(int section) => _firstWords[section];

  /// A chapter the reader has laid out anyway (normal split, this layout):
  /// it is not split again, and a saved split that differs is replaced
  /// (п. 8). Listeners are not told (the reader may be building).
  void addChapter(int section, List<int> pageFirstWords) {
    final known = _firstWords[section];
    if (known == null) {
      _done(section, pageFirstWords);
      if (_current?.sectionIndex == section) _current = null;
    } else if (!listEquals(known, pageFirstWords)) {
      _splitPages += pageFirstWords.length - known.length;
      _firstWords[section] = pageFirstWords;
      _unsaved = true;
    }
  }

  void _restore(ChapterPages cached) {
    if (cached.length != _chars.length) return;
    for (var s = 0; s < cached.length; s++) {
      if (cached[s] case final pages?) _done(s, pages);
    }
    // Nothing new to save yet.
    _unsaved = false;
  }

  /// Pages in the book.
  PageNumber get pageCount =>
      (value: _pagesUpTo(_chars.length), exact: isComplete);

  /// Pages of the chapters before [section].
  PageNumber pagesBefore(int section) => (
    value: _pagesUpTo(section),
    exact: [for (var s = 0; s < section; s++) _firstWords[s]]
        .every((p) => p != null),
  );

  int _pagesUpTo(int section) {
    var pages = 0;
    for (var s = 0; s < section; s++) {
      pages += _firstWords[s]?.length ?? _estimate(s);
    }
    return pages;
  }

  /// Pages of a chapter not split yet: its length at the density of the
  /// chapters split so far (or a rough guess from the page size).
  int _estimate(int section) {
    final chars = _chars[section];
    if (chars == 0) return 0;
    final double charsPerPage;
    if (_splitChars > 0 && _splitPages > 0) {
      charsPerPage = _splitChars / _splitPages;
    } else {
      final em = _style.textScaler.scale(_style.fontSize);
      final perLine = _pageSize.width / (em * 0.5);
      charsPerPage = perLine * (_pageSize.height / _style.bodyLine);
    }
    return math.max(1, (chars / math.max(charsPerPage, 1)).round());
  }

  void _done(int section, List<int> pageFirstWords) {
    _firstWords[section] = pageFirstWords;
    _left--;
    _splitChars += _chars[section];
    _splitPages += pageFirstWords.length;
    _unsaved = true;
  }

  void _work() {
    if (_disposed || isComplete) return;
    final watch = Stopwatch()..start();
    // At least one block per portion, whatever the budget.
    do {
      final paginator = _current ??= _nextPaginator();
      if (paginator == null) break;
      if (paginator.step(budget - watch.elapsed)) {
        _current = null;
        _done(paginator.sectionIndex, paginator.pageFirstWords);
      }
    } while (!isComplete && watch.elapsed < budget);
    if (isComplete && kDebugMode) {
      debugPrint(
        'BookPagination: ${_chars.length} chapters, '
        '${pageCount.value} pages in ${_total.elapsedMilliseconds} ms',
      );
    }
    _notify(force: isComplete);
    if (isComplete || _sinceSaved.elapsed >= saveEvery) flush();
    if (!isComplete) _scheduleNext();
  }

  /// Saves the chapters split so far, if any are new.
  void flush() {
    final save = _save;
    if (save == null || !_unsaved) return;
    _unsaved = false;
    _sinceSaved.reset();
    save(List.unmodifiable(_firstWords));
  }

  void _scheduleNext() {
    if (_schedule case final schedule?) return schedule(_work);
    _scheduleIdle();
  }

  /// Not `scheduleTask(…, Priority.idle)`: while an animation runs, it asks
  /// the event loop again at once, without a pause. Here an animation (page
  /// transition, speed reading) puts the work off until a frame has ended.
  void _scheduleIdle() {
    _timer = Timer(Duration.zero, () {
      if (_disposed) return;
      final binding = SchedulerBinding.instance;
      if (binding.transientCallbackCount > 0) {
        binding.addPostFrameCallback((_) {
          if (!_disposed) _scheduleIdle();
        });
      } else {
        _work();
      }
    });
  }

  ChapterPaginator? _nextPaginator() {
    while (_nextSection < _chars.length && _firstWords[_nextSection] != null) {
      _nextSection++;
    }
    if (_nextSection == _chars.length) return null;
    return ChapterPaginator(
      tokens: _tokens,
      sectionIndex: _nextSection,
      style: _style,
      pageSize: _pageSize,
    );
  }

  /// Not on every chapter: a book of hundreds of short chapters would
  /// rebuild the reader all the time.
  void _notify({bool force = false}) {
    if (!force && _sinceNotified.elapsedMilliseconds < 300) return;
    _sinceNotified.reset();
    notifyListeners();
  }

  /// Saves (unless left at once) and stops the work; a portion already
  /// scheduled does nothing.
  @override
  void dispose() {
    if (isComplete || _total.elapsed >= keepAfter) flush();
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
