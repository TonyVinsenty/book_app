import 'package:flutter/material.dart';

/// Size of the box the launch book is drawn in, the same as the system
/// launch screen draws it (`tool/icons/build_icons.py`, `SPLASH_BOX`), so
/// the picture does not jump when the app takes over.
const launchBookBox = 176.0;

/// Away this long, the app shows the launch animation again on return.
const splashAfterAway = Duration(hours: 1);

/// The launch animation over the app (owner, after 0.1.0+15): the book of
/// the system launch screen, the red dot flies out of it, then everything
/// fades and the app is seen. On start and on a return after
/// [splashAfterAway] in the background.
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({super.key, required this.child, this.clock});

  final Widget child;

  /// Current time, for tests.
  final DateTime Function()? clock;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1000);

  late final _controller = AnimationController(vsync: this, duration: _duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) setState(() => _shown = false);
    });
  late final AppLifecycleListener _lifecycle;
  var _shown = true;
  DateTime? _hiddenAt;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = _now(),
      onShow: _returned,
    );
    _controller.forward();
  }

  void _returned() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || _now().difference(hiddenAt) < splashAfterAway) {
      return;
    }
    setState(() => _shown = true);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final night = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final still = MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_shown)
          ExcludeSemantics(
            child: AbsorbPointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value;
                  return Opacity(
                    opacity: 1 - _fade.transform(t),
                    child: ColoredBox(
                      color: night ? _night.background : _day.background,
                      child: Center(
                        child: CustomPaint(
                          size: const Size.square(launchBookBox),
                          painter: _BookPainter(
                            colors: night ? _night : _day,
                            rise: still ? 1 : _rise.transform(t),
                            grow: still ? 1 : 1 + 0.06 * _fade.transform(t),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  /// 0–200 ms the book alone, as on the system screen (Android fades its
  /// screen out meanwhile); the dot flies out till 550 ms; it stays a
  /// moment, then all fades from 700 ms (owner: one second in all).
  static const _rise = Interval(0.2, 0.55, curve: Curves.easeOutBack);
  static const _fade = Interval(0.7, 1, curve: Curves.easeInOut);
}

/// Colors of the launch book, as in `tool/icons/build_icons.py` (`SPLASH`):
/// the page of «Бумага», day and night.
typedef _SplashColors = ({
  Color background,
  Color cover,
  Color left,
  Color right,
  Color dot,
});

const _SplashColors _day = (
  background: Color(0xFFF6F0E4),
  cover: Color(0xFF7462A6),
  left: Color(0xFFFAF8FF),
  right: Color(0xFFEFEAFA),
  dot: Color(0xFFC2492F),
);

const _SplashColors _night = (
  background: Color(0xFF1F1B17),
  cover: Color(0xFFA99BD3),
  left: Color(0xFF2D2822),
  right: Color(0xFF26211C),
  dot: Color(0xFFFF8A6B),
);

/// The icon's book in a 1024 box, centred on its middle with the dot, as
/// `build_icons.py` draws it; the dot rises from behind the pages.
class _BookPainter extends CustomPainter {
  _BookPainter({required this.colors, required this.rise, required this.grow});

  final _SplashColors colors;

  /// 0 — the dot hidden behind the book, 1 — at its place above it.
  final double rise;

  /// Scale of the whole picture.
  final double grow;

  static const _middle = Offset(512, 497);
  static const _dotFrom = 560.0;
  static const _dotTo = 300.0;
  static const _dotRadius = 46.0;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 1024 * grow;
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..scale(k)
      ..translate(-_middle.dx, -_middle.dy);
    final dotY = _dotFrom + (_dotTo - _dotFrom) * rise;
    canvas
      ..drawCircle(
        Offset(512, dotY),
        _dotRadius * (0.7 + 0.3 * rise.clamp(0, 1)),
        Paint()..color = colors.dot,
      )
      ..drawPath(_cover, Paint()..color = colors.cover)
      ..drawPath(_left, Paint()..color = colors.left)
      ..drawPath(_right, Paint()..color = colors.right);
  }

  static final _cover = Path()
    ..moveTo(512, 740)
    ..cubicTo(430, 690, 340, 680, 240, 700)
    ..lineTo(240, 400)
    ..cubicTo(340, 380, 430, 390, 512, 440)
    ..cubicTo(594, 390, 684, 380, 784, 400)
    ..lineTo(784, 700)
    ..cubicTo(684, 680, 594, 690, 512, 740)
    ..close();

  static final _left = Path()
    ..moveTo(512, 690)
    ..cubicTo(436, 648, 350, 636, 270, 652)
    ..lineTo(270, 390)
    ..cubicTo(350, 374, 436, 384, 512, 430)
    ..close();

  static final _right = Path()
    ..moveTo(512, 690)
    ..cubicTo(588, 648, 674, 636, 754, 652)
    ..lineTo(754, 390)
    ..cubicTo(674, 374, 588, 384, 512, 430)
    ..close();

  @override
  bool shouldRepaint(_BookPainter old) =>
      old.rise != rise || old.grow != grow || old.colors != colors;
}
