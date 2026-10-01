import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/student.dart';
import 'package:tadarab_app/screens/home/home_screen.dart';
import 'package:tadarab_app/services/home_data_service.dart';

import '../helpers/fake_courses_service.dart';
import '../helpers/fake_home_data_service.dart';

void main() {
  // A fixed Wednesday afternoon so "today", the weekly row, and the
  // greeting text are all deterministic.
  final now = DateTime(2026, 3, 11, 14, 30);
  final weekStart = DateTime(2026, 3, 8);
  final aCourse = Course(courseId: 'c1', courseName: 'IS230', email: 'e@x.com');

  Future<void> pumpHome(
    WidgetTester tester, {
    FakeHomeDataService? dataService,
    FakeCoursesService? coursesService,
    VoidCallback? onSignOut,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          uid: 'uid-1',
          homeDataService: dataService ?? FakeHomeDataService(),
          coursesService: coursesService ?? FakeCoursesService(),
          now: now,
          onSignOut: onSignOut,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('zero courses (Frame 1 — new student)', () {
    testWidgets(
      'shows only the greeting and onboarding card — no Today\'s Progress, streak, or Upcoming',
      (tester) async {
        // FakeHomeDataService defaults to zero courses — this is the true
        // fresh-account state: no courses, no sessions, nothing to resume.
        await pumpHome(tester);

        expect(find.text('Turn your lectures into quizzes.'), findsOneWidget);
        expect(find.text('Create my first course'), findsOneWidget);
        expect(find.text("Today's progress"), findsNothing);
        expect(find.text('Nothing in progress'), findsNothing);
        expect(find.text('Start a new session'), findsNothing);
        expect(find.text('Upcoming'), findsNothing);
      },
    );

    testWidgets(
      'tapping Create my first course opens the real Add Course screen '
      '(feature/courses), not a placeholder',
      (tester) async {
        await pumpHome(tester);

        final button = find.text('Create my first course');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(find.text('Add course'), findsOneWidget);
        expect(
          find.text('Create a course to organize your studies'),
          findsOneWidget,
        );
        expect(find.text('Add Course screen'), findsNothing);
      },
    );

    testWidgets(
      'creating a course through this entry point returns to Home and '
      'lifts it out of the onboarding state — regression test for a bug '
      'where Save neither navigated back nor refreshed anything',
      (tester) async {
        // The same list backs both fakes, mirroring how HomeDataService and
        // CoursesService both read the same real Firestore collection —
        // creating a course through one is visible to the other.
        final sharedCourses = <Course>[];
        final homeDataService = FakeHomeDataService(courses: sharedCourses);
        final coursesService = FakeCoursesService(courses: sharedCourses);

        await pumpHome(
          tester,
          dataService: homeDataService,
          coursesService: coursesService,
        );
        expect(find.text('Create my first course'), findsOneWidget);

        await tester.ensureVisible(find.text('Create my first course'));
        await tester.tap(find.text('Create my first course'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'IS230');
        await tester.pump();
        await tester.tap(
          find
              .byWidgetPredicate((w) => w.runtimeType.toString() == '_Swatch')
              .first,
        );
        await tester.pump();
        await tester.tap(find.text('Save course'));
        await tester.pumpAndSettle();

        // Back on Home, not still on the Add Course screen.
        expect(coursesService.createCourseCalls, 1);
        expect(find.text('Add course'), findsNothing);
        // ...and Home reflects the new course instead of the stale
        // zero-courses onboarding state.
        expect(find.text('Create my first course'), findsNothing);
        expect(find.text("Today's progress"), findsOneWidget);
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

    testWidgets('the points badge is hidden in the greeting (no courses yet)', (
      tester,
    ) async {
      await pumpHome(
        tester,
        dataService: FakeHomeDataService(
          student: Student(
            uid: 'u',
            email: 'e@x.com',
            name: 'Ghaida',
            totalPoints: 108,
          ),
        ),
      );

      expect(find.text('108'), findsNothing);
    });
  });

  group('has courses, nothing in progress', () {
    testWidgets('shows the Continue/Start card, not the onboarding card', (
      tester,
    ) async {
      await pumpHome(
        tester,
        dataService: FakeHomeDataService(courses: [aCourse]),
      );

      expect(find.text('Nothing in progress'), findsOneWidget);
      expect(find.text('Start a new session'), findsOneWidget);
      expect(find.text('Turn your lectures into quizzes.'), findsNothing);
      expect(
        find.text(
          'No upcoming events yet. Once you add events, they\'ll show up here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the points badge shows once the student has a course', (
      tester,
    ) async {
      await pumpHome(
        tester,
        dataService: FakeHomeDataService(
          courses: [aCourse],
          student: Student(
            uid: 'u',
            email: 'e@x.com',
            name: 'Ghaida',
            totalPoints: 108,
          ),
        ),
      );

      expect(find.text('108'), findsOneWidget);
    });
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
          // courses: [aCourse] so the Continue/Start card renders instead of
          // the onboarding card — the latter has its own step "2" circle,
          // which would collide with the weekly row's "2" cell below.
          dataService: FakeHomeDataService(
            courses: [aCourse],
            weeklyProgress: progress,
          ),
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
        dataService: FakeHomeDataService(
          courses: [aCourse],
          inProgress: inProgress,
        ),
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
          dataService: FakeHomeDataService(
            courses: [aCourse],
            inProgress: inProgress,
          ),
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
          // courses: [aCourse] — Upcoming only renders once the student has
          // at least one course (Frame 1's onboarding-only layout has no
          // Upcoming section at all).
          dataService: FakeHomeDataService(
            courses: [aCourse],
            upcomingEvents: events,
          ),
        );

        expect(find.text('Midterm'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('GP1 report'), findsOneWidget);
        expect(find.text('9d'), findsOneWidget);
      },
    );
  });

  group(
    'course picker (reachable only once the student has at least one course)',
    () {
      testWidgets(
        'picking a real course closes the sheet and opens the quiz setup placeholder',
        (tester) async {
          await pumpHome(
            tester,
            dataService: FakeHomeDataService(courses: [aCourse]),
          );

          await tester.tap(find.text('New Quiz'));
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
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(courses: [aCourse]),
        );

        await tester.tap(find.text('New Flashcards'));
        await tester.pumpAndSettle();

        expect(
          find.text('Flashcards · pick the subject to study'),
          findsOneWidget,
        );
      });
    },
  );

  group('bottom navigation', () {
    testWidgets(
      'switches between Home, Courses, Calendar and Profile placeholders',
      (tester) async {
        // courses: [aCourse] so returning to Home shows Today's Progress
        // (this test is about tab-switching, not which Home state renders).
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(courses: [aCourse]),
        );

        await tester.tap(find.text('Courses'));
        await tester.pumpAndSettle();
        // The Courses tab (feature/courses) now renders the real
        // CoursesListScreen rather than a placeholder — assert on its
        // header, which is present regardless of its loading/data state.
        expect(find.text('Courses'), findsWidgets);

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
      'a course created while Home was inactive shows up on returning to '
      'the Home tab — regression test for Home never refreshing itself',
      (tester) async {
        final courses = <Course>[];
        final homeDataService = FakeHomeDataService(courses: courses);
        await pumpHome(tester, dataService: homeDataService);

        expect(find.text('Create my first course'), findsOneWidget);
        expect(homeDataService.fetchCoursesCalls, 1);

        await tester.tap(find.text('Courses'));
        await tester.pumpAndSettle();

        // A course "created" while Home sat inactive on another tab.
        courses.add(aCourse);

        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();

        expect(homeDataService.fetchCoursesCalls, 2);
        expect(find.text('Create my first course'), findsNothing);
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
