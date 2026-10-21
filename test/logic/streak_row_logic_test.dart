import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/logic/streak_row_logic.dart';

void main() {
  group('addDaysCalendar', () {
    test('normal: a shift within the same month moves the day only', () {
      expect(addDaysCalendar(DateTime(2026, 3, 8), -1), DateTime(2026, 3, 7));
    });

    test('edge: a backward shift crosses a month boundary correctly', () {
      expect(addDaysCalendar(DateTime(2026, 3, 1), -7), DateTime(2026, 2, 22));
    });

    test('edge: a forward shift crosses a year boundary correctly', () {
      expect(addDaysCalendar(DateTime(2025, 12, 29), 7), DateTime(2026, 1, 5));
    });

    test('normal: time-of-day is preserved exactly, not zeroed', () {
      expect(
        addDaysCalendar(DateTime(2026, 3, 8, 13, 45, 30), -7),
        DateTime(2026, 3, 1, 13, 45, 30),
      );
    });

    test(
      'failure-adjacent: this is calendar-date math, not Duration — '
      'repeatedly subtracting 7 days 52 times from a date lands on the '
      'exact same calendar day one year earlier regardless of any DST '
      'transition that span might contain',
      () {
        var d = DateTime(2026, 10, 19);
        for (var i = 0; i < 52; i++) {
          d = addDaysCalendar(d, -7);
        }
        expect(d, DateTime(2025, 10, 20));
      },
    );
  });

  group('weekStartForWeeksBack', () {
    test('normal: zero weeks back returns the current week unchanged', () {
      final currentWeekStart = DateTime(2026, 10, 18);
      expect(
        weekStartForWeeksBack(
          currentWeekStart: currentWeekStart,
          weeksBack: 0,
        ),
        currentWeekStart,
      );
    });

    test('normal: one week back is exactly 7 days earlier', () {
      expect(
        weekStartForWeeksBack(
          currentWeekStart: DateTime(2026, 10, 18),
          weeksBack: 1,
        ),
        DateTime(2026, 10, 11),
      );
    });

    test('edge: several weeks back crosses a month boundary correctly', () {
      expect(
        weekStartForWeeksBack(
          currentWeekStart: DateTime(2026, 10, 18),
          weeksBack: 3,
        ),
        DateTime(2026, 9, 27),
      );
    });

    test('failure: a negative weeksBack throws', () {
      expect(
        () => weekStartForWeeksBack(
          currentWeekStart: DateTime(2026, 10, 18),
          weeksBack: -1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('streakHeaderLabel', () {
    test('normal: current week entirely within one month shows just the '
        'month', () {
      expect(
        streakHeaderLabel(weekStart: DateTime(2026, 10, 18), isCurrent: true),
        'Oct',
      );
    });

    test('edge: current week spanning two months shows both', () {
      // Sunday Sep 27 2026 .. Saturday Oct 3 2026.
      expect(
        streakHeaderLabel(weekStart: DateTime(2026, 9, 27), isCurrent: true),
        'Sep – Oct',
      );
    });

    test('normal: an earlier week shows the explicit day range', () {
      expect(
        streakHeaderLabel(weekStart: DateTime(2026, 10, 11), isCurrent: false),
        'Oct 11 – Oct 17',
      );
    });

    test('edge: an earlier week spanning two months names both months', () {
      expect(
        streakHeaderLabel(weekStart: DateTime(2026, 9, 27), isCurrent: false),
        'Sep 27 – Oct 3',
      );
    });
  });

  group('dayCellFillState', () {
    test('normal: any day with activity is active, today or not', () {
      expect(
        dayCellFillState(hasActivity: true, isToday: false),
        DayCellFillState.active,
      );
      expect(
        dayCellFillState(hasActivity: true, isToday: true),
        DayCellFillState.active,
      );
    });

    test('edge: today with no activity yet is its own state', () {
      expect(
        dayCellFillState(hasActivity: false, isToday: true),
        DayCellFillState.todayEmpty,
      );
    });

    test(
      'normal: a non-today day with no activity is "otherEmpty" — this '
      'collapses a missed past day and a locked future day into the same '
      'fill/border, on purpose (only the label opacity tells them apart, '
      'see dayCellLabelOpacity)',
      () {
        expect(
          dayCellFillState(hasActivity: false, isToday: false),
          DayCellFillState.otherEmpty,
        );
      },
    );
  });

  group('dayCellLabelOpacity', () {
    test('normal: today is always full opacity', () {
      expect(
        dayCellLabelOpacity(isToday: true, isFuture: false),
        1.0,
      );
    });

    test('edge: a future/locked day is dimmer than a past day', () {
      expect(dayCellLabelOpacity(isToday: false, isFuture: true), 0.4);
    });

    test('normal: a past day (active or missed) is 0.6, not the dimmer 0.4 '
        'future value', () {
      expect(dayCellLabelOpacity(isToday: false, isFuture: false), 0.6);
    });
  });
}
