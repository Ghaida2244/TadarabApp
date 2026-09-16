import 'package:flutter/material.dart';

/// Wraps [child] with a dashed rounded-rectangle border. Flutter has no
/// built-in dashed border, and the mockup specifically calls for one (the
/// Today's Progress streak row's empty/locked day cells) — a solid border
/// would be a visible approximation, not a match.
class DashedRoundedBorder extends StatelessWidget {
  const DashedRoundedBorder({
    super.key,
    required this.child,
    required this.color,
    this.borderRadius = 12,
    this.strokeWidth = 2,
    this.dashWidth = 4,
    this.gapWidth = 3,
  });

  final Widget child;
  final Color color;
  final double borderRadius;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        radius: borderRadius,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        gapWidth: gapWidth,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.gapWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var drawing = true;
      while (distance < metric.length) {
        final segment = drawing ? dashWidth : gapWidth;
        final end = (distance + segment).clamp(0.0, metric.length);
        if (drawing) {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance = end;
        drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashWidth != oldDelegate.dashWidth ||
        gapWidth != oldDelegate.gapWidth;
  }
}
