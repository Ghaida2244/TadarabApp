import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/screens/calendar/widgets/day_events_sheet.dart';

void main() {
  final day = DateTime(2026, 5, 14);

  CalendarEvent event({
    String id = 'e1',
    String name = 'Midterm',
    String time = '09:00',
    String color = '#F5A524',
    String? courseId,
    bool reminderEnabled = false,
    int? reminderBefore,
    ReminderUnit? reminderUnit,
  }) => CalendarEvent(
    eventId: id,
    eventName: name,
    eventDate: day,
    eventTime: time,
    color: color,
    email: 'student@example.com',
    courseId: courseId,
    reminderEnabled: reminderEnabled,
    reminderBefore: reminderBefore,
    reminderUnit: reminderUnit,
  );

  Future<List<CalendarEvent>> pumpSheet(
    WidgetTester tester, {
    required List<CalendarEvent> events,
    Map<String, Course> coursesById = const {},
  }) async {
    final deleted = <CalendarEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DayEventsSheet(
            day: day,
            events: events,
            coursesById: coursesById,
            onDeleteRequested: deleted.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return deleted;
  }

  testWidgets('shows the long date and a singular count', (tester) async {
    await pumpSheet(tester, events: [event()]);

    expect(find.text('May 14, 2026'), findsOneWidget);
    expect(find.text('1 event'), findsOneWidget);
  });

  testWidgets('pluralises the count', (tester) async {
    await pumpSheet(
      tester,
      events: [event(id: 'a'), event(id: 'b', time: '10:00')],
    );

    expect(find.text('2 events'), findsOneWidget);
  });

  testWidgets('sorts events by time regardless of input order', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      events: [
        event(id: 'late', name: 'Evening', time: '20:00'),
        event(id: 'early', name: 'Morning', time: '07:30'),
      ],
    );

    expect(
      tester.getTopLeft(find.text('Morning')).dy,
      lessThan(tester.getTopLeft(find.text('Evening')).dy),
    );
  });

  testWidgets('renders the time in 12-hour form', (tester) async {
    await pumpSheet(tester, events: [event(time: '23:59')]);

    expect(find.textContaining('11:59 PM'), findsOneWidget);
  });

  group('course name', () {
    testWidgets('is shown when the course exists', (tester) async {
      await pumpSheet(
        tester,
        events: [event(courseId: 'c1')],
        coursesById: {
          'c1': Course(courseId: 'c1', courseName: 'IS230', email: 'e@x.com'),
        },
      );

      expect(find.text('IS230'), findsOneWidget);
    });

    testWidgets('is omitted for an event with no course', (tester) async {
      await pumpSheet(tester, events: [event()]);

      expect(find.text('IS230'), findsNothing);
      expect(find.text('Midterm'), findsOneWidget);
    });

    testWidgets(
      'is omitted — without crashing — when the course was deleted',
      (tester) async {
        await pumpSheet(
          tester,
          // The course this points at is absent from the lookup.
          events: [event(courseId: 'gone')],
          coursesById: {
            'c1': Course(courseId: 'c1', courseName: 'IS230', email: 'e@x.com'),
          },
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Midterm'), findsOneWidget);
        expect(find.text('IS230'), findsNothing);
      },
    );

    testWidgets('is omitted when the lookup is empty entirely', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        events: [event(courseId: 'c1')],
        coursesById: const {},
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Midterm'), findsOneWidget);
    });
  });

  group('reminder summary', () {
    testWidgets('appends the lead time when a reminder is set', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        events: [
          event(
            reminderEnabled: true,
            reminderBefore: 2,
            reminderUnit: ReminderUnit.days,
          ),
        ],
      );

      expect(
        find.textContaining('reminder 2 days before'),
        findsOneWidget,
      );
    });

    testWidgets('singularises a lead time of one', (tester) async {
      await pumpSheet(
        tester,
        events: [
          event(
            reminderEnabled: true,
            reminderBefore: 1,
            reminderUnit: ReminderUnit.hours,
          ),
        ],
      );

      expect(
        find.textContaining('reminder 1 hour before'),
        findsOneWidget,
      );
    });

    testWidgets('is omitted when the reminder was stored as off', (
      tester,
    ) async {
      // The shape left behind when permission was declined.
      await pumpSheet(tester, events: [event(reminderEnabled: false)]);

      expect(find.textContaining('reminder'), findsNothing);
    });

    testWidgets('is omitted when the reminder is enabled but incomplete', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        events: [event(reminderEnabled: true)],
      );

      expect(find.textContaining('reminder'), findsNothing);
    });
  });

  testWidgets('the delete button reports the event', (tester) async {
    final deleted = await pumpSheet(tester, events: [event(id: 'e9')]);

    await tester.tap(find.bySemanticsLabel('Delete event'));
    await tester.pumpAndSettle();

    expect(deleted.single.eventId, 'e9');
  });

  testWidgets('an empty day shows the dashed empty state', (tester) async {
    await pumpSheet(tester, events: const []);

    expect(find.text('No events on this day'), findsOneWidget);
    expect(find.text('0 events'), findsOneWidget);
  });
}
