import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/services/calendar_service.dart';
import 'package:tadarab_app/utils/event_time.dart';

CalendarEvent event({
  String id = 'e1',
  String name = 'Midterm',
  required DateTime date,
  String time = '12:00',
  bool reminderEnabled = false,
  int? reminderBefore,
  ReminderUnit? reminderUnit,
}) {
  return CalendarEvent(
    eventId: id,
    eventName: name,
    eventDate: date,
    eventTime: time,
    reminderEnabled: reminderEnabled,
    reminderBefore: reminderBefore,
    reminderUnit: reminderUnit,
    email: 'student@example.com',
  );
}

void main() {
  group('daysInMonth', () {
    test('handles 31-, 30- and 28-day months', () {
      expect(daysInMonth(2026, 5), 31);
      expect(daysInMonth(2026, 4), 30);
      expect(daysInMonth(2026, 2), 28);
    });

    test('handles a leap February', () {
      expect(daysInMonth(2024, 2), 29);
    });

    test('handles December without rolling into the next year', () {
      expect(daysInMonth(2026, 12), 31);
    });
  });

  group('monthGridCells', () {
    test('May 2026 has 5 leading blanks so the 1st lands on Friday', () {
      // Matches the mockup: May 2026 shows 1 and 2 alone on Fri/Sat.
      final cells = monthGridCells(DateTime(2026, 5, 1));

      expect(cells.length, 5 + 31);
      expect(cells.take(5), everyElement(isNull));
      expect(cells[5], DateTime(2026, 5, 1));
      expect(cells[6], DateTime(2026, 5, 2));
      expect(cells.last, DateTime(2026, 5, 31));
    });

    test('a month starting on Sunday has no leading blanks', () {
      final cells = monthGridCells(DateTime(2026, 2, 1));

      expect(cells.first, DateTime(2026, 2, 1));
      expect(cells.length, 28);
    });

    test('is unaffected by the time-of-day on the passed date', () {
      final fromMidMonth = monthGridCells(DateTime(2026, 5, 17, 23, 45));

      expect(fromMidMonth.length, 5 + 31);
      expect(fromMidMonth[5], DateTime(2026, 5, 1));
    });
  });

  group('addMonths', () {
    test('steps forward and back within a year', () {
      expect(addMonths(DateTime(2026, 5, 1), 1), DateTime(2026, 6, 1));
      expect(addMonths(DateTime(2026, 5, 1), -1), DateTime(2026, 4, 1));
    });

    test('rolls over the year boundary in both directions', () {
      expect(addMonths(DateTime(2026, 12, 1), 1), DateTime(2027, 1, 1));
      expect(addMonths(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 1));
    });

    test('stepping from a 31-day month does not skip February', () {
      // The bug this guards: adding 30/31 days instead of a month would
      // jump Jan 31 straight past February.
      final fromJan31 = addMonths(DateTime(2026, 1, 31), 1);

      expect(fromJan31, DateTime(2026, 2, 1));
      expect(addMonths(fromJan31, 1), DateTime(2026, 3, 1));
    });
  });

  group('parseEventTime', () {
    test('parses a stored HH:mm value', () {
      expect(parseEventTime('12:00'), const TimeOfDay(hour: 12, minute: 0));
      expect(parseEventTime('23:59'), const TimeOfDay(hour: 23, minute: 59));
      expect(parseEventTime('00:00'), const TimeOfDay(hour: 0, minute: 0));
    });

    test('returns null for malformed or out-of-range values', () {
      expect(parseEventTime('noon'), isNull);
      expect(parseEventTime('12'), isNull);
      expect(parseEventTime('12:00:00'), isNull);
      expect(parseEventTime('24:00'), isNull);
      expect(parseEventTime('12:60'), isNull);
      expect(parseEventTime(''), isNull);
    });
  });

  group('event time formatting', () {
    test('formats midday and midnight with the right meridiem', () {
      expect(
        formatEventTimeForDisplay(const TimeOfDay(hour: 12, minute: 0)),
        '12:00 PM',
      );
      expect(
        formatEventTimeForDisplay(const TimeOfDay(hour: 0, minute: 0)),
        '12:00 AM',
      );
    });

    test('formats afternoon and late-evening times', () {
      expect(
        formatEventTimeForDisplay(const TimeOfDay(hour: 13, minute: 5)),
        '1:05 PM',
      );
      expect(
        formatEventTimeForDisplay(const TimeOfDay(hour: 23, minute: 59)),
        '11:59 PM',
      );
    });

    test('round-trips through the stored HH:mm form', () {
      const time = TimeOfDay(hour: 9, minute: 7);
      expect(formatEventTimeForStorage(time), '09:07');
      expect(parseEventTime(formatEventTimeForStorage(time)), time);
    });

    test('falls back to the raw stored value when it cannot be parsed', () {
      expect(formatStoredTimeForDisplay('garbage'), 'garbage');
    });
  });

  group('eventDateTime', () {
    test('combines the date with the stored time-of-day', () {
      final combined = eventDateTime(
        event(date: DateTime(2026, 5, 14), time: '23:59'),
      );

      expect(combined, DateTime(2026, 5, 14, 23, 59));
    });

    test('falls back to midnight when the stored time is unparseable', () {
      final combined = eventDateTime(
        event(date: DateTime(2026, 5, 14, 18, 30), time: 'garbage'),
      );

      expect(combined, DateTime(2026, 5, 14));
    });
  });

  group('reminderFireTime', () {
    test('subtracts the lead time for each unit', () {
      final base = DateTime(2026, 5, 14);
      expect(
        reminderFireTime(
          event(
            date: base,
            time: '12:00',
            reminderEnabled: true,
            reminderBefore: 30,
            reminderUnit: ReminderUnit.minutes,
          ),
        ),
        DateTime(2026, 5, 14, 11, 30),
      );
      expect(
        reminderFireTime(
          event(
            date: base,
            time: '12:00',
            reminderEnabled: true,
            reminderBefore: 1,
            reminderUnit: ReminderUnit.days,
          ),
        ),
        DateTime(2026, 5, 13, 12, 0),
      );
      expect(
        reminderFireTime(
          event(
            date: base,
            time: '12:00',
            reminderEnabled: true,
            reminderBefore: 2,
            reminderUnit: ReminderUnit.weeks,
          ),
        ),
        DateTime(2026, 4, 30, 12, 0),
      );
    });

    test('crosses the month boundary backwards correctly', () {
      final fire = reminderFireTime(
        event(
          date: DateTime(2026, 5, 1),
          time: '00:30',
          reminderEnabled: true,
          reminderBefore: 1,
          reminderUnit: ReminderUnit.hours,
        ),
      );

      expect(fire, DateTime(2026, 4, 30, 23, 30));
    });

    test('returns null when the reminder is disabled', () {
      expect(
        reminderFireTime(
          event(
            date: DateTime(2026, 5, 14),
            reminderBefore: 1,
            reminderUnit: ReminderUnit.days,
          ),
        ),
        isNull,
      );
    });

    test('returns null when enabled but the amount or unit is missing', () {
      // Both are nullable on the model, so "enabled but incomplete" is
      // representable and must never be scheduled.
      expect(
        reminderFireTime(
          event(
            date: DateTime(2026, 5, 14),
            reminderEnabled: true,
            reminderUnit: ReminderUnit.days,
          ),
        ),
        isNull,
      );
      expect(
        reminderFireTime(
          event(
            date: DateTime(2026, 5, 14),
            reminderEnabled: true,
            reminderBefore: 1,
          ),
        ),
        isNull,
      );
    });
  });

  group('formatReminderUnitLabel', () {
    // The amount lives in its own field next to this dropdown (mockup 06),
    // so the label is the unit word alone — pluralised by the amount, which
    // is what makes the two fields read together as "1 Day" / "2 Days".
    test('uses the singular for exactly one', () {
      expect(formatReminderUnitLabel(1, ReminderUnit.days), 'Day');
      expect(formatReminderUnitLabel(1, ReminderUnit.minutes), 'Minute');
      expect(formatReminderUnitLabel(1, ReminderUnit.hours), 'Hour');
      expect(formatReminderUnitLabel(1, ReminderUnit.weeks), 'Week');
    });

    test('pluralises every other amount, including zero', () {
      expect(formatReminderUnitLabel(2, ReminderUnit.days), 'Days');
      expect(formatReminderUnitLabel(0, ReminderUnit.hours), 'Hours');
      expect(formatReminderUnitLabel(15, ReminderUnit.minutes), 'Minutes');
    });
  });

  group('groupEventsByDay', () {
    test('groups events onto their calendar day, ignoring time-of-day', () {
      final grouped = groupEventsByDay([
        event(id: 'a', date: DateTime(2026, 5, 14, 9), time: '23:59'),
        event(id: 'b', date: DateTime(2026, 5, 14, 22), time: '08:00'),
        event(id: 'c', date: DateTime(2026, 5, 20), time: '10:00'),
      ]);

      expect(grouped.keys.toSet(), {
        DateTime(2026, 5, 14),
        DateTime(2026, 5, 20),
      });
      expect(grouped[DateTime(2026, 5, 14)]!.length, 2);
    });

    test('sorts each day soonest-first by time of day', () {
      final grouped = groupEventsByDay([
        event(id: 'late', date: DateTime(2026, 5, 14), time: '23:59'),
        event(id: 'early', date: DateTime(2026, 5, 14), time: '08:00'),
      ]);

      expect(
        grouped[DateTime(2026, 5, 14)]!.map((e) => e.eventId),
        ['early', 'late'],
      );
    });

    test('returns an empty map for no events rather than throwing', () {
      expect(groupEventsByDay([]), isEmpty);
    });
  });

  group('reminderAlreadyPassed', () {
    final now = DateTime(2026, 5, 3, 9, 0);

    test('is false when the fire time is still ahead', () {
      // Event May 5 12:00, reminder 1 day before -> fires May 4 12:00.
      expect(
        reminderAlreadyPassed(
          event(
            date: DateTime(2026, 5, 5),
            reminderEnabled: true,
            reminderBefore: 1,
            reminderUnit: ReminderUnit.days,
          ),
          now,
        ),
        isFalse,
      );
    });

    test('is true for a future event whose lead time has already passed', () {
      // The event itself is still ahead (today 10:00), but a 1-day
      // reminder would have had to fire yesterday.
      expect(
        reminderAlreadyPassed(
          event(
            date: DateTime(2026, 5, 3),
            time: '10:00',
            reminderEnabled: true,
            reminderBefore: 1,
            reminderUnit: ReminderUnit.days,
          ),
          now,
        ),
        isTrue,
      );
    });

    test('treats a fire time of exactly now as passed', () {
      // Event 09:30 with a 30-minute reminder fires at 09:00 == now; it
      // can't be scheduled for a moment that is already here.
      expect(
        reminderAlreadyPassed(
          event(
            date: DateTime(2026, 5, 3),
            time: '09:30',
            reminderEnabled: true,
            reminderBefore: 30,
            reminderUnit: ReminderUnit.minutes,
          ),
          now,
        ),
        isTrue,
      );
    });

    test('is false when there is no usable reminder at all', () {
      expect(
        reminderAlreadyPassed(event(date: DateTime(2020, 1, 1)), now),
        isFalse,
      );
      expect(
        reminderAlreadyPassed(
          event(date: DateTime(2020, 1, 1), reminderEnabled: true),
          now,
        ),
        isFalse,
      );
    });
  });

  group('isSameMonth', () {
    test('is true only within the same month of the same year', () {
      expect(
        isSameMonth(DateTime(2026, 5, 1), DateTime(2026, 5, 31)),
        isTrue,
      );
      expect(isSameMonth(DateTime(2026, 5, 1), DateTime(2026, 6, 1)), isFalse);
    });

    test('distinguishes the same month in different years', () {
      expect(isSameMonth(DateTime(2026, 5, 3), DateTime(2027, 5, 3)), isFalse);
    });

    test('ignores the time of day', () {
      expect(
        isSameMonth(DateTime(2026, 5, 1, 23, 59), DateTime(2026, 5, 2, 0, 1)),
        isTrue,
      );
    });
  });

  group('formatEventCount', () {
    test('singularises one event', () {
      expect(formatEventCount(1), '1 event');
    });

    test('pluralises anything else', () {
      expect(formatEventCount(2), '2 events');
      expect(formatEventCount(11), '11 events');
    });

    test('handles zero without saying "0 event"', () {
      expect(formatEventCount(0), '0 events');
    });
  });

  group('formatReminderSummary', () {
    test('lower-cases the unit so it reads inside a sentence', () {
      expect(
        formatReminderSummary(3, ReminderUnit.hours),
        'reminder 3 hours before',
      );
    });

    test('singularises an amount of one', () {
      expect(
        formatReminderSummary(1, ReminderUnit.days),
        'reminder 1 day before',
      );
    });

    test('covers every unit', () {
      expect(
        formatReminderSummary(2, ReminderUnit.minutes),
        'reminder 2 minutes before',
      );
      expect(
        formatReminderSummary(2, ReminderUnit.weeks),
        'reminder 2 weeks before',
      );
    });
  });

  group('eventReminderSummary', () {
    CalendarEvent build({
      bool enabled = true,
      int? before = 1,
      ReminderUnit? unit = ReminderUnit.days,
    }) => CalendarEvent(
      eventId: 'e1',
      eventName: 'Midterm',
      eventDate: DateTime(2026, 5, 14),
      eventTime: '09:00',
      email: 'student@example.com',
      reminderEnabled: enabled,
      reminderBefore: before,
      reminderUnit: unit,
    );

    test('describes a complete reminder', () {
      expect(eventReminderSummary(build()), 'reminder 1 day before');
    });

    test('is null when the reminder is off', () {
      expect(eventReminderSummary(build(enabled: false)), isNull);
    });

    test('is null when enabled but missing its amount or unit', () {
      // Representable because both fields are nullable on the model.
      expect(eventReminderSummary(build(before: null)), isNull);
      expect(eventReminderSummary(build(unit: null)), isNull);
    });
  });

  group('reminderLeadPassed', () {
    final now = DateTime(2026, 5, 3, 9, 0);

    test('is false when the lead time is still ahead', () {
      expect(
        reminderLeadPassed(
          date: DateTime(2026, 5, 14),
          time: const TimeOfDay(hour: 9, minute: 0),
          amount: 1,
          unit: ReminderUnit.days,
          now: now,
        ),
        isFalse,
      );
    });

    test('is true when the lead time is in the past', () {
      expect(
        reminderLeadPassed(
          date: DateTime(2026, 5, 4),
          time: const TimeOfDay(hour: 9, minute: 0),
          amount: 1,
          unit: ReminderUnit.weeks,
          now: now,
        ),
        isTrue,
      );
    });

    test('a lead time landing exactly on now counts as passed', () {
      // May 4 09:00 minus one day is 09:00 on the 3rd — exactly "now", and
      // a notification for this instant can no longer be delivered.
      expect(
        reminderLeadPassed(
          date: DateTime(2026, 5, 4),
          time: const TimeOfDay(hour: 9, minute: 0),
          amount: 1,
          unit: ReminderUnit.days,
          now: now,
        ),
        isTrue,
      );
    });

    test('is false while either the date or the time is unset', () {
      // Nothing to validate against yet, which is what puts the note box in
      // its "pick a date and time" state rather than its error state.
      expect(
        reminderLeadPassed(
          date: null,
          time: const TimeOfDay(hour: 9, minute: 0),
          amount: 1,
          unit: ReminderUnit.days,
          now: now,
        ),
        isFalse,
      );
      expect(
        reminderLeadPassed(
          date: DateTime(2026, 5, 14),
          time: null,
          amount: 1,
          unit: ReminderUnit.days,
          now: now,
        ),
        isFalse,
      );
    });

    test('an event already in the past is always passed', () {
      expect(
        reminderLeadPassed(
          date: DateTime(2026, 4, 1),
          time: const TimeOfDay(hour: 9, minute: 0),
          amount: 1,
          unit: ReminderUnit.minutes,
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('reminder note messages', () {
    test('the passed message states the offending value', () {
      expect(
        formatReminderPassedMessage(3, ReminderUnit.hours),
        '3 hours before this event has already passed.',
      );
    });

    test('the passed message singularises one', () {
      expect(
        formatReminderPassedMessage(1, ReminderUnit.days),
        '1 day before this event has already passed.',
      );
    });

    test('the confirm message reads as a promise', () {
      expect(
        formatReminderConfirmMessage(2, ReminderUnit.weeks),
        'You will be notified 2 weeks before this event.',
      );
    });

    test('the confirm message singularises one', () {
      expect(
        formatReminderConfirmMessage(1, ReminderUnit.minutes),
        'You will be notified 1 minute before this event.',
      );
    });
  });
}
