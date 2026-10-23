import 'dart:io';
import 'dart:math';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/features/reader/page_images.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A picture of the book over the whole screen (ADR 0008 п. 7, owner's
/// answer 2): zoom by fingers or a double tap; a tap, a swipe down, the
/// close button or back closes it. On the theme's background (14.2, A4).
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.file,
    required this.width,
    required this.height,
    required this.dim,
  });

  final File file;

  /// The picture's own size, in pixels.
  final int width;
  final int height;

  /// Night theme: darken a little, as on the page.
  final bool dim;

  /// Opens the viewer with a short fade.
  static Future<void> open(
    BuildContext context, {
    required File file,
    required int width,
    required int height,
    required bool dim,
  }) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          ImageViewerScreen(file: file, width: width, height: height, dim: dim),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

/// Decoded no larger on the long side: sharp enough to zoom, and a huge
/// picture does not take all the memory (ADR 0008 п. 7).
const _decodeLimit = 4096;

/// The double tap zoom.
const _doubleTapScale = 2.5;

/// Zoomed by fingers at most this much.
const _maxScale = 5.0;

/// A swipe down this long (or this fast) closes the viewer.
const _closeDistance = 120.0;
const _closeSpeed = 700.0;

class _ImageViewerScreenState extends State<ImageViewerScreen>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(_onSettle);
  Animation<Matrix4>? _zoom;
  Animation<double>? _dragBack;
  Offset _doubleTapAt = Offset.zero;

  /// The picture pulled down by a swipe while not zoomed.
  double _drag = 0;
  bool _dragging = false;

  bool get _zoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _settle.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _onSettle() {
    final zoom = _zoom;
    final back = _dragBack;
    if (zoom != null) _transform.value = zoom.value;
    if (back != null) setState(() => _drag = back.value);
  }

  void _animate({Matrix4? zoom, bool dragBack = false}) {
    final curve = CurvedAnimation(parent: _settle, curve: Curves.easeOut);
    _zoom = zoom == null
        ? null
        : Matrix4Tween(begin: _transform.value, end: zoom).animate(curve);
    _dragBack = dragBack
        ? Tween<double>(begin: _drag, end: 0).animate(curve)
        : null;
    _settle.forward(from: 0);
  }

  /// Zooms in at the tapped point, or back out if zoomed.
  void _onDoubleTap() {
    if (_zoomed) return _animate(zoom: Matrix4.identity());
    final at = _doubleTapAt;
    _animate(
      zoom: Matrix4.identity()
        ..translateByDouble(
          -at.dx * (_doubleTapScale - 1),
          -at.dy * (_doubleTapScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1),
    );
  }

  void _onInteractionStart(ScaleStartDetails details) {
    _dragging = details.pointerCount == 1 && !_zoomed;
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    if (!_dragging) return;
    if (details.pointerCount > 1) {
      // A second finger: a pinch, not a swipe.
      _dragging = false;
      return _animate(dragBack: true);
    }
    setState(() => _drag = max(0, _drag + details.focalPointDelta.dy));
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    if (_drag > _closeDistance ||
        details.velocity.pixelsPerSecond.dy > _closeSpeed) {
      Navigator.of(context).pop();
    } else {
      _animate(dragBack: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fade = (1 - _drag / (_closeDistance * 3)).clamp(0.3, 1.0);
    final close = Navigator.of(context).pop;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Stack(
        children: [
          ColoredBox(
          color: colors.background.withValues(alpha: fade),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: close,
            onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
            onDoubleTap: _onDoubleTap,
            child: Transform.translate(
              offset: Offset(0, _drag),
              child: InteractiveViewer(
                transformationController: _transform,
                maxScale: _maxScale,
                onInteractionStart: _onInteractionStart,
                onInteractionUpdate: _onInteractionUpdate,
                onInteractionEnd: _onInteractionEnd,
                child: SizedBox.expand(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image(
                    image: ResizeImage(
                      FileImage(widget.file),
                      width: min(widget.width, _decodeLimit),
                      height: min(widget.height, _decodeLimit),
                      policy: ResizeImagePolicy.fit,
                    ),
                    fit: BoxFit.contain,
                    color: widget.dim ? nightImageDim : null,
                    colorBlendMode: widget.dim ? BlendMode.srcATop : null,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colors.textSecondary,
                        size: 48,
                      ),
                    ),
                  ),
                  ),
                ),
              ),
            ),
          ),
        ),
          // A round button: closing by a tap is not seen (14.2, A4).
          Positioned(
            left: 8,
            top: MediaQuery.paddingOf(context).top + 8,
            child: Opacity(
              opacity: fade,
              child: Material(
                color: colors.surface.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: close,
                  tooltip: l10n.readerImageClose,
                  icon: Icon(Icons.close, color: colors.text),
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
