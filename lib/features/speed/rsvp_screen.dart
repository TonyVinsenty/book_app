import 'dart:async';
import 'dart:math' as math;

import 'package:book_app/app/pro.dart';
import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/page_texture.dart';
import 'package:book_app/book/tokenizer/book_tokens.dart';
import 'package:book_app/book/tokenizer/token.dart';
import 'package:book_app/data/book_opener.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/features/reader/page_images.dart';
import 'package:book_app/features/speed/speed_controls.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/speed/pause_text.dart';
import 'package:book_app/speed/phrases.dart';
import 'package:book_app/speed/rewind.dart';
import 'package:book_app/speed/rsvp_engine.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/speed/steps.dart';
import 'package:book_app/speed/timing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where speed reading stopped: the words on screen, [word]..[end], and
/// the [mode] to go on in ([SpeedMode.guide]: on the book page).
typedef RsvpExit = ({int word, int end, SpeedMode mode});

/// Speed reading one word or one phrase at a time (RSVP, ADR 0004). Opens
/// paused on the start word with the controls shown; a tap anywhere starts
/// (gently), the next one pauses. Pops with the [RsvpExit] it stopped on.
class RsvpScreen extends ConsumerStatefulWidget {
  const RsvpScreen({
    super.key,
    required this.opened,
    required this.startWord,
    required this.wordsPerMinute,
    this.mode = SpeedMode.word,
  }) : assert(mode != SpeedMode.guide);

  final OpenedBook opened;
  final int startWord;
  final int wordsPerMinute;

  /// [SpeedMode.word] or [SpeedMode.phrase] to start in; the pause panel
  /// switches them.
  final SpeedMode mode;

  @override
  ConsumerState<RsvpScreen> createState() => RsvpScreenState();
}

