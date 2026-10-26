import 'package:flutter/material.dart';

import '../../../utils/rank.dart';

/// Draws the rank glyph: the same five-pointed star for every tier.
///
/// The handoff's "unique" set (a bespoke SVG path per tier) was used
/// originally, hand-translated into a [Path] and painted at the requested
/// size; the design's other icon set — a single star for every tier — is
/// now the one in use instead, drawn from the former tier 7 glyph.
class RankIcon extends StatelessWidget {
  const RankIcon({
    super.key,
    required this.tier,
    required this.color,
    required this.size,
    this.filled = true,
  });

  /// 1-based tier number, as carried by [Rank.tier].
  final int tier;

  /// Stroke colour, and fill colour when [filled].
  final Color color;

  /// Width and height to paint at; the glyph scales from its 24×24 box.
  final double size;

  /// Whether the glyph is solid. The design fills a rank the student has
  /// reached and outlines one they haven't (`fill: 'none'`).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RankIconPainter(tier: tier, color: color, filled: filled),
        // Lets a test target one icon, and keeps the glyph out of the
        // semantics tree — the rank name beside it is the real label.
        isComplex: false,
      ),
    );
  }
}

/// Paints one tier's glyph, scaled from the design's 24×24 viewBox.
class _RankIconPainter extends CustomPainter {
  const _RankIconPainter({
    required this.tier,
    required this.color,
    required this.filled,
  });

  final int tier;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24.0;
    canvas.save();
    canvas.scale(scale);

    final path = rankIconPath(tier);
    if (filled) {
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        // The design's stroke-width:2 in the same 24-unit space.
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RankIconPainter oldDelegate) =>
      oldDelegate.tier != tier ||
      oldDelegate.color != color ||
      oldDelegate.filled != filled;
}

/// The glyph for [tier] as a [Path] in the design's 24×24 coordinate space —
/// the same five-pointed star for every tier (the former tier 7 glyph).
///
/// Public so the icon can be unit-tested without a canvas. [tier] is
/// accepted but otherwise unused — kept so callers never need to special-
/// case a tier number, and so an out-of-range tier still degrades to the
/// star rather than throwing.
Path rankIconPath(int tier) {
  return Path()
    ..moveTo(12, 4)
    ..lineTo(14.3, 8.8)
    ..lineTo(19.5, 9.5)
    ..lineTo(15.7, 13.1)
    ..lineTo(16.6, 18.3)
    ..lineTo(12, 15.8)
    ..lineTo(7.4, 18.3)
    ..lineTo(8.3, 13.1)
    ..lineTo(4.5, 9.5)
    ..lineTo(9.7, 8.8)
    ..close();
}
