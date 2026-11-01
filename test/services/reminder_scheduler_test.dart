import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/services/reminder_scheduler.dart';

CalendarEvent _event({
  String eventName = 'mid',
  required DateTime eventDate,
  required String eventTime,
}) => CalendarEvent(
  eventId: 'e1',
  eventName: eventName,
  eventDate: eventDate,
  eventTime: eventTime,
  email: 'student@example.com',
);

void main() {
  group('eventReminderTitle', () {
    test('just the event name when there is no course', () {
      expect(eventReminderTitle('mid', null), 'mid');
    });

    test('an empty course name is treated the same as no course', () {
      expect(eventReminderTitle('mid', ''), 'mid');
      expect(eventReminderTitle('mid', '   '), 'mid');
    });

    test('event name, a " · " separator, then the course name', () {
      expect(eventReminderTitle('mid', 'IS463'), 'mid · IS463');
    });

    test('trims surrounding spaces on both the event and course name', () {
      expect(eventReminderTitle('  mid  ', '  IS463  '), 'mid · IS463');
    });
  });

  group('eventReminderBody', () {
    test('same calendar day as the fire time reads "today"', () {
      final event = _event(
        eventDate: DateTime(2026, 11, 1),
        eventTime: '16:00',
      );
      final body = eventReminderBody(event, DateTime(2026, 11, 1, 9));
      expect(body, "Don't forget your upcoming event today at 4:00 PM.");
    });

    test('the calendar day right after the fire time reads "tomorrow"', () {
      final event = _event(
        eventDate: DateTime(2026, 11, 2),
        eventTime: '12:00',
      );
      final body = eventReminderBody(event, DateTime(2026, 11, 1, 9));
      expect(body, "Don't forget your upcoming event tomorrow at 12:00 PM.");
    });

    test('a month boundary still reads "tomorrow" (fire time Oct 31, event '
        'Nov 1)', () {
      final event = _event(
        eventDate: DateTime(2026, 11, 1),
        eventTime: '09:00',
      );
      final body = eventReminderBody(event, DateTime(2026, 10, 31, 20));
      expect(body, "Don't forget your upcoming event tomorrow at 9:00 AM.");
    });

    test('any later date (not today or tomorrow) reads "on <date>"', () {
      final event = _event(
        eventDate: DateTime(2026, 11, 5),
        eventTime: '08:30',
      );
      final body = eventReminderBody(event, DateTime(2026, 11, 3, 9));
      expect(body, "Don't forget your upcoming event on Nov 5 at 8:30 AM.");
    });

    test('two days after the fire time (Nov 3 fire, Nov 5 event) is neither '
        'today nor tomorrow', () {
      final event = _event(
        eventDate: DateTime(2026, 11, 5),
        eventTime: '08:30',
      );
      final body = eventReminderBody(event, DateTime(2026, 11, 3, 9));
      expect(body, isNot(contains('today')));
      expect(body, isNot(contains('tomorrow')));
    });

    test('a different year than the fire time adds the year (the "on" '
        'case — fire Dec 31 2026, event Jan 5 2027)', () {
      final event = _event(eventDate: DateTime(2027, 1, 5), eventTime: '18:00');
      final body = eventReminderBody(event, DateTime(2026, 12, 31, 9));
      expect(
        body,
        "Don't forget your upcoming event on Jan 5, 2027 at 6:00 PM.",
      );
    });

    test('"tomorrow" never shows the date, even across a year boundary (fire '
        'Dec 31 2026, event Jan 1 2027) — just "tomorrow at <time>"', () {
      final event = _event(eventDate: DateTime(2027, 1, 1), eventTime: '00:30');
      final body = eventReminderBody(event, DateTime(2026, 12, 31, 9));
      expect(body, "Don't forget your upcoming event tomorrow at 12:30 AM.");
    });

    test('AM formatting', () {
      final event = _event(
        eventDate: DateTime(2026, 11, 1),
        eventTime: '00:05',
      );
      final body = eventReminderBody(event, DateTime(2026, 11, 1, 0));
      expect(body, contains('at 12:05 AM.'));
    });

    test('PM formatting', () {
      final event = _event(
        eventDate: DateTime(2026, 11, 1),
        eventTime: '23:59',
      );
      final body = eventReminderBody(event, DateTime(2026, 11, 1, 0));
      expect(body, contains('at 11:59 PM.'));
    });
  });

  group('notificationIdFor', () {
    test('is stable for the same event ID, so a reminder can be cancelled', () {
      expect(notificationIdFor('abc123'), notificationIdFor('abc123'));
    });

    test('stays a non-negative 32-bit int, as the plugin requires', () {
      for (final id in ['', 'a', 'x' * 500, 'Zq9-_ü']) {
        final n = notificationIdFor(id);
        expect(n, greaterThanOrEqualTo(0));
        expect(n, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });
  });

  group('daily study reminder (SRS text)', () {
    test('uses the exact title and body the SRS specifies', () {
      expect(kStudyReminderTitle, 'Time to Study!');
      expect(
        kStudyReminderBody,
        'Open Tadarab and continue your learning journey.',
      );
    });

    test('its title and body differ from the event reminder\'s', () {
      // Two distinct notifications: a nudge to study at all, versus a
      // specific event coming up.
      expect(kStudyReminderTitle, isNot(eventReminderTitle('mid', null)));
      expect(
        kStudyReminderBody,
        isNot(
          eventReminderBody(
            _event(eventDate: DateTime(2026, 11, 1), eventTime: '09:00'),
            DateTime(2026, 11, 1),
          ),
        ),
      );
    });
  });

  group('kStudyReminderNotificationId', () {
    test('is negative, which no event ID can ever be', () {
      // notificationIdFor masks with & 0x7FFFFFFF, so its range is
      // [0, 2^31-1]. A negative reserved ID therefore cannot collide with
      // any event's, for any event ID whatsoever.
      expect(kStudyReminderNotificationId, lessThan(0));
    });

    test('never equals notificationIdFor for a spread of document IDs', () {
      final ids = <String>[
        '',
        'a',
        'abc123',
        'oZ9kQ2pLmN4vB7xR1tYu',
        'x' * 64,
        '0',
        '-1',
        'study_reminder',
        for (var i = 0; i < 500; i++) 'doc-$i',
      ];
      for (final id in ids) {
        expect(
          notificationIdFor(id),
          isNot(kStudyReminderNotificationId),
          reason: 'collision for "$id"',
        );
      }
    });
  });
}
