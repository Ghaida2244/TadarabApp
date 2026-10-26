import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/screens/calendar/widgets/day_events_sheet.dart';

void main() {
  final day = DateTime(2026, 5, 14);
  // Well before `day`, so every existing test below — none of which pass
  // `now` explicitly — deterministically exercises the "future day,
  // unchanged" case they were all written for, rather than depending on
  // whatever the real wall-clock date happens to be relative to a fixed
  // `day`.
  final beforeDay = DateTime(2026, 4, 1);

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
    DateTime? now,
    DateTime? forDay,
  }) async {
    final deleted = <CalendarEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DayEventsSheet(
            day: forDay ?? day,
            events: events,
            coursesById: coursesById,
            onDeleteRequested: deleted.add,
            now: now ?? beforeDay,
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

  group('Finished grouping — selected day is today', () {
    final today = DateTime(2026, 5, 14);
    final noon = DateTime(2026, 5, 14, 12, 0);

    testWidgets(
      'not-yet-started first (ascending), then a Finished divider, then '
      'already-started (also ascending)',
      (tester) async {
        await pumpSheet(
          tester,
          forDay: today,
          now: noon,
          events: [
            event(id: 'a', name: 'Early', time: '08:00'),
            event(id: 'b', name: 'LateMorning', time: '10:00'),
            event(id: 'c', name: 'Afternoon', time: '14:00'),
            event(id: 'd', name: 'Evening', time: '18:00'),
          ],
        );

        expect(find.text('Finished'), findsOneWidget);

        final afternoonY = tester.getTopLeft(find.text('Afternoon')).dy;
        final eveningY = tester.getTopLeft(find.text('Evening')).dy;
        final dividerY = tester.getTopLeft(find.text('Finished')).dy;
        final earlyY = tester.getTopLeft(find.text('Early')).dy;
        final lateMorningY = tester.getTopLeft(find.text('LateMorning')).dy;

        expect(afternoonY, lessThan(eveningY));
        expect(eveningY, lessThan(dividerY));
        expect(dividerY, lessThan(earlyY));
        expect(earlyY, lessThan(lateMorningY));
      },
    );

    testWidgets(
      'finished events are dimmed; not-yet-started events are not',
      (tester) async {
        await pumpSheet(
          tester,
          forDay: today,
          now: noon,
          events: [
            event(id: 'a', name: 'Early', time: '08:00'),
            event(id: 'c', name: 'Afternoon', time: '14:00'),
          ],
        );

        final earlyOpacity = tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text('Early'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;
        final afternoonOpacity = tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text('Afternoon'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;

        expect(earlyOpacity, lessThan(1.0));
        expect(afternoonOpacity, 1.0);
      },
    );

    testWidgets(
      'a finished event\'s delete button is never dimmed and keeps working',
      (tester) async {
        final deleted = await pumpSheet(
          tester,
          forDay: today,
          now: noon,
          events: [event(id: 'e1', name: 'Early', time: '08:00')],
        );

        expect(
          find.ancestor(
            of: find.bySemanticsLabel('Delete event'),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );

        await tester.tap(find.bySemanticsLabel('Delete event'));
        await tester.pumpAndSettle();
        expect(deleted.single.eventId, 'e1');
      },
    );

    testWidgets('only not-yet-started events today shows no divider', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        forDay: today,
        now: noon,
        events: [event(id: 'c', name: 'Afternoon', time: '14:00')],
      );

      expect(find.text('Finished'), findsNothing);
    });

    testWidgets('only already-started events today shows no divider', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        forDay: today,
        now: noon,
        events: [event(id: 'a', name: 'Early', time: '08:00')],
      );

      expect(find.text('Finished'), findsNothing);
    });

    testWidgets(
      'boundary: an event starting exactly at now counts as finished',
      (tester) async {
        await pumpSheet(
          tester,
          forDay: today,
          now: noon,
          events: [event(id: 'x', name: 'RightNow', time: '12:00')],
        );

        // Only one group ends up populated, so no divider either way —
        // the real assertion is that it landed in the finished (dimmed)
        // group at all.
        expect(find.text('Finished'), findsNothing);
        final opacity = tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text('RightNow'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;
        expect(opacity, lessThan(1.0));
      },
    );
  });

  group('Finished grouping — selected day is in the past', () {
    testWidgets(
      'all events dimmed, plain chronological order, no divider',
      (tester) async {
        final pastDay = DateTime(2026, 5, 10);
        final laterNow = DateTime(2026, 5, 14, 9, 0);

        await pumpSheet(
          tester,
          forDay: pastDay,
          now: laterNow,
          events: [
            event(id: 'late', name: 'Evening', time: '20:00'),
            event(id: 'early', name: 'Morning', time: '07:30'),
          ],
        );

        expect(find.text('Finished'), findsNothing);
        expect(
          tester.getTopLeft(find.text('Morning')).dy,
          lessThan(tester.getTopLeft(find.text('Evening')).dy),
        );

        final morningOpacity = tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text('Morning'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;
        final eveningOpacity = tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text('Evening'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;
        expect(morningOpacity, lessThan(1.0));
        expect(eveningOpacity, lessThan(1.0));
      },
    );
  });

  group('Finished grouping — selected day is in the future', () {
    testWidgets(
      'unchanged: plain chronological order, no divider, no dimming',
      (tester) async {
        await pumpSheet(
          tester,
          events: [
            event(id: 'late', name: 'Evening', time: '20:00'),
            event(id: 'early', name: 'Morning', time: '07:30'),
          ],
        );

        expect(find.text('Finished'), findsNothing);
        expect(
          tester.getTopLeft(find.text('Morning')).dy,
          lessThan(tester.getTopLeft(find.text('Evening')).dy),
        );
        // The row always wraps its colour bar/text in an Opacity (so the
        // dimmed and un-dimmed cases share one code path) — "no dimming"
        // means that opacity is fully opaque, not that the widget is absent.
        final morningOpacity = tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text('Morning'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;
        expect(morningOpacity, 1.0);
      },
    );
  });
}
