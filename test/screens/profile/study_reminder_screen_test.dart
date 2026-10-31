import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/screens/profile/study_reminder_screen.dart';
import 'package:tadarab_app/services/profile_service.dart';
import 'package:tadarab_app/widgets/app_button.dart';

import '../../helpers/fake_profile_service.dart';
import '../../helpers/fake_reminder_scheduler.dart';

void main() {
  // Fixed so every pre-existing test below (none of which pass `now`
  // explicitly) deterministically opens the time picker's "no saved time
  // yet" fallback on 9:00 AM, as they all already assume, rather than on
  // whatever the real wall-clock time happens to be when the suite runs.
  final defaultNow = DateTime(2026, 5, 3, 9, 0);

  late FakeProfileService service;
  late FakeReminderScheduler scheduler;

  Future<void> pumpReminder(
    WidgetTester tester, {
    bool enabled = false,
    TimeOfDay? time,
    DateTime? now,
    FakeProfileService? profileService,
    FakeReminderScheduler? reminderScheduler,
  }) async {
    service = profileService ?? FakeProfileService();
    scheduler = reminderScheduler ?? FakeReminderScheduler();
    // 600 wide because Material's time picker overflows a phone-width
    // surface — the same reason the Add Event suite is 600 wide.
    await tester.binding.setSurfaceSize(const Size(600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => StudyReminderScreen(
                    uid: 'uid-1',
                    enabled: enabled,
                    time: time,
                    profileService: service,
                    reminderScheduler: scheduler,
                    now: now ?? defaultNow,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  AppButton saveButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, 'Save Changes'));

  Future<void> toggle(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('study-reminder-toggle')));
    await tester.pumpAndSettle();
  }

  /// Accepts the time picker's default (9:00 AM).
  Future<void> pickDefaultTime(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('reminder-time-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  group('default state', () {
    testWidgets('opens off, with no time card and Save disabled', (
      tester,
    ) async {
      await pumpReminder(tester);

      expect(find.text('Enable Reminder'), findsOneWidget);
      expect(find.text('Get a daily nudge to study'), findsOneWidget);
      // The time card only exists once the toggle is on.
      expect(find.byKey(const ValueKey('reminder-time')), findsNothing);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('turning it on reveals an unset time and blocks Save', (
      tester,
    ) async {
      await pumpReminder(tester);
      await toggle(tester);

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('reminder-time'))).data,
        '--:-- --',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('reminder-helper'))).data,
        kPickTimeNote,
      );
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('an already-on reminder shows its stored time', (
      tester,
    ) async {
      await pumpReminder(
        tester,
        enabled: true,
        time: const TimeOfDay(hour: 16, minute: 0),
      );

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('reminder-time'))).data,
        '4:00 PM',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('reminder-helper'))).data,
        "You'll receive a reminder at 4:00 PM every day.",
      );
      // Nothing has changed yet.
      expect(saveButton(tester).onPressed, isNull);
    });
  });

  group('picking a time', () {
    testWidgets('fills the field and enables Save', (tester) async {
      await pumpReminder(tester);
      await toggle(tester);
      await pickDefaultTime(tester);

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('reminder-time'))).data,
        '9:00 AM',
      );
      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('cancelling the picker leaves the time unset', (tester) async {
      await pumpReminder(tester);
      await toggle(tester);
      await tester.tap(find.byKey(const ValueKey('reminder-time-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('reminder-time'))).data,
        '--:-- --',
      );
    });

    testWidgets(
      'with no saved time, the picker opens on the injected current time',
      (tester) async {
        // A `now` distinct from the file-wide default (9:00 AM), so this
        // genuinely proves it opened on `now` rather than coincidentally
        // matching some other fallback.
        await pumpReminder(tester, now: DateTime(2026, 5, 3, 14, 37));
        await toggle(tester);
        await pickDefaultTime(tester);

        expect(
          tester.widget<Text>(find.byKey(const ValueKey('reminder-time'))).data,
          '2:37 PM',
        );
      },
    );

    testWidgets(
      'with a saved time, the picker opens on that saved time, not the '
      'current time',
      (tester) async {
        await pumpReminder(
          tester,
          enabled: true,
          time: const TimeOfDay(hour: 16, minute: 0),
          // Deliberately different from the saved 4:00 PM, so a picker
          // that opened on `now` instead would be caught by this test.
          now: DateTime(2026, 5, 3, 9, 0),
        );
        await pickDefaultTime(tester);

        expect(
          tester.widget<Text>(find.byKey(const ValueKey('reminder-time'))).data,
          '4:00 PM',
        );
      },
    );
  });

  group('saving', () {
    testWidgets('schedules the daily reminder and stores it on', (
      tester,
    ) async {
      await pumpReminder(tester);
      await toggle(tester);
      await pickDefaultTime(tester);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(scheduler.permissionRequests, 1);
      expect(scheduler.dailyScheduled, [const TimeOfDay(hour: 9, minute: 0)]);
      expect(service.savedReminders.single.enabled, isTrue);
      expect(
        service.savedReminders.single.time,
        const TimeOfDay(hour: 9, minute: 0),
      );
    });

    testWidgets('turning it off cancels and clears the stored time', (
      tester,
    ) async {
      await pumpReminder(
        tester,
        enabled: true,
        time: const TimeOfDay(hour: 16, minute: 0),
      );
      await toggle(tester);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(scheduler.dailyCancelled, 1);
      expect(service.savedReminders.single.enabled, isFalse);
      expect(service.savedReminders.single.time, isNull);
    });

    testWidgets(
      'a declined permission stores reminderEnabled false and says so',
      (tester) async {
        await pumpReminder(
          tester,
          reminderScheduler: FakeReminderScheduler(permissionGranted: false),
        );
        await toggle(tester);
        await pickDefaultTime(tester);
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(scheduler.dailyScheduled, isEmpty);
        expect(service.savedReminders.single.enabled, isFalse);
        expect(service.savedReminders.single.time, isNull);
        expect(
          find.text(kStudyReminderPermissionDeniedMessage),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a refused schedule stores reminderEnabled false and says so',
      (tester) async {
        await pumpReminder(
          tester,
          reminderScheduler: FakeReminderScheduler(scheduleResult: false),
        );
        await toggle(tester);
        await pickDefaultTime(tester);
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(service.savedReminders.single.enabled, isFalse);
        expect(find.text(kStudyReminderNotScheduledMessage), findsOneWidget);
      },
    );

    testWidgets('a successful save confirms the time', (tester) async {
      await pumpReminder(tester);
      await toggle(tester);
      await pickDefaultTime(tester);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(
        find.text('Study reminder set for 9:00 AM'),
        findsOneWidget,
      );
    });

    testWidgets('a write failure shows the banner and unschedules', (
      tester,
    ) async {
      await pumpReminder(
        tester,
        profileService: FakeProfileService(
          reminderError: ProfileFailure('Could not save your changes.'),
        ),
      );
      await toggle(tester);
      await pickDefaultTime(tester);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't save your reminder"), findsOneWidget);
      // Nothing was stored, so nothing should remain scheduled.
      expect(scheduler.dailyCancelled, 1);
    });
  });
}