class RsvpScreenState extends ConsumerState<RsvpScreen>
    with SingleTickerProviderStateMixin {
  late final RsvpEngine _engine;
  late final Ticker _ticker;
  late final AppLifecycleListener _lifecycle;
  late int _wpm;
  late SpeedMode _mode = widget.mode;

  /// The phrases for the screen's width, kept while switching modes.
  PhraseSteps? _phrases;

  /// The speed shown for a moment after a swipe changed it while playing.
  bool _speedHint = false;

  /// Played at least once: the hint says "continue", not "start".
  bool _started = false;
  Timer? _hintTimer;
  Duration _lastTick = Duration.zero;

  /// Pictures of the current stop already tapped away.
  int _imagesSeen = 0;

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
          _chapterStartAt(word) ||
          widget.opened.tokens.imagesBefore(word).isNotEmpty,
    );
    _ticker = createTicker(_onTick);
    _lifecycle = AppLifecycleListener(onInactive: _pause);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Phrases as long as the screen holds (ADR 0004, addendum for stage 10
    // п. 3); a turned phone splits them anew.
    final maxChars = _phraseChars(context);
    if (_phrases?.maxChars == maxChars) return;
    _phrases = PhraseSteps(widget.opened.tokens, maxChars: maxChars);
    // While playing the new phrases wait for the next start: a switch steps
    // back to the start of a phrase.
    if (!_engine.isPlaying) _usePhrases();
  }

  void _usePhrases() {
    if (_mode == SpeedMode.phrase && _engine.steps != _phrases) {
      _engine.steps = _phrases!;
    }
  }

  /// Word ↔ phrase in place, from the current word, at the pace of the new
  /// mode; the leading highlight goes on on the book page (ADR 0004,
  /// addendum for stage 10 п. 10).
  Future<void> _switchMode(SpeedMode mode) async {
    if (mode == _mode) return;
    final settings = ref.read(speedSettingsProvider);
    unawaited(settings.setMode(mode));
    if (mode == SpeedMode.guide) {
      _exit(mode);
      return;
    }
    final wpm = await settings.wordsPerMinute(mode);
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _wpm = wpm;
      _engine
        ..timing = (_engine.timing as SmartPace).withSpeed(wpm)
        ..steps = mode == SpeedMode.phrase ? _phrases! : const WordSteps();
    });
    _savePosition();
  }

  /// Letters with spaces that fit across the screen in the word's font.
  static int _phraseChars(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final room =
        MediaQuery.sizeOf(context).width -
        padding.horizontal -
        2 * RsvpWordPainter.phraseSide;
    final painter = TextPainter(
      text: TextSpan(
        text: _sample,
        style: TextStyle(
          fontFamily: BookFont.literata.family,
          fontSize: _wordSize,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final letter = painter.width / _sample.length;
    painter.dispose();
    return (room / letter).floor().clamp(_minChars, _maxChars);
  }

  /// Common letters with spaces, for the average letter width (Cyrillic is
  /// the wider).
  static const _sample = 'в старом доме на широкой лестнице';
  static const _minChars = 12;
  static const _maxChars = 24;

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
      if (_engine.isFinished) {
        unawaited(
          ref.read(bookRepositoryProvider).markFinished(widget.opened.book.id),
        );
      }
      setState(() {});
    } else if (changed) {
      setState(() {});
    }
  }

  bool _chapterStartAt(int word) =>
      widget.opened.tokens.flagsOf(word) & TokenFlags.sectionStart != 0;

  /// On a stop: the next picture before the word not yet tapped away (ADR
  /// 0008 п. 9), shown before the chapter start if both are there.
  WordImage? get _stopImage {
    if (!_engine.isStopped) return null;
    final images = widget.opened.tokens.imagesBefore(_engine.wordIndex);
    return _imagesSeen < images.length ? images[_imagesSeen] : null;
  }

  void _play() {
    _usePhrases();
    _imagesSeen = 0;
    _engine.play();
    _started = true;
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
    } else if (_stopImage != null) {
      // A tap shows the next picture, then the chapter start or the words;
      // the time on a picture is a pause, not counted in the speed.
      setState(() {
        _imagesSeen++;
        if (_stopImage == null && !_chapterStartAt(_engine.wordIndex)) {
          _play();
        }
      });
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
    unawaited(ref.read(speedSettingsProvider).setWordsPerMinute(_mode, _wpm));
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

  void _exit([SpeedMode? mode]) => Navigator.of(context).pop<RsvpExit>((
    word: _engine.wordIndex,
    end: _engine.unitEnd,
    mode: mode ?? _mode,
  ));

  /// The word or the phrase on screen.
  String get _shownText =>
      phraseText(widget.opened.tokens, _engine.wordIndex, _engine.unitEnd);

  /// The engine paused before a new chapter: its title and "Start".
  Widget _chapterStart(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final section = widget.opened.tokens.sectionOf(_engine.wordIndex);
    final title =
        widget.opened.tokens.content.sections[section].title ??
        l10n.speedChapterNumber(widget.opened.tokens.chapterNumberOf(section));
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

  /// A picture on a stop, fitted between the exit button and the hint, no
  /// larger than its own size (as on the page).
  Widget _picture(BuildContext context, WordImage picture) {
    final colors = context.readingColors;
    final dir = ref.read(contentStoreProvider).imagesDir(widget.opened.book.id);
    final width = picture.image.width!;
    final height = picture.image.height!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 80),
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = math.min(
            1.0,
            math.min(box.maxWidth / width, box.maxHeight / height),
          );
          final size = Size(width * scale, height * scale);
          return Center(
            child: SizedBox.fromSize(
              size: size,
              child: PagePicture(
                image: (
                  assetId: picture.image.assetId,
                  rect: Offset.zero & size,
                  width: width,
                  height: height,
                ),
                imagesDir: dir,
                devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                dim: Theme.of(context).brightness == Brightness.dark,
                frameColor: colors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }

  /// The text before the word on pause, pressed down to the word line from
  /// above (ADR 0004 п. 7, «Изменения»); it ends with the word or phrase on
  /// screen, lit.
  Widget _pauseText(BuildContext context, BoxConstraints box) {
    final colors = context.readingColors;
    final tokens = widget.opened.tokens;
    final word = _engine.wordIndex;
    // Clear of the word and its marks.
    final clearance =
        RsvpWordPainter.reachAbove(
          TextStyle(fontFamily: BookFont.literata.family, fontSize: _wordSize),
          MediaQuery.textScalerOf(context),
        ) +
        16;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 56, 24, box.maxHeight / 2 + clearance),
      child: ShaderMask(
        // Long text fades out at the top instead of being cut.
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xFF000000)],
          stops: [0, 0.25],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.bottomLeft,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: BookFont.literata.family,
                  fontSize: 18,
                  height: 1.5,
                  color: colors.textSecondary,
                ),
                children: [
                  TextSpan(text: textBefore(tokens, word)),
                  TextSpan(
                    text: _shownText,
                    style: TextStyle(
                      color: colors.text,
                      backgroundColor: colors.highlight,
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

  static const _wordSize = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.readingColors;
    final l10n = AppLocalizations.of(context);
    final token = widget.opened.tokens[_engine.wordIndex];
    final phrase = _mode == SpeedMode.phrase;
    final text = phrase ? _shownText : token.text;
    final paused = !_engine.isPlaying;
    final showText = paused && !_engine.isStopped;
    final picture = _stopImage;
    final secondary = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: colors.textSecondary);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: TexturedPage(
          child: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              onHorizontalDragEnd: _onHorizontalSwipe,
              onVerticalDragEnd: _onVerticalSwipe,
              child: Stack(
                children: [
                  if (picture != null)
                    Positioned.fill(child: _picture(context, picture))
                  else if (_engine.isStopped)
                    Positioned.fill(child: _chapterStart(context))
                  else
                    Positioned.fill(
                      child: Semantics(
                        label: text,
                        child: CustomPaint(
                          painter: RsvpWordPainter(
                            text: text,
                            orp: phrase ? null : token.orp,
                            style: TextStyle(
                              fontFamily: BookFont.literata.family,
                              fontSize: _wordSize,
                              color: colors.text,
                            ),
                            textScaler: MediaQuery.textScalerOf(context),
                            orpColor: colors.orp,
                            markColor: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    // The word itself is announced by the painter above.
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: AnimatedOpacity(
                          opacity: showText ? 1 : 0,
                          duration: showText
                              ? const Duration(milliseconds: 300)
                              : Duration.zero,
                          child: showText
                              ? LayoutBuilder(builder: _pauseText)
                              : const SizedBox(),
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
                  if (paused)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: l10n.speedExit,
                        onPressed: _exit,
                      ),
                    ),
                  if (picture != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: Text(
                        l10n.speedTapToContinue,
                        style: secondary,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (paused)
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
                              _started
                                  ? l10n.speedTapToContinue
                                  : l10n.speedTapToStart,
                              style: secondary,
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 16),
                          SpeedStepper(wpm: _wpm, onChange: _changeSpeed),
                          // Without "Pro" there is only the word mode.
                          if (ref.watch(proUnlockedProvider)) ...[
                            const SizedBox(height: 12),
                            SpeedModeSwitch(
                              mode: _mode,
                              onChanged: (mode) => unawaited(_switchMode(mode)),
                            ),
                          ],
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

/// One word with its fixation letter centred on a fixed point at 38% of the
/// width (ADR 0004 п. 3), with thin marks above and below that point. A
/// phrase ([orp] is null) stands in the middle with no marked letter, the
/// marks in the middle too (ADR 0004, addendum for stage 10 п. 5).
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

  /// Room left on each side of a phrase, so it does not touch the edges.
  static const phraseSide = 32.0;

  final String text;

  /// UTF-16 offset of the fixation letter in [text]; null for a phrase.
  final int? orp;
  final TextStyle style;
  final TextScaler textScaler;
  final Color orpColor;
  final Color markColor;

  /// End of the fixation letter; a surrogate pair stays whole.
  static int _orpEnd(String text, int orp) {
    if (orp >= text.length) return text.length;
    final unit = text.codeUnitAt(orp);
    final pair = unit >= 0xD800 && unit < 0xDC00 && orp + 2 <= text.length;
    return orp + (pair ? 2 : 1);
  }

  /// Marks: gap from the word and length, as shares of its line height.
  static const _markGap = 0.15;
  static const _markLength = 0.35;

  /// How far the word and its upper mark reach above the middle line.
  static double reachAbove(TextStyle style, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ж', style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height * (0.5 + _markGap + _markLength);
  }

  TextPainter _layout(double fontSize) {
    final orp = this.orp;
    final end = orp == null ? 0 : _orpEnd(text, orp);
    return TextPainter(
      text: TextSpan(
        style: style.copyWith(fontSize: fontSize),
        text: orp == null ? text : null,
        children: orp == null
            ? null
            : [
                TextSpan(text: text.substring(0, orp)),
                TextSpan(
                  text: text.substring(orp, end),
                  style: TextStyle(color: orpColor),
                ),
                TextSpan(text: text.substring(end)),
              ],
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;
    final fontSize = style.fontSize ?? 36;
    var painter = _layout(fontSize);
    // A word or phrase wider than the screen gets a smaller font (splitting
    // long words comes later, ADR 0004 п. 1).
    final room = size.width - 2 * (this.orp == null ? phraseSide : 8);
    if (painter.width > room && room > 0) {
      final smaller = fontSize * room / painter.width;
      painter.dispose();
      painter = _layout(smaller);
    }
    final orp = this.orp;
    final double anchor;
    final double left;
    if (orp == null) {
      anchor = size.width / 2;
      left = (size.width - painter.width) / 2;
    } else {
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: orp, extentOffset: _orpEnd(text, orp)),
      );
      final letter = boxes.isEmpty
          ? painter.width / 2
          : (boxes.first.left + boxes.first.right) / 2;
      anchor = size.width * fixationX;
      // Only a word too wide to fit leaves the fixation point.
      final spare = size.width - painter.width;
      left = (anchor - letter)
          .clamp(math.min(0.0, spare), math.max(0.0, spare))
          .toDouble();
    }
    final top = (size.height - painter.height) / 2;
    painter.paint(canvas, Offset(left, top));

    final mark = Paint()
      ..color = markColor
      ..strokeWidth = 1.5;
    final gap = painter.height * _markGap;
    final length = painter.height * _markLength;
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
