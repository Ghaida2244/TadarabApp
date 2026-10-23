import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/screens/calendar/widgets/delete_event_dialog.dart';

void main() {
  CalendarEvent event({
    bool reminderEnabled = false,
    int? reminderBefore,
    ReminderUnit? reminderUnit,
  }) => CalendarEvent(
    eventId: 'e1',
    eventName: 'Midterm',
    eventDate: DateTime(2026, 5, 14),
    eventTime: '09:00',
    email: 'student@example.com',
    reminderEnabled: reminderEnabled,
    reminderBefore: reminderBefore,
    reminderUnit: reminderUnit,
  );

  group('deleteEventBody', () {
    test('names the reminder when the event has one', () {
      final body = deleteEventBody(
        event(
          reminderEnabled: true,
          reminderBefore: 1,
          reminderUnit: ReminderUnit.days,
        ),
      );

      expect(body, '$kDeleteBodyWithReminder $kDeleteBodyTail');
    });

    test('says only that it leaves the day when there is no reminder', () {
      expect(
        deleteEventBody(event()),
        '$kDeleteBodyNoReminder $kDeleteBodyTail',
      );
    });

    test('treats a reminder stored as off as having none to cancel', () {
      // The shape left behind when permission was declined: the student
      // asked for a reminder but none was ever scheduled.
      expect(
        deleteEventBody(event(reminderEnabled: false, reminderBefore: 3)),
        contains(kDeleteBodyNoReminder),
      );
    });
  });

  group('dialog', () {
    Future<bool?> showIt(WidgetTester tester, CalendarEvent target) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteEventDialog(
                    context,
                    event: target,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('shows the badge, title, body and both actions', (
      tester,
    ) async {
      await showIt(tester, event());

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('Delete this event?'), findsOneWidget);
      expect(find.textContaining(kDeleteBodyTail), findsOneWidget);
      expect(find.text('Delete event'), findsOneWidget);
      expect(find.text('Keep it'), findsOneWidget);
    });

    testWidgets('"Delete event" resolves true', (tester) async {
      await showIt(tester, event());

      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this event?'), findsNothing);
    });

    testWidgets('"Keep it" resolves false', (tester) async {
      await showIt(tester, event());

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this event?'), findsNothing);
    });

    testWidgets('a reminder event names the cancellation', (tester) async {
      await showIt(
        tester,
        event(
          reminderEnabled: true,
          reminderBefore: 2,
          reminderUnit: ReminderUnit.hours,
        ),
      );

      expect(find.textContaining(kDeleteBodyWithReminder), findsOneWidget);
    });
  });
}
