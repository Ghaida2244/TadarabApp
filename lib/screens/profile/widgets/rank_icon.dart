import 'package:flutter/material.dart';

import '../../../utils/rank.dart';

/// Draws the design's ten rank glyphs.
///
/// The handoff ships each tier's icon as a bespoke SVG path in a 24×24
/// viewBox, and Material has no equivalent for most of them, so each path is
/// hand-translated into a [Path] below and painted at the requested size.
/// That keeps them exact rather than approximated — and needs no package.
///
/// The design's "unique" icon set is the one in use (the alternative, a
/// single star for every tier, is not).
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

/// The glyph for [tier] as a [Path] in the design's 24×24 coordinate space.
///
/// Public so the icons can be unit-tested without a canvas. An unknown tier
/// falls back to the first glyph rather than throwing — a rank number out of
/// range should degrade to a circle, not crash the Ranks screen.
Path rankIconPath(int tier) {
  switch (tier) {
    // 1 — Beginner: a plain circle.
    case 1:
      return Path()
        ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 7));

    // 2 — Active: triangle.
    case 2:
      return Path()
        ..moveTo(12, 4)
        ..lineTo(20, 19)
        ..lineTo(4, 19)
        ..close();

    // 3 — Focused: diamond.
    case 3:
      return Path()
        ..moveTo(12, 3)
        ..lineTo(20, 12)
        ..lineTo(12, 21)
        ..lineTo(4, 12)
        ..close();

    // 4 — Rising: hexagon.
    case 4:
      return Path()
        ..moveTo(12, 3)
        ..lineTo(20, 7.5)
        ..lineTo(20, 16.5)
        ..lineTo(12, 21)
        ..lineTo(4, 16.5)
        ..lineTo(4, 7.5)
        ..close();

    // 5 — Skilled: shield, with the design's two cubics for the point.
    case 5:
      return Path()
        ..moveTo(12, 3)
        ..lineTo(20, 6)
        ..lineTo(20, 12)
        ..cubicTo(20, 17, 16.5, 20, 12, 21)
        ..cubicTo(7.5, 20, 4, 17, 4, 12)
        ..lineTo(4, 6)
        ..close();

    // 6 — Advanced: lightning bolt.
    case 6:
      return Path()
        ..moveTo(13, 2)
        ..lineTo(4, 14)
        ..lineTo(11, 14)
        ..lineTo(10, 22)
        ..lineTo(19, 10)
        ..lineTo(12, 10)
        ..close();

    // 7 — Proficient: five-pointed star.
    case 7:
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

    // 8 — Expert: flame. The design's arc is a clockwise semicircle across
    // the base, then three cubics back up the inner curl.
    case 8:
      return Path()
        ..moveTo(12, 3)
        ..cubicTo(13, 7, 17, 8, 17, 13)
        ..arcToPoint(
          const Offset(7, 13),
          radius: const Radius.circular(5),
          clockwise: true,
        )
        ..cubicTo(7, 10, 9, 9, 9, 7)
        ..cubicTo(10, 8, 11, 9, 11, 10)
        ..cubicTo(12, 8, 12, 5, 12, 3)
        ..close();

    // 9 — Elite: gem.
    case 9:
      return Path()
        ..moveTo(6, 4)
        ..lineTo(18, 4)
        ..lineTo(21, 9)
        ..lineTo(12, 21)
        ..lineTo(3, 9)
        ..close();

    // 10 — Master: crown.
    case 10:
      return Path()
        ..moveTo(3, 8)
        ..lineTo(7.5, 12)
        ..lineTo(12, 5)
        ..lineTo(16.5, 12)
        ..lineTo(21, 8)
        ..lineTo(19, 19)
        ..lineTo(5, 19)
        ..close();

    default:
      return rankIconPath(1);
  }
}
