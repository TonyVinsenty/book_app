import 'dart:async';
import 'dart:math' as math;

import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/book/tokenizer/token.dart';
import 'package:book_app/data/book_opener.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/speed/rewind.dart';
import 'package:book_app/speed/rsvp_engine.dart';
import 'package:book_app/speed/timing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Speed reading one word at a time (RSVP, ADR 0004). Opens paused on the
/// start word with the controls shown; a tap anywhere starts (gently), the
/// next one pauses. Pops with the word it stopped on.
class RsvpScreen extends ConsumerStatefulWidget {
  const RsvpScreen({
    super.key,
    required this.opened,
    required this.startWord,
    required this.wordsPerMinute,
  });

  final OpenedBook opened;
  final int startWord;
  final int wordsPerMinute;

  @override
  ConsumerState<RsvpScreen> createState() => RsvpScreenState();
}

class RsvpScreenState extends ConsumerState<RsvpScreen>
    with SingleTickerProviderStateMixin {
  late final RsvpEngine _engine;
  late final Ticker _ticker;
  late final AppLifecycleListener _lifecycle;
  late int _wpm;

  /// The speed shown for a moment after a swipe changed it while playing.
  bool _speedHint = false;
  Timer? _hintTimer;
  Duration _lastTick = Duration.zero;

  @visibleForTesting
  RsvpEngine get engine => _engine;

  @override
  void initState() {
    super.initState();
    _wpm = SpeedLimits.clamp(widget.wordsPerMinute);
    _engine = RsvpEngine(
      wordCount: widget.opened.tokens.length,
      startWord: widget.startWord,
      timing: SmartPace(widget.opened.tokens, _wpm),
      stopBefore: (word) =>
          widget.opened.tokens.flagsOf(word) & TokenFlags.sectionStart != 0,
    );
    _ticker = createTicker(_onTick);
    _lifecycle = AppLifecycleListener(onInactive: _pause);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _lifecycle.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final changed = _engine.advance(elapsed - _lastTick);
    _lastTick = elapsed;
    if (!_engine.isPlaying) {
      _ticker.stop();
      _savePosition();
      setState(() {});
    } else if (changed) {
      setState(() {});
    }
  }

  void _play() {
    _engine.play();
    if (!_engine.isPlaying || _ticker.isActive) return;
    _lastTick = Duration.zero;
    unawaited(_ticker.start());
  }

  void _pause() {
    if (!_engine.isPlaying) return;
    _engine.pause();
    _ticker.stop();
    _savePosition();
    if (mounted) setState(() {});
  }

  /// Back to the start of the sentence (or the previous one); a playing
  /// engine goes on from there.
  void _back() {
    setState(
      () => _engine.seek(sentenceBack(widget.opened.tokens, _engine.wordIndex)),
    );
    if (!_engine.isPlaying) _savePosition();
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    if ((details.primaryVelocity ?? 0) > _swipeVelocity) _back();
  }

  void _onVerticalSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v < -_swipeVelocity && _wpm < SpeedLimits.max) {
      _changeSpeed(SpeedLimits.step);
    } else if (v > _swipeVelocity && _wpm > SpeedLimits.min) {
      _changeSpeed(-SpeedLimits.step);
    }
  }

  static const _swipeVelocity = 300.0;

  void _toggle() {
    if (_engine.isPlaying) {
      _pause();
    } else {
      setState(_play);
    }
  }

  void _changeSpeed(int delta) {
    setState(() {
      _wpm = SpeedLimits.clamp(_wpm + delta);
      _engine.timing = (_engine.timing as SmartPace).withSpeed(_wpm);
      _speedHint = _engine.isPlaying;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _speedHint = false);
    });
    unawaited(
      ref.read(settingsRepositoryProvider).set(SettingKeys.speedWpm, '$_wpm'),
    );
  }

  void _savePosition() {
    unawaited(
      ref
          .read(bookRepositoryProvider)
          .savePosition(
            widget.opened.book.id,
            widget.opened.tokens.positionOf(_engine.wordIndex),
          ),
    );
  }

  void _exit() => Navigator.of(context).pop(_engine.wordIndex);

  /// The engine paused before a new chapter: its title and "Start".
  Widget _chapterStart(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final section = widget.opened.tokens.sectionOf(_engine.wordIndex);
    final title =
        widget.opened.tokens.content.sections[section].title ??
        l10n.speedChapterNumber(section + 1);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.speedNewChapter,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.readingColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => setState(_play),
              child: Text(l10n.speedStart),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.readingColors;
    final l10n = AppLocalizations.of(context);
    final token = widget.opened.tokens[_engine.wordIndex];
    final paused = !_engine.isPlaying;
    final secondary = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: colors.textSecondary);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            onHorizontalDragEnd: _onHorizontalSwipe,
            onVerticalDragEnd: _onVerticalSwipe,
            child: Stack(
              children: [
                if (_engine.isStopped)
                  Positioned.fill(child: _chapterStart(context))
                else
                  Positioned.fill(
                    child: Semantics(
                      label: token.text,
                      child: CustomPaint(
                        painter: RsvpWordPainter(
                          text: token.text,
                          orp: token.orp,
                          style: TextStyle(
                            fontFamily: BookFont.literata.family,
                            fontSize: 36,
                            color: colors.text,
                          ),
                          textScaler: MediaQuery.textScalerOf(context),
                          orpColor: colors.orp,
                          markColor: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                if (!paused && _speedHint)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Text(
                      l10n.speedWordsPerMinute(_wpm),
                      style: secondary,
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (paused) ...[
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.speedExit,
                      onPressed: _exit,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Column(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.undo),
                          label: Text(l10n.speedBackSentence),
                          onPressed: _engine.wordIndex > 0 ? _back : null,
                        ),
                        const SizedBox(height: 8),
                        if (_engine.isFinished) ...[
                          Text(
                            l10n.speedBookEnd,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _exit,
                            child: Text(l10n.speedBackToText),
                          ),
                        ] else if (!_engine.isStopped)
                          Text(
                            l10n.speedTapToContinue,
                            style: secondary,
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.outlined(
                              icon: const Icon(Icons.remove),
                              tooltip: l10n.speedSlower,
                              onPressed: _wpm > SpeedLimits.min
                                  ? () => _changeSpeed(-SpeedLimits.step)
                                  : null,
                            ),
                            SizedBox(
                              width: 120,
                              child: Text(
                                l10n.speedWordsPerMinute(_wpm),
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton.outlined(
                              icon: const Icon(Icons.add),
                              tooltip: l10n.speedFaster,
                              onPressed: _wpm < SpeedLimits.max
                                  ? () => _changeSpeed(SpeedLimits.step)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One word with its fixation letter centred on a fixed point at 38% of the
/// width (ADR 0004 п. 3), with thin marks above and below that point.
class RsvpWordPainter extends CustomPainter {
  RsvpWordPainter({
    required this.text,
    required this.orp,
    required this.style,
    required this.textScaler,
    required this.orpColor,
    required this.markColor,
  });

  /// Where the fixation letter stands, as a share of the width.
  static const fixationX = 0.38;

  final String text;

  /// UTF-16 offset of the fixation letter in [text].
  final int orp;
  final TextStyle style;
  final TextScaler textScaler;
  final Color orpColor;
  final Color markColor;

  /// End of the fixation letter; a surrogate pair stays whole.
  int get _orpEnd {
    if (orp >= text.length) return text.length;
    final unit = text.codeUnitAt(orp);
    final pair = unit >= 0xD800 && unit < 0xDC00 && orp + 2 <= text.length;
    return orp + (pair ? 2 : 1);
  }

  TextPainter _layout(double fontSize) => TextPainter(
    text: TextSpan(
      style: style.copyWith(fontSize: fontSize),
      children: [
        TextSpan(text: text.substring(0, orp)),
        TextSpan(
          text: text.substring(orp, _orpEnd),
          style: TextStyle(color: orpColor),
        ),
        TextSpan(text: text.substring(_orpEnd)),
      ],
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;
    final fontSize = style.fontSize ?? 36;
    var painter = _layout(fontSize);
    // A word wider than the screen gets a smaller font (splitting long words
    // comes later, ADR 0004 п. 1).
    final room = size.width - 16;
    if (painter.width > room && room > 0) {
      final smaller = fontSize * room / painter.width;
      painter.dispose();
      painter = _layout(smaller);
    }
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: orp, extentOffset: _orpEnd),
    );
    final letter = boxes.isEmpty
        ? painter.width / 2
        : (boxes.first.left + boxes.first.right) / 2;
    final anchor = size.width * fixationX;
    // Only a word too wide to fit leaves the fixation point.
    final spare = size.width - painter.width;
    final left = (anchor - letter)
        .clamp(math.min(0.0, spare), math.max(0.0, spare))
        .toDouble();
    final top = (size.height - painter.height) / 2;
    painter.paint(canvas, Offset(left, top));

    final mark = Paint()
      ..color = markColor
      ..strokeWidth = 1.5;
    final gap = painter.height * 0.15;
    final length = painter.height * 0.35;
    canvas
      ..drawLine(
        Offset(anchor, top - gap - length),
        Offset(anchor, top - gap),
        mark,
      )
      ..drawLine(
        Offset(anchor, top + painter.height + gap),
        Offset(anchor, top + painter.height + gap + length),
        mark,
      );
    painter.dispose();
  }

  @override
  bool shouldRepaint(RsvpWordPainter old) =>
      old.text != text ||
      old.orp != orp ||
      old.style != style ||
      old.textScaler != textScaler ||
      old.orpColor != orpColor ||
      old.markColor != markColor;
}
