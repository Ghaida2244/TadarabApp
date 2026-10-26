import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/profile/widgets/rank_icon.dart';
import 'package:tadarab_app/utils/rank.dart';

void main() {
  group('rankIconPath', () {
    test('every tier has a non-empty glyph', () {
      for (final rank in kRanks) {
        final path = rankIconPath(rank.tier);
        expect(
          path.getBounds().isEmpty,
          isFalse,
          reason: 'tier ${rank.tier} (${rank.name}) has an empty path',
        );
      }
    });

    test('every glyph stays inside the design\'s 24x24 viewBox', () {
      for (final rank in kRanks) {
        final bounds = rankIconPath(rank.tier).getBounds();
        expect(bounds.left, greaterThanOrEqualTo(0), reason: rank.name);
        expect(bounds.top, greaterThanOrEqualTo(0), reason: rank.name);
        expect(bounds.right, lessThanOrEqualTo(24), reason: rank.name);
        expect(bounds.bottom, lessThanOrEqualTo(24), reason: rank.name);
      }
    });

    test('an out-of-range tier never throws, and matches the normal glyph', () {
      final star = rankIconPath(1).getBounds();
      expect(rankIconPath(0).getBounds(), star);
      expect(rankIconPath(99).getBounds(), star);
      expect(rankIconPath(-3).getBounds(), star);
    });

    test('every tier produces the exact same star path', () {
      // One glyph for the whole ladder now — a cheap shape fingerprint
      // (bounds + total path metric length) should be identical across
      // every tier.
      String fingerprint(Path path) {
        final metrics = path.computeMetrics().fold<double>(
          0,
          (sum, m) => sum + m.length,
        );
        return '${path.getBounds()}|${metrics.toStringAsFixed(2)}';
      }

      final expected = fingerprint(rankIconPath(kRanks.first.tier));
      for (final rank in kRanks) {
        expect(
          fingerprint(rankIconPath(rank.tier)),
          expected,
          reason: 'tier ${rank.tier} (${rank.name}) should match the star '
              'every other tier uses',
        );
      }
    });
  });

  group('RankIcon widget', () {
    for (final rank in kRanks) {
      testWidgets('tier ${rank.tier} (${rank.name}) paints filled', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RankIcon(
                  tier: rank.tier,
                  color: rank.color,
                  size: 22,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(RankIcon)), const Size(22, 22));
      });

      testWidgets('tier ${rank.tier} paints outlined', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RankIcon(
                  tier: rank.tier,
                  color: rank.color,
                  size: 44,
                  filled: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('repaints when the tier or colour changes', (tester) async {
      Future<void> pump(int tier, Color color) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RankIcon(tier: tier, color: color, size: 22),
            ),
          ),
        ),
      );

      await pump(1, const Color(0xFF9AA0C4));
      await pump(10, const Color(0xFF0B0F5B));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
