import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/screens/calendar/add_event_screen.dart';
import 'package:tadarab_app/screens/calendar/calendar_styles.dart';
import 'package:tadarab_app/screens/calendar/widgets/reminder_card.dart';
import 'package:tadarab_app/services/calendar_service.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/app_button.dart';

import '../../helpers/fake_calendar_service.dart';
import '../../helpers/fake_reminder_scheduler.dart';

void main() {
  // "Now" is 9:00 AM on Sunday 3 May 2026, so every reminder assertion is
  // deterministic. The date picker opens on May 2026.
  final now = DateTime(2026, 5, 3, 9, 0);

  final aCourse = Course(
    courseId: 'c1',
    courseName: 'IS230',
    color: '#16A34A',
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

    // Tall enough for the whole form, and 600 wide because Material's time
    // picker overflows a phone-width surface — the same reason this suite
    // was 600 wide before the custom pickers were introduced.
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (innerContext) => ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.of(innerContext).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AddEventScreen(
                      uid: 'uid-1',
                      calendarService: calendarService,
                      courses: courses,
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
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// The reminder amount box's current contents.
  String amountText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const ValueKey('reminder-amount')))
      .controller!
      .text;

  Future<void> typeAmount(WidgetTester tester, String value) async {
    await tester.enterText(
      find.byKey(const ValueKey('reminder-amount')),
      value,
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterName(WidgetTester tester, [String name = 'Midterm']) async {
    await tester.enterText(find.byKey(const ValueKey('event-name')), name);
    await tester.pumpAndSettle();
  }

  /// Picks [day] of May 2026 through Flutter's date picker.
  Future<void> pickDate(WidgetTester tester, int day) async {
    await tapVisible(tester, find.byKey(const ValueKey('event-date')));
    await tapVisible(tester, find.text('$day'));
    await tapVisible(tester, find.text('OK'));
  }

  /// Accepts the time picker's default (9:00 AM, from `pickEventTime`).
  /// The dial itself isn't driven — every assertion here only needs *a*
  /// time, and the wrapper's default keeps that deterministic.
  Future<void> pickDefaultTime(WidgetTester tester) async {
    await tapVisible(tester, find.byKey(const ValueKey('event-time')));
    await tapVisible(tester, find.text('OK'));
  }

  /// Fills name + date + time so the form is valid and Save is live.
  Future<void> fillValidForm(WidgetTester tester, {int day = 14}) async {
    await enterName(tester);
    await pickDate(tester, day);
    await pickDefaultTime(tester);
  }

  group('initial state', () {
    testWidgets('shows all-caps labels, placeholders and a reminder off', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      expect(find.text('Add Event'), findsOneWidget);
      expect(find.text('EVENT NAME'), findsOneWidget);
      expect(find.text('EVENT COLOR'), findsOneWidget);
      expect(find.text('DATE'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('e.g. Midterm exam, Assignment 1'), findsOneWidget);
      expect(find.text('No course selected'), findsOneWidget);
      expect(find.text('Select a date'), findsOneWidget);
      expect(find.text('Select a time'), findsOneWidget);
      expect(find.text('Enable reminder'), findsOneWidget);
      // The reminder controls only appear once the toggle is on.
      expect(find.byKey(const ValueKey('reminder-amount')), findsNothing);
    });

    testWidgets('the COURSE label carries its optional half', (tester) async {
      await pumpAddEvent(tester);

      final label = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.textSpan?.toPlainText() == 'COURSE · OPTIONAL',
        ),
      );
      expect(label.textSpan, isNotNull);
    });
  });

  group('save gating', () {
    testWidgets('Save is disabled with the name reason first', (tester) async {
      await pumpAddEvent(tester);

      expect(find.text(kSaveReasonName), findsOneWidget);
      await tapVisible(tester, find.text('Save Event'));
      expect(calendarService.addedEvents, isEmpty);
    });

    testWidgets('the reason advances to the date once a name is typed', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await enterName(tester);

      expect(find.text(kSaveReasonName), findsNothing);
      expect(find.text(kSaveReasonDate), findsOneWidget);
    });

    testWidgets('then to the time once a date is picked', (tester) async {
      await pumpAddEvent(tester);
      await enterName(tester);
      await pickDate(tester, 14);

      expect(find.text(kSaveReasonDate), findsNothing);
      expect(find.text(kSaveReasonTime), findsOneWidget);
    });

    testWidgets('the reason disappears once the form is valid', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await fillValidForm(tester);

      expect(find.byKey(const ValueKey('save-reason')), findsNothing);
    });

    testWidgets('a disabled Save is pink with no shadow', (tester) async {
      await pumpAddEvent(tester);

      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.onPressed, isNull);
      expect(button.disabledBackgroundColor, AppColors.disabledRedFill);
      expect(button.disabledRemovesShadow, isTrue);
    });

    testWidgets('the reason is exposed to screen readers as a hint', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byType(AppButton),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.hint, kSaveReasonName);
    });
  });

  group('event name', () {
    testWidgets('is capped at the SRS 100-character limit', (tester) async {
      await pumpAddEvent(tester);
      await enterName(tester, 'A' * 150);

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('event-name')),
      );
      expect(field.controller!.text.length, kEventNameMaxLength);
    });

    testWidgets('a whitespace-only name does not satisfy the gate', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await enterName(tester, '    ');

      expect(find.text(kSaveReasonName), findsOneWidget);
    });
  });

  group('course dropdown', () {
    testWidgets('opens inline and lists the student\'s courses', (
      tester,
    ) async {
      await pumpAddEvent(tester, courses: [aCourse]);

      await tapVisible(tester, find.byKey(const ValueKey('course-field')));

      expect(
        find.byKey(const ValueKey('course-option-IS230')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('course-option-No course selected')),
        findsOneWidget,
      );
    });

    testWidgets('picking a course swaps the swatches for the colour chip', (
      tester,
    ) async {
      await pumpAddEvent(tester, courses: [aCourse]);

      expect(find.text('EVENT COLOR'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('course-field')));
      await tapVisible(tester, find.byKey(const ValueKey('course-option-IS230')));

      expect(find.text('EVENT COLOR'), findsNothing);
      expect(find.text('Event will use this course color'), findsOneWidget);
      // Once in the course field, once in the colour chip below it.
      expect(find.text('IS230'), findsNWidgets(2));
    });

    testWidgets('an empty course list still explains itself', (tester) async {
      await pumpAddEvent(tester);

      await tapVisible(tester, find.byKey(const ValueKey('course-field')));

      expect(
        find.textContaining("You haven't added any courses yet"),
        findsOneWidget,
      );
    });

    testWidgets('choosing "No course selected" restores the swatches', (
      tester,
    ) async {
      await pumpAddEvent(tester, courses: [aCourse]);

      await tapVisible(tester, find.byKey(const ValueKey('course-field')));
      await tapVisible(tester, find.byKey(const ValueKey('course-option-IS230')));
      await tapVisible(tester, find.byKey(const ValueKey('course-field')));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('course-option-No course selected')),
      );

      expect(find.text('EVENT COLOR'), findsOneWidget);
    });
  });

  group('colour swatches', () {
    testWidgets('excludes hues the student\'s courses already use', (
      tester,
    ) async {
      // IS230 is #16A34A, the first entry in the pool.
      await pumpAddEvent(tester, courses: [aCourse]);

      expect(find.bySemanticsLabel('Event color #16A34A'), findsNothing);
      expect(find.bySemanticsLabel('Event color #2563EB'), findsOneWidget);
    });

    testWidgets('offers the head of the pool when no courses exist', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      expect(find.bySemanticsLabel('Event color #16A34A'), findsOneWidget);
      expect(find.bySemanticsLabel('Event color #2563EB'), findsOneWidget);
    });

    testWidgets('saves the picked swatch as the event colour', (tester) async {
      await pumpAddEvent(tester);
      await tapVisible(tester, find.bySemanticsLabel('Event color #2563EB'));
      await fillValidForm(tester);
      await tapVisible(tester, find.text('Save Event'));

      expect(calendarService.addedEvents.single.color, '#2563EB');
    });

    testWidgets('the custom "+" opens the full colour picker', (tester) async {
      await pumpAddEvent(tester);

      await tapVisible(tester, find.byKey(const ValueKey('custom-color')));

      expect(find.text('Pick a color'), findsOneWidget);
      expect(find.byType(ColorPicker), findsOneWidget);
      expect(find.text('Use this color'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('confirming the picker stores a 6-digit hex', (tester) async {
      await pumpAddEvent(tester);

      await tapVisible(tester, find.byKey(const ValueKey('custom-color')));
      await tapVisible(tester, find.text('Use this color'));
      await fillValidForm(tester);
      await tapVisible(tester, find.text('Save Event'));

      final saved = calendarService.addedEvents.single.color;
      expect(saved, startsWith('#'));
      expect(saved.length, 7);
    });

    testWidgets('cancelling the picker leaves the colour alone', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await tapVisible(tester, find.bySemanticsLabel('Event color #2563EB'));

      await tapVisible(tester, find.byKey(const ValueKey('custom-color')));
      await tapVisible(tester, find.text('Cancel'));
      await fillValidForm(tester);
      await tapVisible(tester, find.text('Save Event'));

      expect(calendarService.addedEvents.single.color, '#2563EB');
    });
  });

  group('date and time pickers', () {
    testWidgets('the date picker fills the field with a long date', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await pickDate(tester, 14);

      expect(find.text('May 14, 2026'), findsOneWidget);
      expect(find.text('Select a date'), findsNothing);
    });

    testWidgets('a past date is selectable', (tester) async {
      await pumpAddEvent(tester);
      // The 1st of May is before "today" (the 3rd).
      await pickDate(tester, 1);

      expect(find.text('May 1, 2026'), findsOneWidget);
    });

    testWidgets('the time picker fills the field in 12-hour form', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await pickDefaultTime(tester);

      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.text('Select a time'), findsNothing);
    });

    testWidgets('cancelling a picker leaves the field untouched', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await tapVisible(tester, find.byKey(const ValueKey('event-date')));
      await tapVisible(tester, find.text('Cancel'));

      expect(find.text('Select a date'), findsOneWidget);
    });

    testWidgets('a filled field takes the navy border', (tester) async {
      await pumpAddEvent(tester);
      await pickDate(tester, 14);

      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('event-date')),
              matching: find.byType(Container),
            )
            .first,
      );
      final border = (box.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, AppColors.navy);
    });
  });

  group('reminder card', () {
    testWidgets('turning it on reveals the stepper, unit and note', (
      tester,
    ) async {
      await pumpAddEvent(tester);

      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));

      expect(find.byKey(const ValueKey('reminder-amount')), findsOneWidget);
      expect(find.byKey(const ValueKey('reminder-unit')), findsOneWidget);
      expect(find.byKey(const ValueKey('reminder-note')), findsOneWidget);
      expect(
        find.textContaining('Pick a date and time'),
        findsOneWidget,
      );
    });

    testWidgets('the note turns green once the reminder is valid', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await fillValidForm(tester);
      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));

      expect(
        find.text('You will be notified 1 day before this event.'),
        findsOneWidget,
      );
    });

    testWidgets('the note turns red when the lead time has already passed', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await enterName(tester);
      // 3 May at 09:00 is exactly "now", so a day earlier is in the past.
      await pickDate(tester, 3);
      await pickDefaultTime(tester);
      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));

      expect(
        find.text('1 day before this event has already passed.'),
        findsOneWidget,
      );
      expect(find.text(kSaveReasonReminder), findsOneWidget);
    });

    testWidgets('the stepper raises and lowers the amount', (tester) async {
      await pumpAddEvent(tester);
      await fillValidForm(tester);
      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));

      await tapVisible(tester, find.byKey(const ValueKey('reminder-increment')));
      expect(amountText(tester), '2');

      await tapVisible(tester, find.byKey(const ValueKey('reminder-decrement')));
      expect(amountText(tester), '1');
    });

    testWidgets('the stepper will not go below 1', (tester) async {
      await pumpAddEvent(tester);
      await fillValidForm(tester);
      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));

      await tapVisible(tester, find.byKey(const ValueKey('reminder-decrement')));

      expect(amountText(tester), '1');
    });

    testWidgets('the unit label pluralises with the amount', (tester) async {
      await pumpAddEvent(tester);
      await fillValidForm(tester);
      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));

      expect(find.text('Day'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('reminder-increment')));

      expect(find.text('Days'), findsOneWidget);
    });

    testWidgets('the unit button expands an inline chip row', (tester) async {
      await pumpAddEvent(tester);
      await fillValidForm(tester);
      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));
      await tapVisible(tester, find.byKey(const ValueKey('reminder-unit')));

      expect(
        find.byKey(const ValueKey('reminder-unit-chip-Minute')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reminder-unit-chip-Week')),
        findsOneWidget,
      );
    });

    testWidgets('picking a unit updates the button and closes the row', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await fillValidForm(tester);
      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));
      await tapVisible(tester, find.byKey(const ValueKey('reminder-unit')));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('reminder-unit-chip-Hour')),
      );

      expect(
        find.byKey(const ValueKey('reminder-unit-chip-Hour')),
        findsNothing,
      );
      expect(find.text('Hour'), findsOneWidget);
    });

    testWidgets(
      'a unit whose lead time has already passed is refused, not accepted',
      (tester) async {
        await pumpAddEvent(tester);
        await enterName(tester);
        // The 5th at 09:00 is 48h away, so "1 day before" is still in the
        // future while "1 week before" is well in the past. (The 4th would
        // not work: 1 day before it lands exactly on "now", which counts as
        // passed.)
        await pickDate(tester, 5);
        await pickDefaultTime(tester);
        await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));
        await tapVisible(tester, find.byKey(const ValueKey('reminder-unit')));
        await tapVisible(
          tester,
          find.byKey(const ValueKey('reminder-unit-chip-Week')),
        );

        // Still on Day: the tap was ignored rather than accepted-then-warned.
        // The row stays open, so "Day" is on both the button and its chip —
        // assert against the button to be unambiguous.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('reminder-unit')),
            matching: find.text('Day'),
          ),
          findsOneWidget,
        );
        expect(find.text(kSaveReasonReminder), findsNothing);
      },
    );
  });

  group('typing the reminder amount', () {
    Future<void> openReminder(WidgetTester tester, {int day = 14}) async {
      await pumpAddEvent(tester);
      await fillValidForm(tester, day: day);
      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));
    }

    testWidgets('a typed value drives the note box live', (tester) async {
      await openReminder(tester);
      await typeAmount(tester, '3');

      expect(
        find.text('You will be notified 3 days before this event.'),
        findsOneWidget,
      );
    });

    testWidgets('a typed value is saved', (tester) async {
      await openReminder(tester);
      await typeAmount(tester, '6');
      await tapVisible(tester, find.text('Save Event'));

      expect(calendarService.addedEvents.single.reminderBefore, 6);
    });

    testWidgets('non-digits never reach the box', (tester) async {
      await openReminder(tester);
      await typeAmount(tester, '1a2.5-');

      expect(amountText(tester), '12');
    });

    testWidgets('the box is capped at two digits', (tester) async {
      await openReminder(tester);
      await typeAmount(tester, '1234');

      expect(amountText(tester), '12');
    });

    testWidgets('an empty box blocks Save and explains the range', (
      tester,
    ) async {
      await openReminder(tester);
      await typeAmount(tester, '');

      expect(find.text(kReminderAmountRangeMessage), findsOneWidget);
      expect(find.text(kSaveReasonReminder), findsOneWidget);
    });

    testWidgets('zero blocks Save and explains the range', (tester) async {
      await openReminder(tester);
      await typeAmount(tester, '0');

      expect(find.text(kReminderAmountRangeMessage), findsOneWidget);
      expect(find.text(kSaveReasonReminder), findsOneWidget);
    });

    testWidgets('above the maximum blocks Save and explains the range', (
      tester,
    ) async {
      await openReminder(tester);
      await typeAmount(tester, '61');

      expect(find.text(kReminderAmountRangeMessage), findsOneWidget);
      expect(find.text(kSaveReasonReminder), findsOneWidget);
    });

    testWidgets('exactly the maximum clears the range message', (
      tester,
    ) async {
      await openReminder(tester);
      await typeAmount(tester, '60');

      // 60 is in range. Whether that *lead time* is reachable is a separate
      // check with its own message — see the reminder card's own suite,
      // where the date can be injected directly.
      expect(find.text(kReminderAmountRangeMessage), findsNothing);
      expect(amountText(tester), '60');
    });

    testWidgets(
      'a typed lead time already in the past is warned, not refused',
      (tester) async {
        // Unlike the stepper and the unit chips, typing is accepted and then
        // blocked at Save — refusing keystrokes would fight the typist.
        await openReminder(tester, day: 5);
        await typeAmount(tester, '30');

        expect(amountText(tester), '30');
        expect(
          find.text('30 days before this event has already passed.'),
          findsOneWidget,
        );
        expect(find.text(kSaveReasonReminder), findsOneWidget);
      },
    );

    testWidgets('an empty box reverts to the last valid value on blur', (
      tester,
    ) async {
      await openReminder(tester);
      await typeAmount(tester, '4');
      await typeAmount(tester, '');
      // Moving focus to the name field is what a student does by tapping
      // elsewhere on the form.
      await tester.tap(find.byKey(const ValueKey('event-name')));
      await tester.pumpAndSettle();

      expect(amountText(tester), '4');
      expect(find.text(kReminderAmountRangeMessage), findsNothing);
    });

    testWidgets('an out-of-range value clamps to the bound on blur', (
      tester,
    ) async {
      await openReminder(tester);
      await typeAmount(tester, '99');
      await tester.tap(find.byKey(const ValueKey('event-name')));
      await tester.pumpAndSettle();

      expect(amountText(tester), '60');
    });

    testWidgets('zero clamps up to the minimum on blur', (tester) async {
      await openReminder(tester);
      await typeAmount(tester, '0');
      await tester.tap(find.byKey(const ValueKey('event-name')));
      await tester.pumpAndSettle();

      expect(amountText(tester), '1');
    });

    testWidgets('the stepper keeps working after a typed value', (
      tester,
    ) async {
      await openReminder(tester);
      await typeAmount(tester, '5');
      await tapVisible(tester, find.byKey(const ValueKey('reminder-decrement')));

      expect(amountText(tester), '4');
    });

    testWidgets('turning the reminder off clears a half-typed amount', (
      tester,
    ) async {
      await openReminder(tester);
      await typeAmount(tester, '');
      expect(find.text(kSaveReasonReminder), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));

      expect(find.byKey(const ValueKey('save-reason')), findsNothing);
    });
  });

  group('saving', () {
    testWidgets('writes the event and pops true', (tester) async {
      await pumpAddEvent(tester);
      await fillValidForm(tester);
      await tapVisible(tester, find.text('Save Event'));

      final saved = calendarService.addedEvents.single;
      expect(saved.eventName, 'Midterm');
      expect(saved.eventDate, DateTime(2026, 5, 14));
      expect(saved.eventTime, '09:00');
      expect(saved.reminderEnabled, isFalse);
      expect(poppedResult, isTrue);
    });

    testWidgets('stores the linked course id', (tester) async {
      await pumpAddEvent(tester, courses: [aCourse]);
      await tapVisible(tester, find.byKey(const ValueKey('course-field')));
      await tapVisible(tester, find.byKey(const ValueKey('course-option-IS230')));
      await fillValidForm(tester);
      await tapVisible(tester, find.text('Save Event'));

      final saved = calendarService.addedEvents.single;
      expect(saved.courseId, 'c1');
      expect(saved.color, aCourse.color);
    });

    testWidgets('schedules the reminder before writing, and stores it on', (
      tester,
    ) async {
      await pumpAddEvent(tester);
      await fillValidForm(tester);
      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));
      await tapVisible(tester, find.text('Save Event'));

      expect(scheduler.permissionRequests, 1);
      expect(scheduler.scheduled, hasLength(1));
      final saved = calendarService.addedEvents.single;
      expect(saved.reminderEnabled, isTrue);
      expect(saved.reminderBefore, 1);
      expect(saved.reminderUnit, ReminderUnit.days);
    });

    testWidgets(
      'a declined permission still saves, with reminderEnabled false',
      (tester) async {
        await pumpAddEvent(
          tester,
          reminderScheduler: FakeReminderScheduler(permissionGranted: false),
        );
        await fillValidForm(tester);
        await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));
        await tapVisible(tester, find.text('Save Event'));

        final saved = calendarService.addedEvents.single;
        expect(saved.reminderEnabled, isFalse);
        expect(saved.reminderBefore, isNull);
        expect(saved.reminderUnit, isNull);
        expect(scheduler.scheduled, isEmpty);
        expect(find.text(kReminderPermissionDeniedMessage), findsOneWidget);
      },
    );

    testWidgets(
      'a refused schedule still saves, with reminderEnabled false',
      (tester) async {
        await pumpAddEvent(
          tester,
          reminderScheduler: FakeReminderScheduler(scheduleResult: false),
        );
        await fillValidForm(tester);
        await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));
        await tapVisible(tester, find.text('Save Event'));

        final saved = calendarService.addedEvents.single;
        expect(saved.reminderEnabled, isFalse);
        expect(find.text(kReminderNotScheduledMessage), findsOneWidget);
      },
    );

    testWidgets('a write failure shows the banner and cancels the reminder', (
      tester,
    ) async {
      await pumpAddEvent(
        tester,
        service: FakeCalendarService(
          addError: CalendarFailure('Could not save your event.'),
        ),
      );
      await fillValidForm(tester);
      await tapVisible(tester, find.byKey(const ValueKey('reminder-toggle')));
      await tapVisible(tester, find.text('Save Event'));

      expect(find.text("Couldn't save your event"), findsOneWidget);
      expect(find.text('Could not save your event.'), findsOneWidget);
      // The event never landed, so its reminder must not fire.
      expect(scheduler.cancelled, [calendarService.nextEventId]);
      expect(poppedResult, isNull);
    });

    testWidgets('shows "Saving…" while the write is in flight', (
      tester,
    ) async {
      await pumpAddEvent(
        tester,
        service: _SlowCalendarService(),
      );
      await fillValidForm(tester);
      await tester.tap(find.text('Save Event'));
      await tester.pump();

      expect(find.text('Saving…'), findsOneWidget);
      // The reason line never shows alongside the in-flight state.
      expect(find.byKey(const ValueKey('save-reason')), findsNothing);
    });
  });

  group('swatch selection logic', () {
    test('excludes every colour a course already uses', () {
      final swatches = eventSwatchesFor(['#16A34A', '#2563EB']);

      expect(swatches, hasLength(kEventSwatchCount));
      expect(swatches, isNot(contains('#16A34A')));
      expect(swatches, isNot(contains('#2563EB')));
    });

    test('matches course colours case-insensitively', () {
      final swatches = eventSwatchesFor(['#16a34a']);

      expect(swatches, isNot(contains('#16A34A')));
    });

    test('falls back to the head of the pool when too few remain', () {
      // Every pool colour is taken, so there is nothing free to offer.
      final swatches = eventSwatchesFor(kEventSwatchPool);

      expect(swatches, hasLength(kEventSwatchCount));
      expect(swatches, kEventSwatchPool.take(kEventSwatchCount));
    });

    test('offers the pool head when no course has a colour', () {
      expect(eventSwatchesFor(const []), kEventSwatchPool.take(4));
    });
  });
}

/// Never resolves its write, so the "Saving…" state can be observed.
///
/// A Completer rather than `Future.delayed`: a pending timer fails the test
/// at teardown, an uncompleted future does not.
class _SlowCalendarService extends FakeCalendarService {
  final Completer<String> _never = Completer<String>();

  @override
  Future<String> addEvent(String uid, CalendarEvent event) => _never.future;
}
