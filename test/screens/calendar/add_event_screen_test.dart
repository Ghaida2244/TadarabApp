import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/screens/calendar/add_event_screen.dart';
import 'package:tadarab_app/services/calendar_service.dart';
import 'package:tadarab_app/theme/app_theme.dart';

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
    FakeReminderScheduler? reminderScheduler,
  }) async {
    calendarService = service ?? FakeCalendarService();
    scheduler = reminderScheduler ?? FakeReminderScheduler();
    poppedResult = null;

    // The form is a tall phone screen. The 800x600 test default cuts it off
    // below the reminder toggle, so give the test a phone-width surface tall
    // enough that the whole form and both picker sheets are directly
    // tappable.
    await tester.binding.setSurfaceSize(const Size(420, 1600));
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

  /// Picks [day] of the month the date sheet opens on (May 2026) by tapping
  /// it in the custom Figure 98 sheet, which closes on selection.
  Future<void> pickDate(WidgetTester tester, int day) async {
    await tapVisible(tester, find.text('Select a date'));
    await tapVisible(tester, find.byKey(ValueKey('picker-day-$day')));
  }

  /// Picks a time in the custom Figure 99 sheet and confirms it. With no
  /// arguments it confirms the sheet's 12:00 PM default.
  Future<void> pickTime(
    WidgetTester tester, {
    int? hour,
    int? minute,
    bool? isPm,
  }) async {
    await tapVisible(tester, find.text('Select a time'));
    if (hour != null) {
      await tapVisible(tester, find.byKey(ValueKey('hour-$hour')));
    }
    if (minute != null) {
      await tapVisible(tester, find.byKey(ValueKey('minute-$minute')));
    }
    if (isPm != null) {
      await tapVisible(
        tester,
        find.byKey(ValueKey(isPm ? 'period-pm' : 'period-am')),
      );
    }
    await tapVisible(tester, find.text('✓ Confirm'));
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

  group('event name length (SRS: VARCHAR(100))', () {
    testWidgets('input stops at 100 characters and saves at most 100', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await tester.enterText(
        find.byKey(const ValueKey('event-name')),
        'a' * 150,
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('event-name')),
      );
      expect(field.controller!.text.length, kEventNameMaxLength);

      await pickDate(tester, 5);
      await pickTime(tester);
      await tapVisible(tester, find.text('Save Event'));

      expect(calendarService.addedEvents.single.eventName.length, 100);
    });

    testWidgets('a name of exactly 100 characters is kept whole', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      final exactly100 = 'b' * 100;

      await tester.enterText(
        find.byKey(const ValueKey('event-name')),
        exactly100,
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('event-name')),
      );
      expect(field.controller!.text, exactly100);
    });
  });

  group('date picker sheet (SRS Figure 98)', () {
    BoxDecoration dayDecoration(WidgetTester tester, int day) {
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byKey(ValueKey('picker-day-$day')),
          matching: find.byType(Container),
        ),
      );
      return box.decoration! as BoxDecoration;
    }

    testWidgets('is the custom sheet, not the Material date picker', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await tapVisible(tester, find.text('Select a date'));

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.text('May 2026'), findsOneWidget);
      expect(find.text('Su'), findsOneWidget);
      expect(find.text('Sa'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('outlines today in red', (tester) async {
      await pumpAddEvent(tester);
      await tapVisible(tester, find.text('Select a date'));

      final today = dayDecoration(tester, 3);
      expect((today.border! as Border).top.color, AppColors.red);
      expect(dayDecoration(tester, 4).border, isNull);
    });

    testWidgets('tapping a day fills the form and closes the sheet', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await pickDate(tester, 5);

      expect(find.text('May 5, 2026'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('reopening highlights the day already chosen', (tester) async {
      await pumpAddEvent(tester);
      await pickDate(tester, 5);

      await tapVisible(tester, find.text('May 5, 2026'));

      expect(dayDecoration(tester, 5).color, const Color(0xFFC7CBD2));
      expect(dayDecoration(tester, 6).color, isNull);
    });

    testWidgets('Cancel leaves the date unset', (tester) async {
      await pumpAddEvent(tester);
      await tapVisible(tester, find.text('Select a date'));

      await tapVisible(tester, find.text('Cancel'));

      expect(find.text('Select a date'), findsOneWidget);
    });

    testWidgets('pages to the next month', (tester) async {
      await pumpAddEvent(tester);
      await tapVisible(tester, find.text('Select a date'));

      await tapVisible(tester, find.bySemanticsLabel('Next month'));
      await tapVisible(tester, find.byKey(const ValueKey('picker-day-10')));

      expect(find.text('June 10, 2026'), findsOneWidget);
    });
  });

  group('past dates', () {
    testWidgets('a day earlier this month is selectable', (tester) async {
      // Today is May 3; May 1 is in the past.
      await pumpAddEvent(tester);

      await pickDate(tester, 1);

      expect(find.text('May 1, 2026'), findsOneWidget);
    });

    testWidgets('an earlier month is reachable and selectable', (tester) async {
      await pumpAddEvent(tester);
      await tapVisible(tester, find.text('Select a date'));

      await tapVisible(tester, find.bySemanticsLabel('Previous month'));
      expect(find.text('April 2026'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('picker-day-20')));

      expect(find.text('April 20, 2026'), findsOneWidget);
    });

    testWidgets('a past event without a reminder saves normally', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await tester.enterText(
        find.byKey(const ValueKey('event-name')),
        'Quiz 1',
      );
      await pickDate(tester, 1);
      await pickTime(tester);
      await tapVisible(tester, find.text('Save Event'));

      expect(calendarService.addedEvents.single.eventDate, DateTime(2026, 5, 1));
      expect(poppedResult, isTrue);
    });
  });

  group('time picker sheet (SRS Figure 99)', () {
    String preview(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const ValueKey('time-preview'))).data!;

    testWidgets('is the custom sheet, not the Material time picker', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await tapVisible(tester, find.text('Select a time'));

      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.text('Select Time'), findsOneWidget);
      expect(preview(tester), '12:00 PM');
      expect(find.text('Hour'), findsOneWidget);
      expect(find.text('Minute'), findsOneWidget);
      expect(find.text('Period'), findsOneWidget);
      expect(find.text('✓ Confirm'), findsOneWidget);
    });

    testWidgets('offers hours 1–12 and minutes in 5-minute steps', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await tapVisible(tester, find.text('Select a time'));

      for (var hour = 1; hour <= 12; hour++) {
        expect(find.byKey(ValueKey('hour-$hour')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('hour-0')), findsNothing);
      expect(find.byKey(const ValueKey('hour-13')), findsNothing);
      for (var minute = 0; minute < 60; minute += 5) {
        expect(find.byKey(ValueKey('minute-$minute')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('minute-1')), findsNothing);
    });

    testWidgets('the preview updates live, before Confirm', (tester) async {
      await pumpAddEvent(tester);
      await tapVisible(tester, find.text('Select a time'));

      await tapVisible(tester, find.byKey(const ValueKey('hour-3')));
      await tapVisible(tester, find.byKey(const ValueKey('minute-45')));
      await tapVisible(tester, find.byKey(const ValueKey('period-am')));

      expect(preview(tester), '3:45 AM');
    });

    testWidgets('Confirm fills the form and stores 24-hour time', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await tester.enterText(
        find.byKey(const ValueKey('event-name')),
        'Midterm',
      );
      await pickDate(tester, 5);

      await pickTime(tester, hour: 3, minute: 45, isPm: true);
      expect(find.text('3:45 PM'), findsOneWidget);

      await tapVisible(tester, find.text('Save Event'));
      expect(calendarService.addedEvents.single.eventTime, '15:45');
    });

    testWidgets('12 AM is stored as midnight, not noon', (tester) async {
      await pumpAddEvent(tester);
      await tester.enterText(
        find.byKey(const ValueKey('event-name')),
        'Midterm',
      );
      await pickDate(tester, 5);

      await pickTime(tester, hour: 12, minute: 30, isPm: false);
      await tapVisible(tester, find.text('Save Event'));

      expect(calendarService.addedEvents.single.eventTime, '00:30');
    });

    testWidgets('closing with ✕ leaves the time unset', (tester) async {
      await pumpAddEvent(tester);
      await tapVisible(tester, find.text('Select a time'));

      await tapVisible(tester, find.bySemanticsLabel('Close'));

      expect(find.text('Select a time'), findsOneWidget);
    });

    testWidgets('reopening starts from the time already chosen', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await pickTime(tester, hour: 9, minute: 15, isPm: false);

      await tapVisible(tester, find.text('9:15 AM'));

      expect(preview(tester), '9:15 AM');
    });
  });

  group('reminder that has already passed', () {
    Future<void> fillTodayAt10Am(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const ValueKey('event-name')),
        'Midterm',
      );
      // Today (May 3, 09:00) at 10:00 AM — the event is still ahead.
      await pickDate(tester, 3);
      await pickTime(tester, hour: 10, minute: 0, isPm: false);
    }

    testWidgets('a lead time that has passed is called out, not skipped', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await fillTodayAt10Am(tester);
      // 1 day before 10:00 today was yesterday.
      await tapVisible(tester, find.byType(Switch));

      await tapVisible(tester, find.text('Save Event'));

      expect(find.text(kReminderPassedMessage), findsOneWidget);
      expect(calendarService.addedEvents, isEmpty);
      expect(scheduler.scheduled, isEmpty);
      expect(poppedResult, isNull);
    });

    testWidgets('a reminder on a past event is called out too', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await tester.enterText(
        find.byKey(const ValueKey('event-name')),
        'Quiz 1',
      );
      await pickDate(tester, 1);
      await pickTime(tester);
      await tapVisible(tester, find.byType(Switch));

      await tapVisible(tester, find.text('Save Event'));

      expect(find.text(kReminderPassedMessage), findsOneWidget);
      expect(calendarService.addedEvents, isEmpty);
    });

    testWidgets('shortening the lead time clears it and saves', (tester) async {
      await pumpAddEvent(tester);
      await fillTodayAt10Am(tester);
      await tapVisible(tester, find.byType(Switch));
      await tapVisible(tester, find.text('Save Event'));
      expect(find.text(kReminderPassedMessage), findsOneWidget);

      // 30 minutes before 10:00 is 09:30, still ahead of 09:00.
      await tester.enterText(
        find.byKey(const ValueKey('reminder-amount')),
        '30',
      );
      await tester.pumpAndSettle();
      expect(find.text(kReminderPassedMessage), findsNothing);
      await tapVisible(tester, find.byKey(const ValueKey('reminder-unit')));
      await tapVisible(tester, find.text('Minutes'));
      await tapVisible(tester, find.text('Save Event'));

      final saved = calendarService.addedEvents.single;
      expect(saved.reminderBefore, 30);
      expect(saved.reminderUnit, ReminderUnit.minutes);
      expect(scheduler.scheduled, hasLength(1));
    });

    testWidgets('turning the reminder off clears it and saves without one', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await fillTodayAt10Am(tester);
      await tapVisible(tester, find.byType(Switch));
      await tapVisible(tester, find.text('Save Event'));

      await tapVisible(tester, find.byType(Switch));
      expect(find.text(kReminderPassedMessage), findsNothing);
      await tapVisible(tester, find.text('Save Event'));

      expect(calendarService.addedEvents.single.reminderEnabled, isFalse);
      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('reminder that cannot be scheduled', () {
    Future<void> saveWithReminder(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const ValueKey('event-name')),
        'Midterm',
      );
      await pickDate(tester, 5);
      await pickTime(tester);
      await tapVisible(tester, find.byType(Switch));
      await tapVisible(tester, find.text('Save Event'));
    }

    testWidgets('asks for notification permission when saving a reminder', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await saveWithReminder(tester);

      expect(scheduler.permissionRequests, 1);
      expect(scheduler.scheduled, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('does not ask for permission when there is no reminder', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await tester.enterText(
        find.byKey(const ValueKey('event-name')),
        'Midterm',
      );
      await pickDate(tester, 5);
      await pickTime(tester);

      await tapVisible(tester, find.text('Save Event'));

      expect(scheduler.permissionRequests, 0);
    });

    testWidgets('declined permission still saves, and says so', (
      tester,
    ) async {
      await pumpAddEvent(
        tester,
        reminderScheduler: FakeReminderScheduler(permissionGranted: false),
      );

      await saveWithReminder(tester);

      expect(calendarService.addedEvents, hasLength(1));
      expect(scheduler.scheduled, isEmpty);
      expect(poppedResult, isTrue);
      expect(find.text(kReminderPermissionDeniedMessage), findsOneWidget);
    });

    testWidgets('declined permission stores the reminder as off', (
      tester,
    ) async {
      await pumpAddEvent(
        tester,
        reminderScheduler: FakeReminderScheduler(permissionGranted: false),
      );

      await saveWithReminder(tester);

      final saved = calendarService.addedEvents.single;
      expect(saved.reminderEnabled, isFalse);
      expect(saved.reminderBefore, isNull);
      expect(saved.reminderUnit, isNull);
    });

    testWidgets('a platform refusal still saves, and says so', (tester) async {
      await pumpAddEvent(
        tester,
        reminderScheduler: FakeReminderScheduler(scheduleResult: false),
      );

      await saveWithReminder(tester);

      expect(calendarService.addedEvents, hasLength(1));
      expect(poppedResult, isTrue);
      expect(find.text(kReminderNotScheduledMessage), findsOneWidget);
    });

    testWidgets('a platform refusal stores the reminder as off', (
      tester,
    ) async {
      await pumpAddEvent(
        tester,
        reminderScheduler: FakeReminderScheduler(scheduleResult: false),
      );

      await saveWithReminder(tester);

      final saved = calendarService.addedEvents.single;
      expect(saved.reminderEnabled, isFalse);
      expect(saved.reminderBefore, isNull);
      expect(saved.reminderUnit, isNull);
    });

    testWidgets('a scheduled reminder is stored as on, under the same ID', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await saveWithReminder(tester);

      final saved = calendarService.addedEvents.single;
      expect(saved.reminderEnabled, isTrue);
      expect(saved.reminderBefore, isNotNull);
      // The notification's handle and the document ID must match, or
      // deleting the event could never cancel its reminder.
      expect(saved.eventId, 'new-event-id');
      expect(scheduler.scheduled.single.eventId, saved.eventId);
    });

    testWidgets('a failed save cancels the reminder it just scheduled', (
      tester,
    ) async {
      await pumpAddEvent(
        tester,
        service: FakeCalendarService(
          addError: CalendarFailure("Couldn't save your event."),
        ),
      );

      await saveWithReminder(tester);

      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.cancelled, ['new-event-id']);
      expect(poppedResult, isNull);
      expect(find.text("Couldn't save your event."), findsOneWidget);
    });
  });
}
