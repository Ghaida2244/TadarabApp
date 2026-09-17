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
}
