import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/logic/performance_tier.dart';

void main() {
  group('performanceTierFor', () {
    test('normal: 80% or more is excellent', () {
      expect(
        performanceTierFor(numerator: 8, denominator: 10),
        PerformanceTier.excellent,
      );
    });

    test('normal: between 50% and 80% is nice', () {
      expect(
        performanceTierFor(numerator: 6, denominator: 10),
        PerformanceTier.nice,
      );
    });

    test('normal: below 50% is needsWork', () {
      expect(
        performanceTierFor(numerator: 3, denominator: 10),
        PerformanceTier.needsWork,
      );
    });

    test('boundary: exactly 80% is excellent, not nice', () {
      expect(
        performanceTierFor(numerator: 4, denominator: 5),
        PerformanceTier.excellent,
      );
    });

    test('boundary: exactly 50% is nice, not needsWork', () {
      expect(
        performanceTierFor(numerator: 5, denominator: 10),
        PerformanceTier.nice,
      );
    });

    test('boundary: just below 80% (79%) is nice, not excellent — the '
        'exact ratio is compared, never rounded first', () {
      expect(
        performanceTierFor(numerator: 79, denominator: 100),
        PerformanceTier.nice,
      );
    });

    test('boundary: just below 50% (49%) is needsWork, not nice — the '
        'exact ratio is compared, never rounded first', () {
      expect(
        performanceTierFor(numerator: 49, denominator: 100),
        PerformanceTier.needsWork,
      );
    });

    test('edge: exactly 0% is needsWork', () {
      expect(
        performanceTierFor(numerator: 0, denominator: 10),
        PerformanceTier.needsWork,
      );
    });

    test(
      'failure: a zero denominator is treated as needsWork, not a '
      'division-by-zero crash',
      () {
        expect(
          performanceTierFor(numerator: 0, denominator: 0),
          PerformanceTier.needsWork,
        );
      },
    );
  });

  group('performanceTierMessage', () {
    test('excellent has the exact NOTE 6 copy', () {
      expect(
        performanceTierMessage(PerformanceTier.excellent),
        'Excellent work! You nailed it. You should be proud of this one.',
      );
    });

    test('nice has the exact NOTE 6 copy', () {
      expect(
        performanceTierMessage(PerformanceTier.nice),
        "Nice progress! You're close, keep it up.",
      );
    });

    test('needsWork has the exact NOTE 6 copy', () {
      expect(
        performanceTierMessage(PerformanceTier.needsWork),
        "This one needs more work before it clicks. You'll get there.",
      );
    });

    test('every tier has distinct, non-empty copy', () {
      final messages = PerformanceTier.values
          .map(performanceTierMessage)
          .toSet();
      expect(messages.length, PerformanceTier.values.length);
      for (final m in messages) {
        expect(m, isNotEmpty);
      }
    });
  });

  group('Quiz usage: correct / total questions', () {
    test('a real quiz ratio (8 correct of 10) is excellent', () {
      expect(
        performanceTierFor(numerator: 8, denominator: 10),
        PerformanceTier.excellent,
      );
    });
  });

  group('Flashcards usage: known / cards reviewed', () {
    test('a real flashcards ratio (6 known of 10 reviewed) is nice', () {
      expect(
        performanceTierFor(numerator: 6, denominator: 10),
        PerformanceTier.nice,
      );
    });
  });
}
