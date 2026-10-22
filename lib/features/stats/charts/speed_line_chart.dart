import 'dart:math';

import 'package:book_app/features/stats/charts/chart_colors.dart';
import 'package:book_app/stats/stats_overview.dart';
import 'package:flutter/material.dart';

/// Two speed lines, by eye and speed reading, oldest point on the left;
/// spans without a speed are skipped, the line goes over them.
class SpeedLineChart extends StatelessWidget {
  const SpeedLineChart({
    super.key,
    required this.points,
    required this.colors,
    required this.label,
  });

  final List<SpeedPoint> points;
  final ChartColors colors;

  /// What the screen reader says instead.
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: SizedBox(
      height: 100,
      width: double.infinity,
      child: CustomPaint(painter: _LinePainter(points, colors)),
    ),
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.points, this.colors);

  final List<SpeedPoint> points;
  final ChartColors colors;

  static const _pad = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height - 2;
    canvas.drawLine(
      Offset(_pad, bottom),
      Offset(size.width - _pad, bottom),
      Paint()
        ..color = colors.line
        ..strokeWidth = 1,
    );
    final values = [
      for (final p in points) ...[?p.eye, ?p.play],
    ];
    if (values.isEmpty) return;
    final (low, high) = (values.reduce(min), values.reduce(max));
    // A flat line sits in the middle; others leave room around them.
    final room = max((high - low) * 0.15, 20.0);
    final (from, to) = (low - room, high + room);
    final step = points.length < 2
        ? 0.0
        : (size.width - 2 * _pad) / (points.length - 1);
    Offset at(int i, int wpm) => Offset(
      _pad + i * step,
      _pad + (to - wpm) / (to - from) * (bottom - 2 * _pad),
    );

    void series(int? Function(SpeedPoint p) of, Color color) {
      final dots = [
        for (var i = 0; i < points.length; i++)
          if (of(points[i]) case final wpm?) at(i, wpm),
      ];
      if (dots.isEmpty) return;
      canvas.drawPath(
        Path()..addPolygon(dots, false),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawCircle(dots.last, 4.5, Paint()..color = color);
    }

    series((p) => p.eye, colors.eye);
    series((p) => p.play, colors.play);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.colors != colors;
}
