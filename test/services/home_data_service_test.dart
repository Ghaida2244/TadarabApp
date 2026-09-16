import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/services/home_data_service.dart';

void main() {
  group('startOfWeek', () {
    test('a Wednesday resolves to the preceding Sunday', () {
      // 2026-03-11 is a Wednesday.
      expect(startOfWeek(DateTime(2026, 3, 11)), DateTime(2026, 3, 8));
    });

    test('a Sunday resolves to itself', () {
      expect(startOfWeek(DateTime(2026, 3, 8)), DateTime(2026, 3, 8));
    });

    test('a Saturday resolves to the Sunday six days earlier', () {
      expect(startOfWeek(DateTime(2026, 3, 14)), DateTime(2026, 3, 8));
    });
  });

  group('aggregateWeeklyProgress', () {
    final weekStart = DateTime(2026, 3, 8); // Sunday

    test('an empty entry list produces all-zero days for the full week', () {
      final result = aggregateWeeklyProgress(
        weekStart: weekStart,
        entries: const [],
      );

      expect(result.days.length, 7);
      expect(result.days.every((d) => d.combined == 0), isTrue);
      expect(result.weekStart, weekStart);
    });

    test('sums multiple entries landing on the same day', () {
      final result = aggregateWeeklyProgress(
        weekStart: weekStart,
        entries: [
          (date: DateTime(2026, 3, 10), questionCount: 5, flashcardCount: 0),
          (date: DateTime(2026, 3, 10), questionCount: 0, flashcardCount: 3),
        ],
      );

      final tuesday = result.days[2]; // Sun=0, Mon=1, Tue=2
      expect(tuesday.questionCount, 5);
      expect(tuesday.flashcardCount, 3);
      expect(tuesday.combined, 8);
    });

    test('a flashcards-only day still counts toward the combined total', () {
      final result = aggregateWeeklyProgress(
        weekStart: weekStart,
        entries: [
          (date: DateTime(2026, 3, 9), questionCount: 0, flashcardCount: 4),
        ],
      );

      expect(result.days[1].combined, 4);
    });

    test('entries outside the week are ignored rather than throwing', () {
      final result = aggregateWeeklyProgress(
        weekStart: weekStart,
        entries: [
          (
            date: DateTime(2026, 3, 1),
            questionCount: 9,
            flashcardCount: 0,
          ), // before the week
          (
            date: DateTime(2026, 3, 20),
            questionCount: 9,
            flashcardCount: 0,
          ), // after the week
        ],
      );

      expect(result.days.every((d) => d.combined == 0), isTrue);
    });

    test(
      'a timestamp with a time-of-day still lands on the correct local day',
      () {
        final result = aggregateWeeklyProgress(
          weekStart: weekStart,
          entries: [
            (
              date: DateTime(2026, 3, 8, 23, 59),
              questionCount: 2,
              flashcardCount: 0,
            ),
          ],
        );

        expect(result.days[0].questionCount, 2);
      },
    );
  });

  group('WeeklyProgress.dayForDate', () {
    test('returns the matching day within the week', () {
      final progress = aggregateWeeklyProgress(
        weekStart: DateTime(2026, 3, 8),
        entries: [
          (date: DateTime(2026, 3, 11), questionCount: 7, flashcardCount: 0),
        ],
      );

      expect(progress.dayForDate(DateTime(2026, 3, 11)).questionCount, 7);
    });

    test(
      'returns a zeroed day for a date outside the week rather than throwing',
      () {
        final progress = aggregateWeeklyProgress(
          weekStart: DateTime(2026, 3, 8),
          entries: const [],
        );

        final outside = progress.dayForDate(DateTime(2026, 4, 1));
        expect(outside.combined, 0);
      },
    );
  });
}
