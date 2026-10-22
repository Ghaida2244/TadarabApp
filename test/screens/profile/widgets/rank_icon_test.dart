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

    test('an out-of-range tier falls back to the first glyph', () {
      final fallback = rankIconPath(1).getBounds();
      expect(rankIconPath(0).getBounds(), fallback);
      expect(rankIconPath(99).getBounds(), fallback);
      expect(rankIconPath(-3).getBounds(), fallback);
    });

    test('the glyphs are distinct from one another', () {
      // A cheap shape fingerprint: no two tiers should share both bounds
      // and metric length, which would mean a copy-paste slip.
      final seen = <String>{};
      for (final rank in kRanks) {
        final path = rankIconPath(rank.tier);
        final metrics = path.computeMetrics().fold<double>(
          0,
          (sum, m) => sum + m.length,
        );
        final fingerprint =
            '${path.getBounds()}|${metrics.toStringAsFixed(2)}';
        expect(
          seen.add(fingerprint),
          isTrue,
          reason: 'tier ${rank.tier} duplicates another glyph',
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
