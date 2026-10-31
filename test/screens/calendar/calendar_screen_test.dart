import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/screens/calendar/calendar_screen.dart';
import 'package:tadarab_app/screens/calendar/widgets/calendar_header.dart';
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
    bool active = true,
  }) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            uid: 'uid-1',
            active: active,
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
              active: true,
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

  group('Add Event date picker', () {
    /// Taps the Add Event pill, opens its date field, then accepts the
    /// picker's own pre-highlighted day without choosing one — revealing
    /// what it opened on.
    Future<void> openAddEventAndAcceptDate(WidgetTester tester) async {
      await tester.tap(find.text('Add Event'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('event-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'opens on today even while the current month is shown (not the '
      '1st) — regression test for passing the displayed month\'s 1st '
      'as the initial date',
      (tester) async {
        await pumpCalendar(tester);

        await openAddEventAndAcceptDate(tester);

        // `now` is May 3, 2026.
        expect(find.text('May 3, 2026'), findsOneWidget);
      },
    );

    testWidgets(
      'opens on today, not the 1st, even while browsing a different '
      'month (e.g. next month)',
      (tester) async {
        await pumpCalendar(tester);

        await tester.tap(find.bySemanticsLabel('Next month'));
        await tester.pumpAndSettle();
        expect(find.text('June 2026'), findsOneWidget);

        await openAddEventAndAcceptDate(tester);

        // Still today (May 3), not June 1st.
        expect(find.text('May 3, 2026'), findsOneWidget);
      },
    );
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

  group('reload when becoming the active tab', () {
    /// Mirrors how HomeScreen embeds this screen (and the Courses tab) in a
    /// persistent IndexedStack: the widget stays mounted, only `active`
    /// flips — via a "toggle active" button, same idiom
    /// `courses_list_screen_test.dart` uses for the identical problem.
    Future<Future<void> Function()> pumpToggleable(
      WidgetTester tester, {
      required FakeCalendarService calendarService,
      required FakeCoursesService coursesService,
      required bool Function() isActive,
      required void Function(bool) setActive,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () => setState(() => setActive(!isActive())),
                    child: const Text('toggle active'),
                  ),
                  Expanded(
                    child: CalendarScreen(
                      uid: 'uid-1',
                      active: isActive(),
                      calendarService: calendarService,
                      coursesService: coursesService,
                      now: now,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return () async {
        await tester.tap(find.text('toggle active'));
        await tester.pumpAndSettle();
      };
    }

    testWidgets(
      'a course added while inactive appears in Add Event\'s dropdown '
      'once this tab becomes active again',
      (tester) async {
        final coursesService = FakeCoursesService();
        var active = false;
        final toggle = await pumpToggleable(
          tester,
          calendarService: FakeCalendarService(),
          coursesService: coursesService,
          isActive: () => active,
          setActive: (v) => active = v,
        );

        // "Created elsewhere" (the Courses tab) while this tab sat inactive.
        coursesService.courses.add(
          Course(
            courseId: 'c1',
            courseName: 'IS230',
            color: '#16A34A',
            email: 'e',
          ),
        );
        await toggle();

        await tester.tap(find.text('Add Event'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('course-field')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('course-option-IS230')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a course deleted while inactive disappears from Add Event\'s '
      'dropdown once this tab becomes active again',
      (tester) async {
        final coursesService = FakeCoursesService(
          courses: [
            Course(
              courseId: 'c1',
              courseName: 'IS230',
              color: '#16A34A',
              email: 'e',
            ),
          ],
        );
        var active = true;
        final toggle = await pumpToggleable(
          tester,
          calendarService: FakeCalendarService(),
          coursesService: coursesService,
          isActive: () => active,
          setActive: (v) => active = v,
        );

        await toggle(); // -> inactive
        coursesService.courses.removeWhere((c) => c.courseId == 'c1');
        await toggle(); // -> active again

        await tester.tap(find.text('Add Event'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('course-field')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('course-option-IS230')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Add Event\'s colour exclusion uses the fresh course colours once '
      'this tab becomes active again',
      (tester) async {
        final coursesService = FakeCoursesService();
        var active = false;
        final toggle = await pumpToggleable(
          tester,
          calendarService: FakeCalendarService(),
          coursesService: coursesService,
          isActive: () => active,
          setActive: (v) => active = v,
        );

        // A non-preset pool colour — only excluded from the random default
        // once the course list genuinely reflects it.
        coursesService.courses.add(
          Course(
            courseId: 'c1',
            courseName: 'Teal course',
            color: '#0D9488',
            email: 'e',
          ),
        );
        await toggle();

        await tester.tap(find.text('Add Event'));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Color #0D9488'), findsNothing);
      },
    );

    testWidgets(
      'the day sheet shows the right course name once this tab becomes '
      'active again, for an event already linked to a course added while '
      'inactive',
      (tester) async {
        final coursesService = FakeCoursesService();
        var active = false;
        final toggle = await pumpToggleable(
          tester,
          calendarService: FakeCalendarService(
            events: [event(day: 14, courseId: 'c1')],
          ),
          coursesService: coursesService,
          isActive: () => active,
          setActive: (v) => active = v,
        );

        // Before the course exists, the day sheet omits the course line —
        // the same "course not found" fallback a deleted course gets.
        await tester.tap(find.text('14'));
        await tester.pumpAndSettle();
        expect(find.text('IS230'), findsNothing);
        await tester.tap(find.bySemanticsLabel('Close'));
        await tester.pumpAndSettle();

        coursesService.courses.add(
          Course(
            courseId: 'c1',
            courseName: 'IS230',
            color: '#16A34A',
            email: 'e',
          ),
        );
        await toggle();

        await tester.tap(find.text('14'));
        await tester.pumpAndSettle();

        expect(find.text('IS230'), findsOneWidget);
      },
    );

    testWidgets('staying active (or going inactive) does not reload', (
      tester,
    ) async {
      final coursesService = FakeCoursesService();

      Widget buildScreen() => MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            uid: 'uid-1',
            active: true,
            calendarService: FakeCalendarService(),
            coursesService: coursesService,
            now: now,
          ),
        ),
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(coursesService.fetchCoursesCalls, 1);

      // Rebuilding with the same active:true shouldn't trigger a refetch.
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(coursesService.fetchCoursesCalls, 1);
    });
  });

  group('status bar / safe area', () {
    testWidgets(
      'the header background reaches the top of the screen under a real '
      'top inset (no white strip above it), and its content sits below '
      'the status-bar inset',
      (tester) async {
        const insets = EdgeInsets.only(top: 48);
        tester.view.physicalSize = const Size(412, 892);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                padding: insets,
                viewPadding: insets,
              ),
              child: Scaffold(
                body: CalendarScreen(
                  uid: 'uid-1',
                  active: true,
                  calendarService: FakeCalendarService(),
                  coursesService: FakeCoursesService(),
                  now: now,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.getRect(find.byType(CalendarHeader)).top, 0);

        final titleRect = tester.getRect(find.text('Calendar'));
        expect(titleRect.top, greaterThan(48));
      },
    );
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
