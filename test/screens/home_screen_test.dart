import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/student.dart';
import 'package:tadarab_app/screens/home/home_screen.dart';
import 'package:tadarab_app/services/home_data_service.dart';

import '../helpers/fake_home_data_service.dart';

void main() {
  // A fixed Wednesday afternoon so "today", the weekly row, and the
  // greeting text are all deterministic.
  final now = DateTime(2026, 3, 11, 14, 30);
  final weekStart = DateTime(2026, 3, 8);

  Future<void> pumpHome(
    WidgetTester tester, {
    FakeHomeDataService? dataService,
    VoidCallback? onSignOut,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          uid: 'uid-1',
          homeDataService: dataService ?? FakeHomeDataService(),
          now: now,
          onSignOut: onSignOut,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('fresh / empty state', () {
    testWidgets(
      'shows zeroed progress, "Start a new session", and the empty Upcoming message',
      (tester) async {
        await pumpHome(tester);

        expect(find.text("Today's progress"), findsOneWidget);
        expect(
          find.text('0'),
          findsWidgets,
        ); // today's question + flashcard counts
        expect(find.text('Nothing in progress'), findsOneWidget);
        expect(find.text('Start a new session'), findsOneWidget);
        expect(
          find.text(
            'No upcoming events yet. Once you add events, they\'ll show up here.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the greeting shows the real student name and a time-appropriate greeting',
      (tester) async {
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(
            student: Student(uid: 'u', email: 'e@x.com', name: 'Ghaida'),
          ),
        );

        expect(find.text('Ghaida'), findsOneWidget);
        expect(find.text('Good afternoon'), findsOneWidget); // now is 14:30
      },
    );
  });

  group('weekly progress row', () {
    testWidgets(
      'past day with data is filled and shows its count; today is filled white; future days are locked',
      (tester) async {
        final progress = aggregateWeeklyProgress(
          weekStart: weekStart,
          entries: [
            (
              date: DateTime(2026, 3, 9),
              questionCount: 5,
              flashcardCount: 0,
            ), // Monday, past
            (
              date: DateTime(2026, 3, 11),
              questionCount: 1,
              flashcardCount: 1,
            ), // Wednesday, today -> combined 2
          ],
        );
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(weeklyProgress: progress),
        );

        expect(find.text('5'), findsOneWidget); // Monday's filled red cell
        expect(
          find.text('2'),
          findsOneWidget,
        ); // today's filled white cell (1 question + 1 flashcard)
      },
    );
  });

  group('in-progress session', () {
    testWidgets('shows the Resume card with course, kind, and fraction', (
      tester,
    ) async {
      final inProgress = InProgressSession(
        sessionId: 's1',
        kind: SessionKind.quiz,
        courseId: 'c1',
        courseName: 'IS230',
        currentIndex: 6,
        total: 15,
      );
      await pumpHome(
        tester,
        dataService: FakeHomeDataService(inProgress: inProgress),
      );

      expect(find.text('Pick up where you left off'), findsOneWidget);
      expect(find.text('IS230 — Quiz'), findsOneWidget);
      expect(find.text('6/15'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Nothing in progress'), findsNothing);
    });

    testWidgets(
      'tapping Resume opens the (currently unreachable-in-production) session placeholder',
      (tester) async {
        final inProgress = InProgressSession(
          sessionId: 's1',
          kind: SessionKind.flashcard,
          courseId: 'c1',
          courseName: 'IS230',
          currentIndex: 2,
          total: 20,
        );
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(inProgress: inProgress),
        );

        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();

        expect(find.text('Flashcard session screen'), findsOneWidget);
      },
    );
  });

  group('upcoming events', () {
    testWidgets(
      'shows a Today badge for an event happening today and a day count for a future one',
      (tester) async {
        final events = [
          UpcomingEventView(
            event: CalendarEvent(
              eventId: 'e1',
              eventName: 'Midterm',
              eventDate: DateTime(2026, 3, 11),
              eventTime: '12:00 PM',
              email: 'e@x.com',
            ),
          ),
          UpcomingEventView(
            event: CalendarEvent(
              eventId: 'e2',
              eventName: 'GP1 report',
              eventDate: DateTime(2026, 3, 20),
              eventTime: '11:59 PM',
              email: 'e@x.com',
            ),
          ),
        ];
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(upcomingEvents: events),
        );

        expect(find.text('Midterm'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('GP1 report'), findsOneWidget);
        expect(find.text('9d'), findsOneWidget);
      },
    );
  });

  group('course picker', () {
    testWidgets(
      'New quiz with no courses shows the explanatory empty state, not an error',
      (tester) async {
        await pumpHome(tester);

        await tester.tap(find.text('New quiz'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'No courses yet. Once courses are added, they\'ll show up here.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'picking a real course closes the sheet and opens the quiz setup placeholder',
      (tester) async {
        final course = Course(
          courseId: 'c1',
          courseName: 'IS230',
          email: 'e@x.com',
        );
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(courses: [course]),
        );

        await tester.tap(find.text('New quiz'));
        await tester.pumpAndSettle();
        expect(find.text('IS230'), findsOneWidget);

        await tester.tap(find.text('IS230'));
        await tester.pumpAndSettle();

        expect(find.text('Quiz setup screen'), findsOneWidget);
      },
    );

    testWidgets('Flashcards button opens the picker labeled for flashcards', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('Flashcards'));
      await tester.pumpAndSettle();

      expect(
        find.text('Flashcards · pick the subject to study'),
        findsOneWidget,
      );
    });
  });

  group('bottom navigation', () {
    testWidgets(
      'switches between Home, Courses, Calendar and Profile placeholders',
      (tester) async {
        await pumpHome(tester);

        await tester.tap(find.text('Courses'));
        await tester.pumpAndSettle();
        expect(find.text('Courses screen'), findsOneWidget);

        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();
        expect(find.text('Calendar screen'), findsOneWidget);

        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(find.text('Profile screen'), findsOneWidget);

        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();
        expect(find.text("Today's progress"), findsOneWidget);
      },
    );

    testWidgets(
      'Profile placeholder shows a working Log out button when onSignOut is provided',
      (tester) async {
        var signedOut = false;
        await pumpHome(tester, onSignOut: () => signedOut = true);

        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(find.text('Log out'), findsOneWidget);

        await tester.tap(find.text('Log out'));
        await tester.pump();

        expect(signedOut, isTrue);
      },
    );

    testWidgets(
      'Profile placeholder has no Log out button when onSignOut is not provided',
      (tester) async {
        await pumpHome(tester);

        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();

        expect(find.text('Log out'), findsNothing);
      },
    );
  });
}
