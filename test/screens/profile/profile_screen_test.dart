import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/student.dart';
import 'package:tadarab_app/screens/profile/profile_screen.dart';
import 'package:tadarab_app/screens/profile/widgets/logout_dialog.dart';
import 'package:tadarab_app/services/home_data_service.dart';

import '../../helpers/fake_home_data_service.dart';
import '../../helpers/fake_profile_service.dart';
import '../../helpers/fake_reminder_scheduler.dart';

void main() {
  Student student({
    String name = 'Leen',
    int totalPoints = 0,
    bool reminderEnabled = false,
    String? reminderTime,
  }) => Student(
    uid: 'uid-1',
    email: 'student@example.com',
    name: name,
    totalPoints: totalPoints,
    reminderEnabled: reminderEnabled,
    reminderTime: reminderTime,
  );

  Future<void> pumpProfile(
    WidgetTester tester, {
    Student? data,
    HomeDataService? dataService,
    VoidCallback? onSignOut,
  }) async {
    // Tall enough that the whole scrolling body is on screen: tap()
    // doesn't scroll, and ensureVisible is unreliable for this
    // Column > Expanded > SingleChildScrollView shape (see CLAUDE.md).
    tester.view.physicalSize = const Size(412, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            uid: 'uid-1',
            homeDataService:
                dataService ?? FakeHomeDataService(student: data ?? student()),
            profileService: FakeProfileService(),
            reminderScheduler: FakeReminderScheduler(),
            onSignOut: onSignOut,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  group('header and summary', () {
    testWidgets('shows the name, points and derived rank', (tester) async {
      await pumpProfile(tester, data: student(name: 'Leen', totalPoints: 1450));

      expect(find.text('Leen'), findsOneWidget);
      expect(textOf(tester, 'profile-points'), '1,450');
      // 1450 is Skilled Learner (1200-1799); the card shows the short name.
      expect(textOf(tester, 'profile-rank'), 'Skilled');
      expect(find.text('Skilled Learner'), findsOneWidget);
    });

    testWidgets('a brand-new student reads as Beginner with 0 points', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(textOf(tester, 'profile-points'), '0');
      expect(textOf(tester, 'profile-rank'), 'Beginner');
      expect(find.text('Beginner Learner'), findsOneWidget);
      expect(find.text('100 pts to Active'), findsOneWidget);
      expect(find.text('0 / 99 pts'), findsOneWidget);
    });

    testWidgets('the top rank reports no next rank', (tester) async {
      await pumpProfile(tester, data: student(totalPoints: 7200));

      expect(textOf(tester, 'profile-rank'), 'Master');
      expect(find.text('Highest rank reached'), findsOneWidget);
      expect(find.text('7,200 pts · top rank'), findsOneWidget);
    });

    testWidgets('derives rank from points, ignoring the stored field', (
      tester,
    ) async {
      // Student.currentRank defaults to 'Beginner Learner' and is never
      // written — the screen must not believe it.
      await pumpProfile(tester, data: student(totalPoints: 5000));

      expect(find.text('Elite Learner'), findsOneWidget);
      expect(find.text('Beginner Learner'), findsNothing);
    });
  });

  group('sections', () {
    testWidgets('lists Settings and all four About rows', (tester) async {
      await pumpProfile(tester);

      expect(find.text('Student Summary'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      for (final label in [
        'About Us',
        'Learning Guide',
        'Privacy Policy',
        'Terms of Use',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('the reminder summary reads "Off" when disabled', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(textOf(tester, 'reminder-summary'), 'Off');
    });

    testWidgets('the reminder summary shows the daily time when on', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        data: student(reminderEnabled: true, reminderTime: '16:00'),
      );

      expect(textOf(tester, 'reminder-summary'), 'Daily at 4:00 PM');
    });

    testWidgets('reads "Off" when enabled but no time was ever stored', (
      tester,
    ) async {
      await pumpProfile(tester, data: student(reminderEnabled: true));

      expect(textOf(tester, 'reminder-summary'), 'Off');
    });
  });

  group('navigation', () {
    testWidgets('the edit chip opens Edit Profile', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.bySemanticsLabel('Edit profile'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('NAME'), findsOneWidget);
    });

    testWidgets('"View Ranks" opens the Ranks screen', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.text('View Ranks'));
      await tester.pumpAndSettle();

      expect(find.text('Ranks'), findsOneWidget);
      // The list is lazy, so assert on the first row rather than the last.
      expect(find.text('Beginner Learner'), findsWidgets);
    });

    testWidgets('the Study Reminder row opens its screen', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.byKey(const ValueKey('study-reminder-row')));
      await tester.pumpAndSettle();

      expect(find.text('Study Reminder'), findsWidgets);
      expect(find.text('Enable Reminder'), findsOneWidget);
    });

    // One test per row rather than a loop in one test: re-pumping inside a
    // single tester leaves the previously pushed route on the navigator,
    // so the Profile rows are no longer findable on the second pass.
    for (final (label, heading) in [
      ('About Us', 'About Tadarab'),
      ('Privacy Policy', 'Privacy Commitment'),
      ('Terms of Use', 'Using Tadarab'),
    ]) {
      testWidgets('the $label row opens its document', (tester) async {
        await pumpProfile(tester);

        await tester.tap(find.byKey(ValueKey('about-row-$label')));
        await tester.pumpAndSettle();

        expect(find.text(heading), findsOneWidget);
      });
    }

    testWidgets('Learning Guide opens the lively variant', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.byKey(const ValueKey('about-row-Learning Guide')));
      await tester.pumpAndSettle();

      expect(find.text('HOW TO EARN POINTS'), findsOneWidget);
      expect(find.text('Rank Progress'), findsOneWidget);
    });
  });

  group('log out', () {
    testWidgets('asks before signing out', (tester) async {
      var signedOut = 0;
      await pumpProfile(tester, onSignOut: () => signedOut++);

      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      expect(find.text(kLogOutTitle), findsOneWidget);
      expect(signedOut, 0, reason: 'must not sign out before confirming');
    });

    testWidgets('confirming signs out', (tester) async {
      var signedOut = 0;
      await pumpProfile(tester, onSignOut: () => signedOut++);

      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(signedOut, 1);
    });

    testWidgets('"Stay signed in" does not sign out', (tester) async {
      var signedOut = 0;
      await pumpProfile(tester, onSignOut: () => signedOut++);

      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stay signed in'));
      await tester.pumpAndSettle();

      expect(signedOut, 0);
      expect(find.text(kLogOutTitle), findsNothing);
    });
  });

  group('loading and failure', () {
    testWidgets('shows a spinner before the first snapshot', (tester) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              uid: 'uid-1',
              homeDataService: _PendingHomeDataService(),
              profileService: FakeProfileService(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the error banner and retries', (tester) async {
      final failing = _FailingHomeDataService();
      await pumpProfile(tester, dataService: failing);

      expect(find.text("Couldn't load your profile"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      final before = failing.watchCalls;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(failing.watchCalls, greaterThan(before));
    });

    testWidgets('a missing student document shows the error state', (
      tester,
    ) async {
      await pumpProfile(tester, dataService: _NullStudentHomeDataService());

      expect(find.text("Couldn't load your profile"), findsOneWidget);
    });
  });
}

/// Never emits, so the loading state can be observed.
class _PendingHomeDataService extends FakeHomeDataService {
  @override
  Stream<Student?> watchStudent(String uid) =>
      StreamController<Student?>().stream;
}

/// Errors the student stream, to drive the failure state.
class _FailingHomeDataService extends FakeHomeDataService {
  int watchCalls = 0;

  @override
  Stream<Student?> watchStudent(String uid) {
    watchCalls++;
    return Stream.error(Exception('offline'));
  }
}

/// Emits null, as a deleted or not-yet-created student document would.
class _NullStudentHomeDataService extends FakeHomeDataService {
  @override
  Stream<Student?> watchStudent(String uid) => Stream.value(null);
}
