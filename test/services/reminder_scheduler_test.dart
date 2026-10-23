import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/services/reminder_scheduler.dart';

void main() {
  group('reminder notification content (SRS Figure 107)', () {
    test('uses the exact generic title and body the SRS specifies', () {
      expect(kEventReminderTitle, 'Event Reminder');
      expect(kEventReminderBody, "Don't forget your upcoming event.");
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
      expect(kStudyReminderTitle, isNot(kEventReminderTitle));
      expect(kStudyReminderBody, isNot(kEventReminderBody));
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
