import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/screens/calendar/calendar_screen.dart';
import 'package:tadarab_app/screens/calendar/widgets/delete_event_dialog.dart';
import 'package:tadarab_app/services/calendar_service.dart';
import 'package:tadarab_app/services/courses_service.dart';

import '../../helpers/fake_calendar_service.dart';
import '../../helpers/fake_courses_service.dart';

void main() {
  // A fixed "today" inside May 2026 — the month the design shows, whose 1st
  // falls on a Friday, so the grid layout is deterministic.
  final now = DateTime(2026, 5, 3, 9, 0);

  CalendarEvent event({
    String id = 'e1',
    String name = 'Midterm',
    int day = 14,
    String time = '23:59',
    String color = '#F0A93B',
    String? courseId,
    bool reminderEnabled = false,
    int? reminderBefore,
    ReminderUnit? reminderUnit,
  }) {
    return CalendarEvent(
      eventId: id,
      eventName: name,
      eventDate: DateTime(2026, 5, day),
      eventTime: time,
      color: color,
      email: 'student@example.com',
      courseId: courseId,
      reminderEnabled: reminderEnabled,
      reminderBefore: reminderBefore,
      reminderUnit: reminderUnit,
    );
  }

  // The handoff's own device canvas. Also the only way the year view's four
  // rows of mini-months all get built: the default 800x600 surface leaves
  // December below the fold, and GridView builds lazily.
  Future<void> pumpCalendar(
    WidgetTester tester, {
    FakeCalendarService? service,
    FakeCoursesService? coursesService,
    VoidCallback? onEventsChanged,
  }) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            uid: 'uid-1',
            calendarService: service ?? FakeCalendarService(),
            coursesService: coursesService ?? FakeCoursesService(),
            now: now,
            onEventsChanged: onEventsChanged,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('month view', () {
    testWidgets('shows the header, month title and Add Event pill', (
      tester,
    ) async {
      await pumpCalendar(tester);

      expect(find.text('Calendar'), findsOneWidget);
      // The pill is now an icon plus bare text, not a "+ Add Event" string.
      expect(find.text('Add Event'), findsOneWidget);
      expect(find.text('May 2026'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
    });

    testWidgets('an empty month shows the line under the grid', (
      tester,
    ) async {
      await pumpCalendar(tester);

      expect(
        find.textContaining('No events yet.'),
        findsOneWidget,
      );
    });

    testWidgets('a month with events hides the empty line', (tester) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(events: [event()]),
      );

      expect(find.textContaining('No events yet.'), findsNothing);
    });

    testWidgets('shows a loading spinner before the first snapshot', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarScreen(
              uid: 'uid-1',
              calendarService: _PendingCalendarService(),
              coursesService: FakeCoursesService(),
              now: now,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('today is outlined, not filled — pale fill, red border', (
      tester,
    ) async {
      await pumpCalendar(tester);

      final todayCell = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('3'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = todayCell.decoration! as BoxDecoration;

      expect(decoration.color, const Color(0xFFFFE9EA));
      expect(decoration.border, isA<Border>());
      expect(
        (decoration.border! as Border).top.color,
        const Color(0xFFE31B23),
      );
      expect((decoration.border! as Border).top.width, 2);
    });

    testWidgets('caps dots at two and shows "+N" for the rest', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(
          events: [
            event(id: 'a', day: 14, time: '08:00'),
            event(id: 'b', day: 14, time: '09:00'),
            event(id: 'c', day: 14, time: '10:00'),
            event(id: 'd', day: 14, time: '11:00'),
          ],
        ),
      );

      expect(find.byKey(const ValueKey('day-dot-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-dot-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-dot-c')), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('a day with no events does not open the sheet', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(events: [event(day: 14)]),
      );

      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();

      expect(find.text('May 21, 2026'), findsNothing);
    });

    testWidgets('month arrows move the viewed month', (tester) async {
      final service = FakeCalendarService();
      await pumpCalendar(tester, service: service);

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('June 2026'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('April 2026'), findsOneWidget);
    });
  });

  group('back to today', () {
    testWidgets('is hidden on the current month', (tester) async {
      await pumpCalendar(tester);

      expect(find.text('Back to today'), findsNothing);
    });

    testWidgets('appears once the month changes and returns to today', (
      tester,
    ) async {
      await pumpCalendar(tester);

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('Back to today'), findsOneWidget);

      await tester.tap(find.text('Back to today'));
      await tester.pumpAndSettle();

      expect(find.text('May 2026'), findsOneWidget);
      expect(find.text('Back to today'), findsNothing);
    });
  });

  group('year view', () {
    testWidgets('the toggle swaps to twelve mini-months and the year', (
      tester,
    ) async {
      final service = FakeCalendarService();
      await pumpCalendar(tester, service: service);

      await tester.tap(find.bySemanticsLabel('Show year view'));
      await tester.pumpAndSettle();

      expect(find.text('2026'), findsOneWidget);
      expect(find.text('May 2026'), findsNothing);
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Dec'), findsOneWidget);
      // It reads the whole year, not one month.
      expect(service.watchedYears, contains(2026));
    });

    testWidgets('the arrows step by year while it is open', (tester) async {
      await pumpCalendar(tester);

      await tester.tap(find.bySemanticsLabel('Show year view'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Next year'));
      await tester.pumpAndSettle();
      expect(find.text('2027'), findsOneWidget);
    });

    testWidgets('"Back to today" is never offered in year view', (
      tester,
    ) async {
      await pumpCalendar(tester);

      await tester.tap(find.bySemanticsLabel('Show year view'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Next year'));
      await tester.pumpAndSettle();

      expect(find.text('Back to today'), findsNothing);
    });

    testWidgets('tapping a mini-month opens it in month view', (
      tester,
    ) async {
      await pumpCalendar(tester);

      await tester.tap(find.bySemanticsLabel('Show year view'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mini-month-8')));
      await tester.pumpAndSettle();

      expect(find.text('August 2026'), findsOneWidget);
    });
  });

  group('day details sheet', () {
    testWidgets('opens with the date, count and event', (tester) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(events: [event(day: 14)]),
      );

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();

      expect(find.text('May 14, 2026'), findsOneWidget);
      expect(find.text('1 event'), findsOneWidget);
      expect(find.text('Midterm'), findsOneWidget);
      expect(find.text('11:59 PM'), findsOneWidget);
    });

    testWidgets('pluralises the count and sorts by time', (tester) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(
          events: [
            event(id: 'late', name: 'Evening', day: 14, time: '18:00'),
            event(id: 'early', name: 'Morning', day: 14, time: '08:00'),
          ],
        ),
      );

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();

      expect(find.text('2 events'), findsOneWidget);
      final morning = tester.getTopLeft(find.text('Morning')).dy;
      final evening = tester.getTopLeft(find.text('Evening')).dy;
      expect(morning, lessThan(evening));
    });

    testWidgets('shows the linked course name', (tester) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(
          events: [event(day: 14, courseId: 'c1')],
        ),
        coursesService: FakeCoursesService(
          courses: [
            Course(courseId: 'c1', courseName: 'IS230', email: 'e@x.com'),
          ],
        ),
      );

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();

      expect(find.text('IS230'), findsOneWidget);
    });

    testWidgets(
      'an event whose course was deleted shows no course name and does not '
      'crash',
      (tester) async {
        await pumpCalendar(
          tester,
          service: FakeCalendarService(
            // Points at a course that is no longer in the student's list.
            events: [event(day: 14, courseId: 'deleted-course')],
          ),
          coursesService: FakeCoursesService(
            courses: [
              Course(courseId: 'c1', courseName: 'IS230', email: 'e@x.com'),
            ],
          ),
        );

        await tester.tap(find.text('14'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Midterm'), findsOneWidget);
        expect(find.text('IS230'), findsNothing);
      },
    );

    testWidgets(
      'a failed course fetch still lists the events, without course names',
      (tester) async {
        await pumpCalendar(
          tester,
          service: FakeCalendarService(
            events: [event(day: 14, courseId: 'c1')],
          ),
          coursesService: FakeCoursesService(
            courses: [
              Course(courseId: 'c1', courseName: 'IS230', email: 'e@x.com'),
            ],
          )..fetchCoursesError = CoursesFailure('offline'),
        );

        await tester.tap(find.text('14'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Midterm'), findsOneWidget);
        expect(find.text('IS230'), findsNothing);
      },
    );

    testWidgets('shows the reminder summary when one is set', (tester) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(
          events: [
            event(
              day: 14,
              reminderEnabled: true,
              reminderBefore: 3,
              reminderUnit: ReminderUnit.hours,
            ),
          ],
        ),
      );

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('reminder 3 hours before'),
        findsOneWidget,
      );
    });

    testWidgets('omits the reminder clause when there is none', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(events: [event(day: 14)]),
      );

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();

      expect(find.textContaining('reminder'), findsNothing);
    });

    testWidgets('closes via the close chip', (tester) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(events: [event(day: 14)]),
      );

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();

      expect(find.text('May 14, 2026'), findsNothing);
    });
  });

  group('delete', () {
    Future<void> openDeleteDialog(
      WidgetTester tester,
      FakeCalendarService service,
    ) async {
      await pumpCalendar(tester, service: service);
      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Delete event'));
      await tester.pumpAndSettle();
    }

    testWidgets('the confirm names the reminder when the event has one', (
      tester,
    ) async {
      await openDeleteDialog(
        tester,
        FakeCalendarService(
          events: [
            event(
              day: 14,
              reminderEnabled: true,
              reminderBefore: 1,
              reminderUnit: ReminderUnit.days,
            ),
          ],
        ),
      );

      expect(find.text('Delete this event?'), findsOneWidget);
      expect(
        find.textContaining(kDeleteBodyWithReminder),
        findsOneWidget,
      );
      expect(find.textContaining(kDeleteBodyTail), findsOneWidget);
    });

    testWidgets('the confirm omits the reminder when there is none', (
      tester,
    ) async {
      await openDeleteDialog(
        tester,
        FakeCalendarService(events: [event(day: 14)]),
      );

      expect(find.textContaining(kDeleteBodyNoReminder), findsOneWidget);
      expect(find.textContaining(kDeleteBodyWithReminder), findsNothing);
    });

    testWidgets('"Keep it" cancels without deleting', (tester) async {
      final service = FakeCalendarService(events: [event(day: 14)]);
      await openDeleteDialog(tester, service);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(service.deletedEventIds, isEmpty);
      expect(find.text('Midterm'), findsOneWidget);
    });

    testWidgets('"Delete event" deletes and notifies Home', (tester) async {
      final service = FakeCalendarService(events: [event(day: 14)]);
      var notified = 0;
      await pumpCalendar(
        tester,
        service: service,
        onEventsChanged: () => notified++,
      );

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Delete event'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();

      expect(service.deletedEventIds, ['e1']);
      expect(notified, 1);
    });

    testWidgets('a delete failure shows the message and keeps the event', (
      tester,
    ) async {
      final service = FakeCalendarService(
        events: [event(day: 14)],
        deleteError: CalendarFailure('Could not delete that event.'),
      );
      await openDeleteDialog(tester, service);

      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();

      expect(find.text('Could not delete that event.'), findsOneWidget);
      expect(service.deletedEventIds, isEmpty);
    });
  });

  group('load failure', () {
    testWidgets('shows the error banner and retries', (tester) async {
      final service = FakeCalendarService(
        loadError: CalendarFailure("Couldn't load your calendar."),
      );
      await pumpCalendar(tester, service: service);

      expect(find.text("Couldn't load your calendar"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      final before = service.watchedMonths.length;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(service.watchedMonths.length, greaterThan(before));
    });
  });
}

/// A service whose month stream never emits *and* never closes, so the
/// screen stays in ConnectionState.waiting and the spinner can be observed.
/// `Stream.empty()` would close immediately and land on `done` instead.
class _PendingCalendarService extends FakeCalendarService {
  @override
  Stream<List<CalendarEvent>> watchEventsForMonth(String uid, DateTime month) =>
      StreamController<List<CalendarEvent>>().stream;
}
