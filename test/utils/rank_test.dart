import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/utils/rank.dart';

void main() {
  group('kRanks table', () {
    test('has the ten tiers the SRS specifies, in order', () {
      expect(kRanks, hasLength(10));
      expect(kRanks.first.name, 'Beginner Learner');
      expect(kRanks.last.name, 'Master Learner');
      for (var i = 0; i < kRanks.length; i++) {
        expect(kRanks[i].tier, i + 1);
      }
    });

    test('is contiguous — no total can fall between two ranks', () {
      for (var i = 0; i < kRanks.length - 1; i++) {
        expect(
          kRanks[i + 1].minPoints,
          kRanks[i].maxPoints! + 1,
          reason: 'gap between ${kRanks[i].name} and ${kRanks[i + 1].name}',
        );
      }
    });

    test('only the top rank is unbounded', () {
      for (final rank in kRanks.take(9)) {
        expect(rank.isTop, isFalse);
        expect(rank.maxPoints, isNotNull);
      }
      expect(kRanks.last.isTop, isTrue);
      expect(kRanks.last.maxPoints, isNull);
    });

    test('matches the SRS thresholds exactly', () {
      expect(
        kRanks.map((r) => r.minPoints),
        [0, 100, 300, 700, 1200, 1800, 2600, 3600, 5000, 7000],
      );
      expect(
        kRanks.map((r) => r.maxPoints),
        [99, 299, 699, 1199, 1799, 2599, 3599, 4999, 6999, null],
      );
    });
  });

  group('rankForPoints', () {
    test('zero points is the first rank', () {
      expect(rankForPoints(0).name, 'Beginner Learner');
    });

    test('every lower boundary lands on its own rank', () {
      for (final rank in kRanks) {
        expect(
          rankForPoints(rank.minPoints).name,
          rank.name,
          reason: '${rank.minPoints} should be ${rank.name}',
        );
      }
    });

    test('every upper boundary stays in its rank', () {
      for (final rank in kRanks.take(9)) {
        expect(
          rankForPoints(rank.maxPoints).name,
          rank.name,
          reason: '${rank.maxPoints} should still be ${rank.name}',
        );
      }
    });

    test('one point past a ceiling promotes', () {
      expect(rankForPoints(99).name, 'Beginner Learner');
      expect(rankForPoints(100).name, 'Active Learner');
      expect(rankForPoints(6999).name, 'Elite Learner');
      expect(rankForPoints(7000).name, 'Master Learner');
    });

    test('anything above the top threshold is the top rank', () {
      expect(rankForPoints(7000).name, 'Master Learner');
      expect(rankForPoints(999999).name, 'Master Learner');
    });

    test('negative points fall back to the first rank', () {
      expect(rankForPoints(-1).name, 'Beginner Learner');
      expect(rankForPoints(-99999).name, 'Beginner Learner');
    });

    test('a missing total falls back to the first rank', () {
      expect(rankForPoints(null).name, 'Beginner Learner');
    });
  });

  group('nextRankAfter', () {
    test('steps up one tier', () {
      expect(nextRankAfter(kRanks.first)!.name, 'Active Learner');
      expect(nextRankAfter(kRanks[8])!.name, 'Master Learner');
    });

    test('is null at the top', () {
      expect(nextRankAfter(kRanks.last), isNull);
    });
  });

  group('pointsToNextRank', () {
    test('counts the gap to the next threshold', () {
      expect(pointsToNextRank(0), 100);
      expect(pointsToNextRank(50), 50);
      expect(pointsToNextRank(99), 1);
    });

    test('is zero at the moment of promotion, not negative', () {
      // 100 is Active Learner's own floor, so the gap to Focused is 200.
      expect(pointsToNextRank(100), 200);
    });

    test('is null at the top rank', () {
      expect(pointsToNextRank(7000), isNull);
      expect(pointsToNextRank(50000), isNull);
    });

    test('treats negative and missing totals as zero', () {
      expect(pointsToNextRank(-5), 100);
      expect(pointsToNextRank(null), 100);
    });
  });

  group('progressWithinRank', () {
    test('is zero at a rank floor', () {
      expect(progressWithinRank(0), 0);
      expect(progressWithinRank(100), 0);
      expect(progressWithinRank(7000), 1); // top rank is always full
    });

    test('is full at a rank ceiling', () {
      // 99 of a 0-99 span is 99/99.
      expect(progressWithinRank(99), 1);
    });

    test('is proportional in between', () {
      // Active Learner spans 100-299, so 200 is halfway (100/199).
      expect(progressWithinRank(200), closeTo(0.503, 0.01));
    });

    test('the top rank always reads as full', () {
      expect(progressWithinRank(7000), 1);
      expect(progressWithinRank(999999), 1);
    });

    test('never escapes 0..1', () {
      for (final points in [-100, 0, 1, 99, 100, 3599, 6999, 7000, 123456]) {
        final value = progressWithinRank(points);
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThanOrEqualTo(1.0));
      }
    });

    test('treats a missing total as zero progress', () {
      expect(progressWithinRank(null), 0);
    });
  });

  group('labels', () {
    test('shortName drops the trailing " Learner"', () {
      expect(kRanks.first.shortName, 'Beginner');
      expect(kRanks.last.shortName, 'Master');
    });

    test('rangeLabel reads as the design prints it', () {
      expect(kRanks.first.rangeLabel, '0 – 99 pts');
      expect(kRanks[3].rangeLabel, '700 – 1,199 pts');
      expect(kRanks.last.rangeLabel, '7,000+ pts');
    });

    test('formatPoints groups thousands', () {
      expect(formatPoints(0), '0');
      expect(formatPoints(999), '999');
      expect(formatPoints(1450), '1,450');
      expect(formatPoints(1000000), '1,000,000');
    });

    test('formatPoints clamps negative and missing totals to zero', () {
      expect(formatPoints(-5), '0');
      expect(formatPoints(null), '0');
    });
  });
}
