import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_sessions_screen.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';
import 'package:tadarab_app/models/flashcard_session.dart';
import 'package:tadarab_app/models/student.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/screens/courses/course_detail_screen.dart';
import 'package:tadarab_app/screens/home/home_screen.dart';
import 'package:tadarab_app/services/home_data_service.dart';
import 'package:tadarab_app/utils/rank.dart';

import '../helpers/fake_calendar_service.dart';
import '../helpers/fake_courses_service.dart';
import '../helpers/fake_flashcard_service.dart';
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
    FakeCalendarService? calendarService,
    FakeCoursesService? coursesService,
    FakeFlashcardService? flashcardService,
    VoidCallback? onSignOut,
    bool reducedMotion = false,
    double textScaleFactor = 1.0,
  }) async {
    final home = HomeScreen(
      uid: 'uid-1',
      homeDataService: dataService ?? FakeHomeDataService(),
      // The Calendar tab is a real screen now, so it needs a fake
      // service for the moment a test actually opens that tab.
      calendarService: calendarService ?? FakeCalendarService(),
      coursesService: coursesService ?? FakeCoursesService(),
      // A single fake covers every courseId a test uses — scoping by
      // the real uid/courseId the screen asks for isn't needed here,
      // since each test only ever deals with one course.
      flashcardServiceBuilder: flashcardService == null
          ? null
          : ({required uid, required courseId}) => flashcardService,
      now: now,
      onSignOut: onSignOut,
    );
    final needsMediaQuery = reducedMotion || textScaleFactor != 1.0;
    await tester.pumpWidget(
      MaterialApp(
        home: needsMediaQuery
            ? MediaQuery(
                data: MediaQueryData(
                  disableAnimations: reducedMotion,
                  textScaler: TextScaler.linear(textScaleFactor),
                ),
                child: home,
              )
            : home,
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

        // Not left on the Add Course screen, and — per the "land on
        // Courses after creating from Home's onboarding" rule — switched
        // to the Courses tab rather than staying on Home.
        expect(coursesService.createCourseCalls, 1);
        expect(find.text('Add course'), findsNothing);
        final bottomNav = tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_BottomNav',
          ),
        );
        expect((bottomNav as dynamic).currentIndex, 1);
        // The Courses tab itself shows the real, newly-created course —
        // not just that the tab index flipped.
        expect(find.text('IS230'), findsOneWidget);
      },
    );

    testWidgets(
      'returning from a pushed screen re-fetches Home data instead of staying stale',
      (tester) async {
        // HomeScreen keeps every bottom-nav tab alive (IndexedStack), so
        // this State is never recreated by navigating away and back — the
        // real bug this guards against was a `late final` Future computed
        // once and never refreshed (e.g. finishing a quiz updates points/
        // streak in Firestore, but Home kept showing the pre-quiz snapshot).
        //
        // The real Add Course screen (feature/courses) only reports back
        // to Home (`created == true`) once a course is actually saved —
        // unlike the old placeholder, a bare pop doesn't trigger a reload —
        // so this drives the real save flow rather than just popping.
        final sharedCourses = <Course>[];
        final dataService = FakeHomeDataService(courses: sharedCourses);
        final coursesService = FakeCoursesService(courses: sharedCourses);
        await pumpHome(
          tester,
          dataService: dataService,
          coursesService: coursesService,
        );
        expect(dataService.fetchCoursesCalls, 1);

        final button = find.text('Create my first course');
        await tester.ensureVisible(button);
        await tester.tap(button);
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

        expect(dataService.fetchCoursesCalls, 2);
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

      expect(find.textContaining('108'), findsNothing);
    });

    testWidgets(
      'no decorative initial-letter circle in the greeting — it had no '
      'tap behavior and is gone now',
      (tester) async {
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(
            student: Student(uid: 'u', email: 'e@x.com', name: 'Ghaida'),
          ),
        );

        // The removed circle's only content was the bare first-letter
        // initial ('G') on its own — nothing else in the greeting header
        // renders a standalone single capital letter.
        expect(find.text('G'), findsNothing);
      },
    );
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

    testWidgets(
      'the points badge shows once the student has a course, with the '
      'short rank name and points on one line',
      (tester) async {
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

        // 108 is Active Learner (100-299) — shortName drops " Learner".
        expect(find.text('Active · 108'), findsOneWidget);
      },
    );

    // Other pill-shaped buttons elsewhere on Home (e.g. "Start a new
    // session") share this same circular(999) radius, so this still needs
    // to anchor on the badge's own label text to find the right one.
    Finder badgePill(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).borderRadius ==
                BorderRadius.circular(999),
      ),
    );

    testWidgets(
      'just below a rank threshold, the points badge is tinted with that '
      'rank\'s own color (99 pts — Beginner Learner)',
      (tester) async {
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(
            courses: [aCourse],
            student: Student(
              uid: 'u',
              email: 'e@x.com',
              name: 'Ghaida',
              totalPoints: 99,
            ),
          ),
        );

        expect(find.text('Beginner · 99'), findsOneWidget);
        final color =
            (tester.widget<Container>(badgePill('Beginner · 99')).decoration!
                    as BoxDecoration)
                .color;
        expect(color, rankForPoints(99).color.withValues(alpha: 0.12));
      },
    );

    testWidgets(
      'crossing a rank threshold changes the points badge color (100 pts '
      '— Active Learner, not Beginner Learner\'s color)',
      (tester) async {
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(
            courses: [aCourse],
            student: Student(
              uid: 'u',
              email: 'e@x.com',
              name: 'Ghaida',
              totalPoints: 100,
            ),
          ),
        );

        expect(find.text('Active · 100'), findsOneWidget);
        final color =
            (tester.widget<Container>(badgePill('Active · 100')).decoration!
                    as BoxDecoration)
                .color;
        expect(color, rankForPoints(100).color.withValues(alpha: 0.12));
        expect(color, isNot(rankForPoints(99).color.withValues(alpha: 0.12)));
      },
    );

    // Verifies the greeting Row's own layout directly via geometry, rather
    // than asserting zero exceptions screen-wide: at 1.5x/2x text scale,
    // the Today's Progress week row (today_progress_card.dart, untouched
    // by this change) separately overflows its own day cells — a real,
    // pre-existing bug this task didn't ask to fix (confirmed by manually
    // inspecting the overflow output at both scales: every reported
    // RenderFlex belongs to that file's _DayCell, none to home_screen.dart).
    // That overflow must still be consumed below or the test would
    // auto-fail on teardown; the greeting itself is then checked
    // independently, on its own terms, via geometry.
    Future<void> expectGreetingFitsAt(
      WidgetTester tester,
      double textScaleFactor,
    ) async {
      const longName = 'Alexandra Christodoulopoulou';
      await pumpHome(
        tester,
        textScaleFactor: textScaleFactor,
        dataService: FakeHomeDataService(
          courses: [aCourse],
          student: Student(
            uid: 'u',
            email: 'e@x.com',
            name: longName,
            totalPoints: 616, // Focused Learner (300-699).
          ),
        ),
      );
      // Consumes the known, unrelated today_progress_card.dart overflow(s)
      // above so this test doesn't auto-fail on them.
      tester.takeException();

      expect(find.text('Focused · 616'), findsOneWidget);
      final nameRect = tester.getRect(find.text(longName));
      final pillRect = tester.getRect(
        find.ancestor(
          of: find.text('Focused · 616'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).borderRadius ==
                    BorderRadius.circular(999),
          ),
        ),
      );
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;

      // The ellipsized name never reaches into the pill's own space, and
      // the pill (natural width, not stretched) never runs off-screen.
      expect(nameRect.right, lessThanOrEqualTo(pillRect.left));
      expect(pillRect.right, lessThanOrEqualTo(screenWidth));
    }

    testWidgets(
      'a long student name at 1.5x text scale never overlaps or pushes '
      'the points pill off-screen',
      (tester) => expectGreetingFitsAt(tester, 1.5),
    );

    testWidgets(
      'a long student name at 2x text scale never overlaps or pushes '
      'the points pill off-screen',
      (tester) => expectGreetingFitsAt(tester, 2.0),
    );
  });

  group('weekly progress row', () {
    testWidgets(
      'active days (past or today) are labeled "studied", a day with no '
      'activity (past or future) is labeled "no activity" — no counts '
      'shown anywhere',
      (tester) async {
        final progress = aggregateWeeklyProgress(
          weekStart: weekStart,
          entries: [
            (
              date: DateTime(2026, 3, 9),
              questionCount: 5,
              flashcardCount: 0,
            ), // Monday, past, active
            (
              date: DateTime(2026, 3, 11),
              questionCount: 1,
              flashcardCount: 1,
            ), // Wednesday, today, active (1 question + 1 flashcard)
          ],
        );
        final handle = tester.ensureSemantics();

        await pumpHome(
          tester,
          // courses: [aCourse] so the Continue/Start card renders instead of
          // the onboarding card — the latter has its own step "2" circle,
          // which would collide with the weekly row's cells below.
          dataService: FakeHomeDataService(
            courses: [aCourse],
            weeklyProgress: progress,
          ),
        );

        // No count text in the row itself any more (the top two "Today's
        // progress" counters are unchanged and legitimately show "1" for
        // each of today's question/flashcard counts — just not in the
        // week row below).
        expect(find.text('5'), findsNothing);
        expect(find.text('2'), findsNothing);

        expect(
          find.bySemanticsLabel('Monday, Mar 9, studied'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Wednesday, Mar 11, studied'),
          findsOneWidget,
        ); // today, active
        expect(
          find.bySemanticsLabel('Sunday, Mar 8, no activity'),
          findsOneWidget,
        ); // past, missed
        expect(
          find.bySemanticsLabel('Saturday, Mar 14, no activity'),
          findsOneWidget,
        ); // future, locked — same label as a missed day, per the design
        handle.dispose();
      },
    );

    testWidgets(
      'today with no activity yet is labeled "no activity" too — it only '
      'differs from a missed day visually (bright dashed outline), not in '
      'its semantics label',
      (tester) async {
        final handle = tester.ensureSemantics();

        await pumpHome(
          tester,
          dataService: FakeHomeDataService(courses: [aCourse]),
        );

        expect(
          find.bySemanticsLabel('Wednesday, Mar 11, no activity'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets('each cell is labeled "<weekday letter> <day of month>" on '
        'one line', (tester) async {
      await pumpHome(
        tester,
        dataService: FakeHomeDataService(courses: [aCourse]),
      );

      expect(find.text('S 8'), findsOneWidget); // Sunday, weekStart
      expect(find.text('W 11'), findsOneWidget); // Wednesday, today
      expect(find.text('S 14'), findsOneWidget); // Saturday, end of week
    });

    testWidgets(
      'current week: the header shows just the month, and the "back to '
      'this week" button is present but invisible and inert',
      (tester) async {
        final handle = tester.ensureSemantics();

        await pumpHome(
          tester,
          dataService: FakeHomeDataService(courses: [aCourse]),
        );

        expect(find.text('Mar'), findsOneWidget);

        final opacity = tester.widget<Opacity>(
          find.ancestor(
            of: find.byIcon(Icons.keyboard_double_arrow_right),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacity.opacity, 0);
        expect(find.bySemanticsLabel('Back to this week'), findsNothing);
        handle.dispose();
      },
    );

    testWidgets(
      'swiping right once goes back exactly one week: the header shows '
      'the explicit range and the back button becomes visible and tappable',
      (tester) async {
        final handle = tester.ensureSemantics();

        await pumpHome(
          tester,
          dataService: FakeHomeDataService(courses: [aCourse]),
        );

        await tester.drag(find.byType(PageView), const Offset(400, 0));
        await tester.pumpAndSettle();

        expect(find.text('Mar'), findsNothing);
        expect(find.text('Mar 1 – Mar 7'), findsOneWidget);

        final opacity = tester.widget<Opacity>(
          find.ancestor(
            of: find.byIcon(Icons.keyboard_double_arrow_right),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacity.opacity, 1);
        expect(find.bySemanticsLabel('Back to this week'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets(
      'tapping "back to this week" after swiping returns to the current '
      "week and hides the button again",
      (tester) async {
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(courses: [aCourse]),
        );

        await tester.drag(find.byType(PageView), const Offset(400, 0));
        await tester.pumpAndSettle();
        expect(find.text('Mar 1 – Mar 7'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.keyboard_double_arrow_right));
        await tester.pumpAndSettle();

        expect(find.text('Mar'), findsOneWidget);
        expect(find.text('Mar 1 – Mar 7'), findsNothing);
      },
    );

    testWidgets(
      'reduced motion: "back to this week" jumps instantly rather than '
      'animating — a single pump already shows the current week',
      (tester) async {
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(courses: [aCourse]),
          reducedMotion: true,
        );

        await tester.drag(find.byType(PageView), const Offset(400, 0));
        await tester.pumpAndSettle();
        expect(find.text('Mar 1 – Mar 7'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.keyboard_double_arrow_right));
        await tester.pump(); // exactly one pump — no settle
        expect(tester.takeException(), isNull);

        expect(find.text('Mar'), findsOneWidget);
        expect(find.text('Mar 1 – Mar 7'), findsNothing);
      },
    );

    testWidgets(
      'the current week is the last page: swiping left (toward the '
      'future) from the current week does nothing',
      (tester) async {
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(courses: [aCourse]),
        );

        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.text('Mar'), findsOneWidget);
      },
    );

    testWidgets(
      'an earlier week is fetched lazily exactly once and cached — '
      'revisiting it does not re-fetch',
      (tester) async {
        final earlierWeek = aggregateWeeklyProgress(
          weekStart: DateTime(2026, 3, 1),
          entries: [
            (date: DateTime(2026, 3, 2), questionCount: 3, flashcardCount: 0),
          ],
        );
        final dataService = FakeHomeDataService(
          courses: [aCourse],
          weeklyProgressByWeek: {DateTime(2026, 3, 1): earlierWeek},
        );
        final handle = tester.ensureSemantics();

        int callsFor(DateTime week) =>
            dataService.fetchWeeklyProgressCalls.where((w) => w == week).length;

        await pumpHome(tester, dataService: dataService);
        // The current week is seeded synchronously from the already-eager
        // _loadAll fetch — never a *second*, separate fetch from the card
        // itself.
        expect(callsFor(DateTime(2026, 3, 8)), 1);
        // Mar 1 might already have been fetched once here too, if it's
        // peeking at the current page's left edge — that's fine; the
        // point of this test is that it's never fetched *more* than once.

        await tester.drag(find.byType(PageView), const Offset(400, 0));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Monday, Mar 2, studied'), findsOneWidget);
        expect(callsFor(DateTime(2026, 3, 1)), 1);

        // Back to current, then back to the same earlier week again.
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView), const Offset(400, 0));
        await tester.pumpAndSettle();

        // Still exactly one fetch for Mar 1 — the cached week wasn't
        // fetched again on revisiting it.
        expect(callsFor(DateTime(2026, 3, 1)), 1);
        handle.dispose();
      },
    );

    testWidgets(
      'a failed fetch for an earlier week falls back to an empty week '
      'instead of crashing or retrying forever',
      (tester) async {
        final handle = tester.ensureSemantics();

        await pumpHome(
          tester,
          dataService: FakeHomeDataService(
            courses: [aCourse],
            // The current week's own initial load must still succeed —
            // only the *earlier* (unmapped) week this test swipes to
            // should fail.
            weeklyProgressByWeek: {weekStart: WeeklyProgress.empty(weekStart)},
            weeklyProgressError: Exception('failed-precondition'),
          ),
        );

        await tester.drag(find.byType(PageView), const Offset(400, 0));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.bySemanticsLabel('Monday, Mar 2, no activity'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'a streak still alive as of today (studied yesterday) shows its real '
      'stored value',
      (tester) async {
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(
            courses: [aCourse],
            student: Student(
              uid: 'uid-1',
              email: 'student@example.com',
              name: 'Ghaida',
              currentStreak: 4,
              lastStudyDate: DateTime(2026, 3, 10), // yesterday (now: Wed 3/11)
            ),
          ),
        );

        expect(find.text('4-day streak'), findsOneWidget);
      },
    );

    testWidgets(
      'bug repro: a stale stored streak (real gap since last activity) '
      'shows as broken (0) immediately, not the stale stored count',
      (tester) async {
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(
            courses: [aCourse],
            student: Student(
              uid: 'uid-1',
              email: 'student@example.com',
              name: 'Ghaida',
              currentStreak: 4,
              // 3 days before `now` (Wed 3/11) — nothing has re-run
              // computeNextStreak since it broke, but it's shown as broken
              // right now regardless.
              lastStudyDate: DateTime(2026, 3, 8),
            ),
          ),
        );

        expect(find.text('0-day streak'), findsOneWidget);
        expect(find.text('4-day streak'), findsNothing);
      },
    );

    testWidgets(
      "the gap across a week boundary (the peeking previous week's last "
      "cell to the active week's first cell) equals the gap between cells "
      'inside one week — the strip reads as one continuously-spaced row',
      (tester) async {
        final handle = tester.ensureSemantics();

        await pumpHome(
          tester,
          dataService: FakeHomeDataService(courses: [aCourse]),
        );

        final prevWeekLastCell = tester.getRect(
          find.bySemanticsLabel('Saturday, Mar 7, no activity'),
        );
        final activeWeekFirstCell = tester.getRect(
          find.bySemanticsLabel('Sunday, Mar 8, no activity'),
        );
        final activeWeekSecondCell = tester.getRect(
          find.bySemanticsLabel('Monday, Mar 9, no activity'),
        );

        final innerGap = activeWeekSecondCell.left - activeWeekFirstCell.right;
        final crossBoundaryGap =
            activeWeekFirstCell.left - prevWeekLastCell.right;

        expect(innerGap, 8);
        expect(crossBoundaryGap, innerGap);
        handle.dispose();
      },
    );

    testWidgets(
      "the panel's bottom padding (below the day labels) equals its top "
      'padding (above the "N-day streak" line) — 14dp each',
      (tester) async {
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(courses: [aCourse]),
        );

        final panel = tester.getRect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    Colors.white.withValues(alpha: 0.1) &&
                (w.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(18),
          ),
        );
        // The header Row's own position (not the streak text inside it) —
        // the Row's height is dictated by its tallest child (the 24dp back
        // button), so different text inside it can sit a couple of px
        // lower than the Row's own top edge, purely from cross-axis
        // centering of text with a different line-height; the Row's own
        // top is where the Padding actually places it, unaffected by that.
        final headerRow = tester.getRect(
          find.ancestor(
            of: find.text('0-day streak'),
            matching: find.byType(Row),
          ).first,
        );
        final dayLabel = tester.getRect(find.text('S 8'));

        final topPadding = headerRow.top - panel.top;
        final bottomPadding = panel.bottom - dayLabel.bottom;

        expect(topPadding, 14);
        expect(bottomPadding, topPadding);
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
        resumePosition: 7,
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
      expect(find.text('6 of 15 answered'), findsOneWidget);
      expect(find.text('Resume at question 7'), findsOneWidget);
      expect(find.text('Nothing in progress'), findsNothing);
    });

    testWidgets(
      'tapping Resume opens the real Flashcard Flip Deck screen at the '
      'stored position — regression test for a bug where this opened a '
      'placeholder instead',
      (tester) async {
        final inProgress = InProgressSession(
          sessionId: 's1',
          kind: SessionKind.flashcard,
          courseId: 'c1',
          courseName: 'IS230',
          currentIndex: 2,
          total: 20,
          resumePosition: 3,
        );
        final session = FlashcardSession(
          sessionId: 's1',
          createdAt: DateTime(2026, 3, 1),
          difficultyLevels: const [DifficultyLevel.medium],
          email: 'e@x.com',
          courseId: 'c1',
          materialIds: const ['m1'],
          materialTitles: const ['Lecture 1'],
          numberOfFlashcards: 3,
          currentFlashcardIndex: 2,
          knownCount: 1,
          needsReviewCount: 1,
        );
        final cards = [
          Flashcard(
            flashcardId: 'f1',
            frontText: 'front-1',
            backText: 'back-1',
            reviewStatus: ReviewStatus.knowIt,
            sourceLocation: 'Slide 1',
            sessionId: 's1',
            cardIndex: 0,
          ),
          Flashcard(
            flashcardId: 'f2',
            frontText: 'front-2',
            backText: 'back-2',
            reviewStatus: ReviewStatus.needsReview,
            sourceLocation: 'Slide 2',
            sessionId: 's1',
            cardIndex: 1,
          ),
          Flashcard(
            flashcardId: 'f3',
            frontText: 'front-3',
            backText: 'back-3',
            reviewStatus: null,
            sourceLocation: 'Slide 3',
            sessionId: 's1',
            cardIndex: 2,
          ),
        ];
        await pumpHome(
          tester,
          dataService: FakeHomeDataService(
            courses: [aCourse],
            inProgress: inProgress,
          ),
          flashcardService: FakeFlashcardService(
            sessions: [session],
            flashcardsBySessionId: {'s1': cards},
          ),
        );

        // The streak row's new bottom padding makes this screen's content
        // tall enough that the button can land under the fixed bottom nav
        // bar at this test viewport size — ensureVisible scrolls it into
        // the scrollable area first, same as a real device would need a
        // real scroll gesture for a long enough Home screen.
        await tester.ensureVisible(find.text('Resume at card 3'));
        await tester.tap(find.text('Resume at card 3'));
        await tester.pumpAndSettle();

        expect(find.text('Flashcard session screen'), findsNothing);
        expect(find.text('Card 3 of 3'), findsOneWidget);
        expect(find.text('front-3'), findsOneWidget);
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
        'picking a real course closes the sheet and opens the real Quiz sessions screen',
        (tester) async {
          // At least one material, so the fresh materials check (added to
          // guard against opening sessions for a still-locked course)
          // lets this through to the sessions screen as before.
          await pumpHome(
            tester,
            dataService: FakeHomeDataService(courses: [aCourse]),
            coursesService: FakeCoursesService(
              courses: [aCourse],
              materialsByCourse: {
                'c1': [
                  StudyMaterial(
                    materialId: 'm1',
                    title: 'Lecture 1',
                    type: 'pptx',
                    document: 'd',
                    courseId: 'c1',
                    extractedText: 't',
                  ),
                ],
              },
            ),
          );

          await tester.tap(find.text('New Quiz'));
          await tester.pumpAndSettle();
          expect(find.text('IS230'), findsOneWidget);

          await tester.tap(find.text('IS230'));
          // Not pumpAndSettle: QuizSessionsScreen shows a CircularProgress-
          // Indicator while its Firestore fetch is pending (no real Firebase
          // app in this test, so it never resolves) — an indeterminate
          // spinner animates forever, which would make pumpAndSettle hang.
          // One pump for the materials-check Future to resolve, one for the
          // sheet closing, one for the route's push transition — enough to
          // prove navigation happened; the header renders synchronously,
          // independent of the sessions screen's own pending fetch.
          // QuizSessionsScreen's own states are covered by
          // test/screens/quiz_sessions_screen_test.dart.
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('Quiz sessions'), findsOneWidget);
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

      testWidgets(
        'picking a course with zero materials opens its Course Detail page '
        'instead of Quiz sessions, with a heads-up SnackBar',
        (tester) async {
          await pumpHome(
            tester,
            dataService: FakeHomeDataService(courses: [aCourse]),
            coursesService: FakeCoursesService(courses: [aCourse]),
          );

          await tester.tap(find.text('New Quiz'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('IS230'));
          await tester.pumpAndSettle();

          expect(find.byType(CourseDetailScreen), findsOneWidget);
          expect(find.text('Quiz sessions'), findsNothing);
          expect(
            find.text('Upload a material first to start a quiz.'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'picking a course with at least one material opens the real Quiz '
        'sessions screen',
        (tester) async {
          await pumpHome(
            tester,
            dataService: FakeHomeDataService(courses: [aCourse]),
            coursesService: FakeCoursesService(
              courses: [aCourse],
              materialsByCourse: {
                'c1': [
                  StudyMaterial(
                    materialId: 'm1',
                    title: 'Lecture 1',
                    type: 'pptx',
                    document: 'd',
                    courseId: 'c1',
                    extractedText: 't',
                  ),
                ],
              },
            ),
          );

          await tester.tap(find.text('New Quiz'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('IS230'));
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('Quiz sessions'), findsOneWidget);
          expect(find.byType(CourseDetailScreen), findsNothing);
        },
      );

      testWidgets(
        'picking a course with zero materials for Flashcards also opens '
        'Course Detail instead of Flashcard sessions',
        (tester) async {
          await pumpHome(
            tester,
            dataService: FakeHomeDataService(courses: [aCourse]),
            coursesService: FakeCoursesService(courses: [aCourse]),
          );

          await tester.tap(find.text('New Flashcards'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('IS230'));
          await tester.pumpAndSettle();

          expect(find.byType(CourseDetailScreen), findsOneWidget);
          expect(find.byType(FlashcardSessionsScreen), findsNothing);
          expect(
            find.text('Upload a material first to start flashcards.'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'picking a course with at least one material opens the real '
        'Flashcard sessions screen',
        (tester) async {
          await pumpHome(
            tester,
            dataService: FakeHomeDataService(courses: [aCourse]),
            coursesService: FakeCoursesService(
              courses: [aCourse],
              materialsByCourse: {
                'c1': [
                  StudyMaterial(
                    materialId: 'm1',
                    title: 'Lecture 1',
                    type: 'pptx',
                    document: 'd',
                    courseId: 'c1',
                    extractedText: 't',
                  ),
                ],
              },
            ),
            flashcardService: FakeFlashcardService(),
          );

          await tester.tap(find.text('New Flashcards'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('IS230'));
          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.byType(FlashcardSessionsScreen), findsOneWidget);
          expect(find.byType(CourseDetailScreen), findsNothing);
        },
      );
    },
  );

  group('bottom navigation', () {
    testWidgets(
      'switches between Home, Courses, the real Calendar, and Profile',
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
        // The real Calendar tab, not a placeholder: its month title and
        // Add Event action are what prove the right screen is mounted.
        expect(find.text('Add Event'), findsOneWidget);
        expect(find.text('March 2026'), findsOneWidget);

        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        // The real Profile tab, not a placeholder: its section headings are
        // what prove the right screen is mounted.
        expect(find.text('Student Summary'), findsOneWidget);
        expect(find.text('Log Out'), findsOneWidget);

        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();
        expect(find.text("Today's progress"), findsOneWidget);
      },
    );

    testWidgets(
      'deleting an event on the Calendar tab refreshes Home\'s Upcoming list',
      (tester) async {
        // Home's Upcoming section reads real events, so it must re-read
        // after the Calendar changes them rather than showing a stale list.
        final dataService = FakeHomeDataService(courses: [aCourse]);
        final calendarService = FakeCalendarService(
          events: [
            CalendarEvent(
              eventId: 'e9',
              eventName: 'Midterm',
              eventDate: DateTime(2026, 3, 14),
              eventTime: '12:00',
              email: 'e@x.com',
            ),
          ],
        );
        await pumpHome(
          tester,
          dataService: dataService,
          calendarService: calendarService,
        );
        final before = dataService.fetchUpcomingEventsCalls;

        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('14'));
        await tester.pumpAndSettle();
        // The row's delete control is now a labelled tinted button, and the
        // confirm's action reads "Delete event" (the unified Calendar design).
        await tester.tap(find.bySemanticsLabel('Delete event'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete event'));
        await tester.pumpAndSettle();

        expect(calendarService.deletedEventIds, ['e9']);
        expect(dataService.fetchUpcomingEventsCalls, greaterThan(before));
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
      'Profile Log Out signs out once the confirmation is accepted',
      (tester) async {
        // Taller than the 800x600 default so Profile's Log Out button is
        // on screen — tap() does not scroll. Width is left alone so Home's
        // own layout is unchanged.
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        var signedOut = false;
        await pumpHome(tester, onSignOut: () => signedOut = true);

        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();

        // The confirm is a team decision departing from the SRS, so assert
        // that signing out really does wait for it.
        expect(signedOut, isFalse);

        await tester.tap(find.text('Log out'));
        await tester.pumpAndSettle();

        expect(signedOut, isTrue);
      },
    );

    testWidgets(
      'declining the Profile Log Out confirmation stays signed in',
      (tester) async {
        // Taller than the 800x600 default so Profile's Log Out button is
        // on screen — tap() does not scroll. Width is left alone so Home's
        // own layout is unchanged.
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        var signedOut = false;
        await pumpHome(tester, onSignOut: () => signedOut = true);

        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Stay signed in'));
        await tester.pumpAndSettle();

        expect(signedOut, isFalse);
      },
    );
  });
}
