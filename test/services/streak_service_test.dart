import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/services/streak_service.dart';

void main() {
  group('computeNextStreak', () {
    test('first-ever activity starts the streak at 1', () {
      final result = computeNextStreak(
        currentStreak: 0,
        lastStudyDate: null,
        activityDate: DateTime(2026, 3, 10),
      );
      expect(result, 1);
    });

    test('a second session the same calendar day does not double-count', () {
      final result = computeNextStreak(
        currentStreak: 5,
        lastStudyDate: DateTime(2026, 3, 10, 8, 0),
        activityDate: DateTime(2026, 3, 10, 22, 30),
      );
      expect(result, 5);
    });

    test('activity exactly one calendar day later extends the streak by 1', () {
      final result = computeNextStreak(
        currentStreak: 5,
        lastStudyDate: DateTime(2026, 3, 10),
        activityDate: DateTime(2026, 3, 11),
      );
      expect(result, 6);
    });

    test(
      'crossing a week boundary is just another consecutive day — no reset',
      () {
        // Saturday -> Sunday: a new week starts on the weekly row, but the
        // streak itself must not care about week boundaries at all.
        final result = computeNextStreak(
          currentStreak: 6,
          lastStudyDate: DateTime(2026, 3, 14), // a Saturday
          activityDate: DateTime(2026, 3, 15), // the following Sunday
        );
        expect(result, 7);
      },
    );

    test('a gap of exactly one full zero-activity day breaks the streak, restarting at 1', () {
      // Last study Monday, activity Wednesday: Tuesday had zero activity.
      final result = computeNextStreak(
        currentStreak: 6,
        lastStudyDate: DateTime(2026, 3, 9),
        activityDate: DateTime(2026, 3, 11),
      );
      expect(result, 1);
    });

    test(
      'a long gap also just restarts at 1, not a negative or zero streak',
      () {
        final result = computeNextStreak(
          currentStreak: 40,
          lastStudyDate: DateTime(2026, 1, 1),
          activityDate: DateTime(2026, 3, 10),
        );
        expect(result, 1);
      },
    );

    test('midnight-to-midnight local time, not a rolling 24h window: 11:59pm then 12:01am next day still counts as consecutive', () {
      final result = computeNextStreak(
        currentStreak: 3,
        lastStudyDate: DateTime(2026, 3, 10, 23, 59),
        activityDate: DateTime(2026, 3, 11, 0, 1),
      );
      expect(result, 4);
    });

    test('an out-of-order activity date (before lastStudyDate) does not corrupt the streak', () {
      final result = computeNextStreak(
        currentStreak: 5,
        lastStudyDate: DateTime(2026, 3, 10),
        activityDate: DateTime(2026, 3, 8),
      );
      expect(result, 5);
    });
  });

  group('dateOnly', () {
    test('strips the time-of-day, keeping local date', () {
      expect(
        dateOnly(DateTime(2026, 3, 10, 23, 59, 59)),
        DateTime(2026, 3, 10),
      );
    });
  });
}
