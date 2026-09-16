import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/screens/calendar/add_event_screen.dart';
import 'package:tadarab_app/services/calendar_service.dart';

import '../../helpers/fake_calendar_service.dart';
import '../../helpers/fake_home_data_service.dart';
import '../../helpers/fake_reminder_scheduler.dart';

void main() {
  final now = DateTime(2026, 5, 3, 9, 0);
  final aCourse = Course(
    courseId: 'c1',
    courseName: 'IS230',
    color: '#10B981',
    email: 'student@example.com',
  );

  late FakeCalendarService calendarService;
  late FakeReminderScheduler scheduler;
  bool? poppedResult;

  Future<void> pumpAddEvent(
    WidgetTester tester, {
    List<Course> courses = const [],
    FakeCalendarService? service,
  }) async {
    calendarService = service ?? FakeCalendarService();
    scheduler = FakeReminderScheduler();
    poppedResult = null;

    // The form is a tall phone screen. The 800x600 test default cuts it off
    // below the reminder toggle, so give the test a surface that fits the
    // whole form and every control is directly tappable. It is wider than a
    // real phone because the Material time picker's OK button overflows a
    // 420px-wide surface and becomes untappable.
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Builder(
              builder: (innerContext) => ElevatedButton(
                onPressed: () async {
                  poppedResult = await Navigator.of(innerContext).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AddEventScreen(
                        uid: 'uid-1',
                        calendarService: calendarService,
                        homeDataService: FakeHomeDataService(courses: courses),
                        reminderScheduler: scheduler,
                        initialDate: DateTime(2026, 5, 1),
                        now: now,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Picks [day] in May 2026 through the real Material date picker.
  Future<void> pickDate(WidgetTester tester, int day) async {
    await tapVisible(tester, find.text('Select a date'));
    await tester.tap(find.text('$day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  /// Confirms the time picker at its default, which the screen seeds to
  /// 12:00 PM — the same time the mockup shows.
  Future<void> pickTime(WidgetTester tester) async {
    await tapVisible(tester, find.text('Select a time'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  group('initial state (05_add_event_no_course)', () {
    testWidgets('shows empty placeholders, the colour presets, reminder off', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      expect(find.text('Add Event'), findsOneWidget);
      expect(find.text('e.g. Midterm Exam, Assignment 1'), findsOneWidget);
      expect(find.text('No course selected'), findsOneWidget);
      expect(find.text('Event Color'), findsOneWidget);
      expect(find.text('Select a date'), findsOneWidget);
      expect(find.text('Select a time'), findsOneWidget);
      expect(find.text('Enable Reminder'), findsOneWidget);
      expect(find.text('Save Event'), findsOneWidget);

      // Reminder is off, so the amount+unit row is not shown yet.
      expect(find.byKey(const ValueKey('reminder-unit')), findsNothing);
    });

    testWidgets('pre-selects green, the same default the model stores', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      final green = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byIcon(Icons.check),
              matching: find.byType(Semantics),
            )
            .first,
      );

      expect(green.properties.label, 'Event color #10B981');
      expect(green.properties.selected, isTrue);
    });

    testWidgets('offers a custom colour beyond the four presets', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      expect(find.bySemanticsLabel('Custom event color'), findsOneWidget);
    });
  });

  group('course selection (06_add_event_with_course)', () {
    testWidgets('picking a course replaces the colour picker with its chip', (
      tester,
    ) async {
      await pumpAddEvent(tester, courses: [aCourse]);

      await tapVisible(tester, find.text('No course selected'));
      await tester.tap(find.text('IS230').last);
      await tester.pumpAndSettle();

      expect(find.text('Event will use this course color'), findsOneWidget);
      expect(find.text('Event Color'), findsNothing);
    });

    testWidgets('saving with a course stores its id and colour', (
      tester,
    ) async {
      await pumpAddEvent(tester, courses: [aCourse]);

      await tester.enterText(find.byKey(const ValueKey('event-name')), 'Midterm');
      await tapVisible(tester, find.text('No course selected'));
      await tester.tap(find.text('IS230').last);
      await tester.pumpAndSettle();
      await pickDate(tester, 5);
      await pickTime(tester);
      await tapVisible(tester, find.text('Save Event'));

      final saved = calendarService.addedEvents.single;
      expect(saved.courseId, 'c1');
      expect(saved.color, '#10B981');
    });

    testWidgets('an empty course list still allows saving without one', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await tapVisible(tester, find.text('No course selected'));

      expect(
        find.text(
          "You haven't added any courses yet. Events can still be saved without one.",
        ),
        findsOneWidget,
      );
    });
  });

  group('validation', () {
    testWidgets('an empty name is rejected with a message, not a silent no-op', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await tapVisible(tester, find.text('Save Event'));

      expect(find.text('Event name is required'), findsOneWidget);
      expect(calendarService.addedEvents, isEmpty);
    });

    testWidgets('a missing date and time are both called out', (tester) async {
      await pumpAddEvent(tester);

      await tester.enterText(find.byKey(const ValueKey('event-name')), 'Midterm');
      await tapVisible(tester, find.text('Save Event'));

      expect(find.text('Pick a date for this event'), findsOneWidget);
      expect(find.text('Pick a time for this event'), findsOneWidget);
      expect(calendarService.addedEvents, isEmpty);
    });

    testWidgets('the name error clears as soon as the student types', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await tapVisible(tester, find.text('Save Event'));
      expect(find.text('Event name is required'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('event-name')), 'M');
      await tester.pumpAndSettle();

      expect(find.text('Event name is required'), findsNothing);
    });
  });

  group('saving', () {
    testWidgets('writes the event and pops true', (tester) async {
      await pumpAddEvent(tester);

      await tester.enterText(find.byKey(const ValueKey('event-name')), 'Midterm');
      await pickDate(tester, 5);
      await pickTime(tester);
      await tapVisible(tester, find.text('Save Event'));

      final saved = calendarService.addedEvents.single;
      expect(saved.eventName, 'Midterm');
      expect(saved.eventDate, DateTime(2026, 5, 5));
      expect(saved.eventTime, '12:00');
      expect(saved.reminderEnabled, isFalse);
      expect(saved.reminderBefore, isNull);
      expect(saved.reminderUnit, isNull);
      expect(poppedResult, isTrue);
    });

    testWidgets('a save failure shows the banner and stays on the form', (
      tester,
    ) async {
      await pumpAddEvent(
        tester,
        service: FakeCalendarService(
          addError: CalendarFailure('Network unavailable.'),
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('event-name')), 'Midterm');
      await pickDate(tester, 5);
      await pickTime(tester);
      await tapVisible(tester, find.text('Save Event'));

      expect(find.text("Couldn't save your event"), findsOneWidget);
      expect(find.text('Network unavailable.'), findsOneWidget);
      expect(find.text('Save Event'), findsOneWidget);
      expect(poppedResult, isNull);
    });
  });

  group('reminder', () {
    testWidgets('enabling it reveals the amount and unit row', (tester) async {
      await pumpAddEvent(tester);

      await tapVisible(tester, find.byType(Switch));

      expect(find.byKey(const ValueKey('reminder-unit')), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);
    });

    testWidgets('the unit label pluralises with the amount', (tester) async {
      await pumpAddEvent(tester);

      await tapVisible(tester, find.byType(Switch));
      expect(find.text('Day'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('reminder-amount')), '3');
      await tester.pumpAndSettle();

      expect(find.text('Days'), findsOneWidget);
      expect(find.text('Day'), findsNothing);
    });

    testWidgets('saving with a reminder stores it and schedules it', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await tester.enterText(find.byKey(const ValueKey('event-name')), 'Midterm');
      await pickDate(tester, 5);
      await pickTime(tester);
      await tapVisible(tester, find.byType(Switch));
      await tester.enterText(find.byKey(const ValueKey('reminder-amount')), '2');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Save Event'));

      final saved = calendarService.addedEvents.single;
      expect(saved.reminderEnabled, isTrue);
      expect(saved.reminderBefore, 2);
      expect(saved.reminderUnit, ReminderUnit.days);

      // Scheduled against the Firestore-assigned ID, not the empty
      // placeholder the form builds the event with.
      expect(scheduler.scheduled.single.eventId, 'new-event-id');
    });

    testWidgets('no reminder is scheduled when the toggle is off', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await tester.enterText(find.byKey(const ValueKey('event-name')), 'Midterm');
      await pickDate(tester, 5);
      await pickTime(tester);
      await tapVisible(tester, find.text('Save Event'));

      expect(scheduler.scheduled, isEmpty);
    });
  });
}
