import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/question.dart';
import 'package:tadarab_app/models/quiz_session.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/screens/quiz/quiz_navigation.dart';
import 'package:tadarab_app/screens/quiz/quiz_sessions_screen.dart';
import 'package:tadarab_app/services/quiz_session_service.dart';
import 'package:tadarab_app/widgets/app_button.dart';

import '../../helpers/fake_quiz_session_service.dart';

AppButton _retakeButton(WidgetTester tester) => tester.widget<AppButton>(
  find.byWidgetPredicate((w) => w is AppButton && w.label == 'Retake quiz'),
);

QuizSession _session({
  required String id,
  required bool completed,
  Mode mode = Mode.exam,
  int currentQuestionIndex = 3,
  int correctAnswers = 8,
}) {
  return QuizSession(
    sessionId: id,
    createdAt: DateTime(2026, 1, 1),
    isSessionCompleted: completed,
    difficultyLevels: const [DifficultyLevel.medium],
    email: 'a@b.com',
    courseId: 'course-1',
    materialIds: const ['m1'],
    numberOfQuestions: 10,
    mode: mode,
    currentQuestionIndex: currentQuestionIndex,
    correctAnswers: correctAnswers,
  );
}

Future<void> _pump(WidgetTester tester, FakeQuizSessionService service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: QuizSessionsScreen(
        courseId: 'course-1',
        courseName: 'IS230',
        service: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state: no sessions shows the empty-state copy', (
    tester,
  ) async {
    await _pump(tester, FakeQuizSessionService());

    expect(find.text('No sessions yet'), findsOneWidget);
    expect(find.text('0 sessions'), findsOneWidget);
    expect(find.text('Start new quiz'), findsOneWidget);
  });

  testWidgets(
    'normal case: grouped sessions show headers and the right action label',
    (tester) async {
      final service = FakeQuizSessionService(
        sessions: [
          _session(id: 'done-1', completed: true),
          _session(
            id: 'inprogress-1',
            completed: false,
            currentQuestionIndex: 4,
          ),
        ],
      );
      await _pump(tester, service);

      expect(find.text('2 sessions'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('Resume at question 5'), findsOneWidget);
      expect(find.text('View performance summary'), findsOneWidget);
      expect(find.text('Retake quiz'), findsOneWidget);
    },
  );

  testWidgets('edge case: an in-progress session has no Retake button', (
    tester,
  ) async {
    final service = FakeQuizSessionService(
      sessions: [_session(id: 's1', completed: false)],
    );
    await _pump(tester, service);

    expect(find.text('Retake quiz'), findsNothing);
  });

  testWidgets(
    'regression: retaking an Exam session plays from an in-memory draft — never a resumable persisted one',
    (tester) async {
      // Retake has to get the same draft-until-submit treatment as a
      // brand-new Exam session — otherwise force-quitting mid-retake
      // would reopen exactly the resumability hole this was all meant to
      // close, just through a second entry point.
      final original = _session(id: 's1', completed: true); // mode: Mode.exam
      final freshQuestions = [
        Question(
          questionId: 'q1',
          questionText: 'Fresh question',
          correctAnswer: 'A',
          explanation: 'E',
          sourceLocation: 'Slide 1',
          options: const ['A', 'B', 'C', 'D'],
          sessionId: 's1',
        ),
      ];
      final service = FakeQuizSessionService(
        sessions: [original],
        retakeSessionResult: GeneratedSessionResult(
          session: QuizSession(
            sessionId: 's1',
            createdAt: original.createdAt,
            difficultyLevels: original.difficultyLevels,
            email: original.email,
            courseId: original.courseId,
            materialIds: original.materialIds,
            numberOfQuestions: 1,
            mode: Mode.exam,
          ),
          note: null,
          requestedCount: 1,
          questions: freshQuestions,
        ),
      );
      await _pump(tester, service);
      final loadsBeforeRetake = service.fetchSessionsCalls;

      await tester.tap(find.text('Retake quiz'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 1'), findsOneWidget);
      // Retake itself wrote nothing and reloaded nothing — there's
      // nothing to reload, since nothing changed in Firestore yet.
      expect(service.fetchSessionsCalls, loadsBeforeRetake);
      expect(service.submitExamSessionCalls, 0);
    },
  );

  group('Retake loading state', () {
    GeneratedSessionResult learningResult(QuizSession original) {
      return GeneratedSessionResult(
        session: QuizSession(
          sessionId: original.sessionId,
          createdAt: original.createdAt,
          difficultyLevels: original.difficultyLevels,
          email: original.email,
          courseId: original.courseId,
          materialIds: original.materialIds,
          numberOfQuestions: 1,
          mode: Mode.learning,
        ),
        note: null,
        requestedCount: 1,
        questions: [
          Question(
            questionId: 'q1',
            questionText: 'Fresh question',
            correctAnswer: 'A',
            explanation: 'E',
            sourceLocation: 'Slide 1',
            options: const ['A', 'B', 'C', 'D'],
            sessionId: original.sessionId,
          ),
        ],
      );
    }

    testWidgets(
      'tapping Retake shows a loading state on the button and disables it',
      (tester) async {
        final original = _session(id: 's1', completed: true, mode: Mode.learning);
        final pending = Completer<GeneratedSessionResult>();
        final service = FakeQuizSessionService(
          sessions: [original],
          pendingRetakeSession: pending,
        );
        await _pump(tester, service);

        expect(_retakeButton(tester).loading, isFalse);

        await tester.tap(find.text('Retake quiz'));
        await tester.pump();

        expect(_retakeButton(tester).loading, isTrue);
        expect(_retakeButton(tester).onPressed, isNull);

        pending.complete(learningResult(original));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'a second tap while loading does not trigger a second retake call',
      (tester) async {
        final original = _session(id: 's1', completed: true, mode: Mode.learning);
        final pending = Completer<GeneratedSessionResult>();
        final service = FakeQuizSessionService(
          sessions: [original],
          pendingRetakeSession: pending,
        );
        await _pump(tester, service);

        await tester.tap(find.text('Retake quiz'));
        await tester.pump();
        expect(service.retakeCalls, 1);

        // The button is disabled while loading, but tap it again anyway to
        // prove the guard in _retake() itself (not just the disabled
        // button) is what prevents a second call.
        await tester.tap(find.text('Retake quiz'), warnIfMissed: false);
        await tester.pump();

        expect(service.retakeCalls, 1);

        pending.complete(learningResult(original));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'loading clears after a successful retake, once popped back to Sessions',
      (tester) async {
        // Exam mode, not Learning: a successful Learning retake flips the
        // session to in-progress, which removes its Retake button entirely
        // (correct, unrelated to loading) — Exam's retake leaves the
        // original completed session in the list untouched (see the
        // existing Exam-retake regression test above), so its Retake
        // button is still there to check.
        final original = _session(id: 's1', completed: true); // mode: Mode.exam
        final service = FakeQuizSessionService(
          sessions: [original],
          retakeSessionResult: GeneratedSessionResult(
            session: QuizSession(
              sessionId: original.sessionId,
              createdAt: original.createdAt,
              difficultyLevels: original.difficultyLevels,
              email: original.email,
              courseId: original.courseId,
              materialIds: original.materialIds,
              numberOfQuestions: 1,
              mode: Mode.exam,
            ),
            note: null,
            requestedCount: 1,
            questions: [
              Question(
                questionId: 'q1',
                questionText: 'Fresh question',
                correctAnswer: 'A',
                explanation: 'E',
                sourceLocation: 'Slide 1',
                options: const ['A', 'B', 'C', 'D'],
                sessionId: original.sessionId,
              ),
            ],
          ),
        );
        await _pump(tester, service);

        await tester.tap(find.text('Retake quiz'));
        await tester.pumpAndSettle();

        // The Exam draft is pushed (not a replacement), so Sessions is
        // still mounted underneath — pop back to check it.
        final navigatorState = tester.state<NavigatorState>(
          find.byType(Navigator),
        );
        navigatorState.pop();
        await tester.pumpAndSettle();

        expect(_retakeButton(tester).loading, isFalse);
        expect(_retakeButton(tester).onPressed, isNotNull);
      },
    );

    testWidgets(
      'loading clears after a failed retake, and shows the error SnackBar',
      (tester) async {
        final original = _session(id: 's1', completed: true, mode: Mode.learning);
        final service = FakeQuizSessionService(
          sessions: [original],
          retakeSessionError: Exception('boom'),
        );
        await _pump(tester, service);

        await tester.tap(find.text('Retake quiz'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Retake failed. Please try again.'), findsOneWidget);
        expect(_retakeButton(tester).loading, isFalse);
        expect(_retakeButton(tester).onPressed, isNotNull);
      },
    );

    testWidgets(
      "a successful retake that falls short of the requested count shows "
      "Flashcards' style of message",
      (tester) async {
        final original = _session(id: 's1', completed: true, mode: Mode.learning);
        final service = FakeQuizSessionService(
          sessions: [original],
          retakeSessionResult: GeneratedSessionResult(
            session: QuizSession(
              sessionId: original.sessionId,
              createdAt: original.createdAt,
              difficultyLevels: original.difficultyLevels,
              email: original.email,
              courseId: original.courseId,
              materialIds: original.materialIds,
              numberOfQuestions: 1,
              mode: Mode.learning,
            ),
            note: null,
            requestedCount: 5,
            questions: [
              Question(
                questionId: 'q1',
                questionText: 'Fresh question',
                correctAnswer: 'A',
                explanation: 'E',
                sourceLocation: 'Slide 1',
                options: const ['A', 'B', 'C', 'D'],
                sessionId: original.sessionId,
              ),
            ],
          ),
          questions: {'s1': []},
        );
        await _pump(tester, service);

        await tester.tap(find.text('Retake quiz'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Generated 1 of 5 requested.'), findsOneWidget);
      },
    );

    testWidgets(
      "a successful retake with the Worker's own note shows that note "
      'instead of a generic message',
      (tester) async {
        final original = _session(id: 's1', completed: true, mode: Mode.learning);
        final service = FakeQuizSessionService(
          sessions: [original],
          retakeSessionResult: GeneratedSessionResult(
            session: QuizSession(
              sessionId: original.sessionId,
              createdAt: original.createdAt,
              difficultyLevels: original.difficultyLevels,
              email: original.email,
              courseId: original.courseId,
              materialIds: original.materialIds,
              numberOfQuestions: 1,
              mode: Mode.learning,
            ),
            note: 'Only easy items were generated this time.',
            requestedCount: 1,
            questions: [
              Question(
                questionId: 'q1',
                questionText: 'Fresh question',
                correctAnswer: 'A',
                explanation: 'E',
                sourceLocation: 'Slide 1',
                options: const ['A', 'B', 'C', 'D'],
                sessionId: original.sessionId,
              ),
            ],
          ),
          questions: {'s1': []},
        );
        await _pump(tester, service);

        await tester.tap(find.text('Retake quiz'));
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Only easy items were generated this time.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a successful retake at the full requested count with no note shows '
      'no SnackBar',
      (tester) async {
        final original = _session(id: 's1', completed: true, mode: Mode.learning);
        final service = FakeQuizSessionService(
          sessions: [original],
          retakeSessionResult: learningResult(original),
          questions: {'s1': []},
        );
        await _pump(tester, service);

        await tester.tap(find.text('Retake quiz'));
        await tester.pump();
        await tester.pump();

        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });

  group('materials badge', () {
    testWidgets(
      'normal case: shows the material title the session was generated from',
      (tester) async {
        final service = FakeQuizSessionService(
          sessions: [
            _session(id: 's1', completed: true),
          ], // default materialIds: ['m1']
          materials: [
            StudyMaterial(
              materialId: 'm1',
              title: 'Lecture 1 — Introduction',
              type: 'pptx',
              document: '',
              courseId: 'course-1',
              extractedText: '',
            ),
          ],
        );
        await _pump(tester, service);

        expect(find.text('Lecture 1 — Introduction'), findsOneWidget);
      },
    );

    testWidgets('edge case: multiple materials are comma-joined', (
      tester,
    ) async {
      final session = QuizSession(
        sessionId: 's1',
        createdAt: DateTime(2026, 1, 1),
        isSessionCompleted: true,
        difficultyLevels: const [DifficultyLevel.medium],
        email: 'a@b.com',
        courseId: 'course-1',
        materialIds: const ['m1', 'm2'],
        numberOfQuestions: 10,
        mode: Mode.exam,
        correctAnswers: 8,
      );
      final service = FakeQuizSessionService(
        sessions: [session],
        materials: [
          StudyMaterial(
            materialId: 'm1',
            title: 'Lecture 1',
            type: 'pptx',
            document: '',
            courseId: 'course-1',
            extractedText: '',
          ),
          StudyMaterial(
            materialId: 'm2',
            title: 'Lecture 2',
            type: 'docx',
            document: '',
            courseId: 'course-1',
            extractedText: '',
          ),
        ],
      );
      await _pump(tester, service);

      expect(find.text('Lecture 1, Lecture 2'), findsOneWidget);
    });

    testWidgets(
      'failure case: a materialId with no matching material falls back to "Material removed"',
      (tester) async {
        final service = FakeQuizSessionService(
          sessions: [
            _session(id: 's1', completed: true),
          ], // materialIds: ['m1']
          materials: const [], // 'm1' resolves to nothing
        );
        await _pump(tester, service);

        expect(find.text('Material removed'), findsOneWidget);
      },
    );

    testWidgets(
      'regression: a label longer than the available space genuinely overflows and can scroll',
      (tester) async {
        final longTitleMaterials = List.generate(
          6,
          (i) => StudyMaterial(
            materialId: 'm$i',
            title: 'A Genuinely Long Lecture Title Number $i',
            type: 'pptx',
            document: '',
            courseId: 'course-1',
            extractedText: '',
          ),
        );
        final session = QuizSession(
          sessionId: 's1',
          createdAt: DateTime(2026, 1, 1),
          isSessionCompleted: true,
          difficultyLevels: const [DifficultyLevel.medium],
          email: 'a@b.com',
          courseId: 'course-1',
          materialIds: longTitleMaterials.map((m) => m.materialId).toList(),
          numberOfQuestions: 10,
          mode: Mode.exam,
          correctAnswers: 8,
        );
        final service = FakeQuizSessionService(
          sessions: [session],
          materials: longTitleMaterials,
        );
        await _pump(tester, service);

        // Scoped to the badge's own SingleChildScrollView specifically, and
        // read via its ScrollableState directly (not Scrollable.of(), which
        // searches *ancestors* — starting from the Scrollable's own element
        // would find the outer sessions ListView's scrollable instead).
        final scrollableFinder = find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        );
        final position = tester
            .state<ScrollableState>(scrollableFinder)
            .position;
        expect(
          position.maxScrollExtent,
          greaterThan(0),
          reason: 'the label is far longer than the card — there must be real overflow to scroll',
        );
      },
    );

    testWidgets(
      'regression: a real horizontal drag on the badge actually moves it, inside the real vertical sessions list',
      (tester) async {
        // maxScrollExtent > 0 only proves the content overflows — it says
        // nothing about whether a real drag gesture actually reaches this
        // Scrollable instead of being claimed by the outer vertical
        // ListView (a gesture-arena conflict, not a layout one). This
        // drives an actual drag through the widget tester's real gesture
        // pipeline — the same arena-resolution code a live app uses — to
        // verify the touch genuinely lands on and moves this scrollable,
        // sitting inside its real ListView.separated context (not pumped
        // in isolation).
        final longTitleMaterials = List.generate(
          6,
          (i) => StudyMaterial(
            materialId: 'm$i',
            title: 'A Genuinely Long Lecture Title Number $i',
            type: 'pptx',
            document: '',
            courseId: 'course-1',
            extractedText: '',
          ),
        );
        final session = QuizSession(
          sessionId: 's1',
          createdAt: DateTime(2026, 1, 1),
          isSessionCompleted: true,
          difficultyLevels: const [DifficultyLevel.medium],
          email: 'a@b.com',
          courseId: 'course-1',
          materialIds: longTitleMaterials.map((m) => m.materialId).toList(),
          numberOfQuestions: 10,
          mode: Mode.exam,
          correctAnswers: 8,
        );
        final service = FakeQuizSessionService(
          sessions: [session],
          materials: longTitleMaterials,
        );
        await _pump(tester, service);

        final scrollableFinder = find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        );
        final position = tester
            .state<ScrollableState>(scrollableFinder)
            .position;
        expect(position.pixels, 0);

        // Drag starting from the badge's own on-screen center — a point
        // that's actually inside the clipped, visible viewport (not the
        // Text's full unclipped geometry, which can extend far outside it).
        final badgeCenter = tester.getCenter(
          find.byType(SingleChildScrollView).first,
        );
        await tester.dragFrom(badgeCenter, const Offset(-80, 0));
        await tester.pump();

        expect(
          position.pixels,
          greaterThan(0),
          reason:
              'a real horizontal drag on the badge must move its own scroll position, not be '
              'swallowed by the outer vertical list',
        );
      },
    );

    testWidgets(
      'regression: the badge itself is genuinely 32px tall, and a drag near its edge still works',
      (tester) async {
        // Two other approaches were tried and confirmed (by failing
        // tests, not just reasoning) not to work: an invisible
        // SizedOverflowBox-based hit-slop can't extend hit-testing at
        // all, and wrapping the small pill in a taller SizedBox+Center
        // hits the same wall one level up (Center still hit-tests against
        // the *child's own* size). The only thing that actually works is
        // the pill itself genuinely being 32px — settled on with the user
        // after confirming that and that matching the nearby EXAM/
        // LEARNING badge's 22px wouldn't meet the reliability floor.
        //
        // Uses several long titles (not just one) to guarantee genuine
        // overflow — a single title, even a long one, can fit within the
        // available card width and never overflow, which would make this
        // test pass for the wrong reason (nothing to scroll, so "no
        // movement" is vacuously true regardless of where the drag starts).
        final longTitleMaterials = List.generate(
          6,
          (i) => StudyMaterial(
            materialId: 'm$i',
            title: 'A Genuinely Long Lecture Title Number $i',
            type: 'pptx',
            document: '',
            courseId: 'course-1',
            extractedText: '',
          ),
        );
        final service = FakeQuizSessionService(
          sessions: [
            QuizSession(
              sessionId: 's1',
              createdAt: DateTime(2026, 1, 1),
              isSessionCompleted: true,
              difficultyLevels: const [DifficultyLevel.medium],
              email: 'a@b.com',
              courseId: 'course-1',
              materialIds: longTitleMaterials.map((m) => m.materialId).toList(),
              numberOfQuestions: 10,
              mode: Mode.exam,
              correctAnswers: 8,
            ),
          ],
          materials: longTitleMaterials,
        );
        await _pump(tester, service);

        final pillSize = tester.getSize(
          find.byType(SingleChildScrollView).first,
        );
        expect(pillSize.height, 32.0);

        final scrollableFinder = find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        );
        final position = tester
            .state<ScrollableState>(scrollableFinder)
            .position;
        expect(position.pixels, 0);
        expect(
          position.maxScrollExtent,
          greaterThan(0),
          reason: 'the setup must force real overflow, or this test would pass vacuously',
        );

        // Start the drag right at the pill's own top edge — under the old
        // ~18px pill this would have been well outside it; now it's
        // genuinely inside the real, hit-testable 32px pill.
        final pillTopLeft = tester.getTopLeft(
          find.byType(SingleChildScrollView).first,
        );
        final nearTopEdge = pillTopLeft + Offset(pillSize.width / 2, 4);
        await tester.dragFrom(nearTopEdge, const Offset(-80, 0));
        await tester.pump();

        expect(
          position.pixels,
          greaterThan(0),
          reason: 'a drag starting near the top edge of the 32px pill must still move it',
        );
      },
    );

    testWidgets('a short label that already fits has nothing to scroll', (
      tester,
    ) async {
      final service = FakeQuizSessionService(
        sessions: [_session(id: 's1', completed: true)], // materialIds: ['m1']
        materials: [
          StudyMaterial(
            materialId: 'm1',
            title: 'L1',
            type: 'pptx',
            document: '',
            courseId: 'course-1',
            extractedText: '',
          ),
        ],
      );
      await _pump(tester, service);

      final scrollableFinder = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollableFinder).position;
      expect(position.maxScrollExtent, 0);
    });
  });

  testWidgets(
    '"X of N answered" reflects actually-answered questions, not currentQuestionIndex',
    (tester) async {
      // currentQuestionIndex is 4 (the student's position — she moved
      // forward via Next/Previous), but only 1 question actually has a
      // studentAnswer. The label must read "1 of 10", never "4 of 10".
      final questions = List.generate(10, (i) {
        return Question(
          questionId: 'q$i',
          questionText: 'Q$i',
          correctAnswer: 'Right',
          explanation: 'E',
          sourceLocation: 'Slide $i',
          studentAnswer: i == 0 ? 'Right' : null,
          options: const ['Right', 'Wrong'],
          sessionId: 's1',
        );
      });
      final service = FakeQuizSessionService(
        sessions: [
          _session(id: 's1', completed: false, currentQuestionIndex: 4),
        ],
        questions: {'s1': questions},
      );
      await _pump(tester, service);

      expect(find.text('1 of 10 answered'), findsOneWidget);
      expect(find.text('4 of 10 answered'), findsNothing);
    },
  );

  testWidgets('delete flow: confirming removes the session from the list', (
    tester,
  ) async {
    final service = FakeQuizSessionService(
      sessions: [_session(id: 's1', completed: true)],
    );
    await _pump(tester, service);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Delete this session?'), findsOneWidget);
    await tester.tap(find.text('Delete session'));
    await tester.pumpAndSettle();

    expect(service.deleteCalls, 1);
    expect(find.text('No sessions yet'), findsOneWidget);
  });

  testWidgets('delete flow: "Keep it" dismisses without deleting', (
    tester,
  ) async {
    final service = FakeQuizSessionService(
      sessions: [_session(id: 's1', completed: true)],
    );
    await _pump(tester, service);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(service.deleteCalls, 0);
    expect(find.text('Delete this session?'), findsNothing);
  });

  testWidgets('tapping "Start new quiz" opens the Quiz setup screen', (
    tester,
  ) async {
    await _pump(tester, FakeQuizSessionService());

    await tester.tap(find.text('Start new quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Quiz setup'), findsOneWidget);
  });

  testWidgets(
    'tapping Resume on an in-progress session opens the play screen',
    (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_session(id: 's1', completed: false)],
        questions: {'s1': []},
      );
      await _pump(tester, service);

      await tester.tap(find.textContaining('Resume at question'));
      await tester.pumpAndSettle();

      // No questions were stubbed for this session, so the Play screen's
      // own empty/error state is what proves navigation actually happened.
      expect(find.text("Couldn't load this quiz."), findsOneWidget);
    },
  );

  testWidgets(
    'regression: reload fires only on genuine return, not at an intermediate pushReplacement',
    (tester) async {
      // Reproduces the exact shape of the real bug: Setup replacing itself
      // with Play, which replaces itself with Summary — pushReplacement's
      // old route completes its own "popped" future immediately, which
      // used to make the .then()-based reload fire right after the first
      // replacement (i.e. right after generation, before the quiz was
      // ever finished). The RouteObserver-based fix must not fire until
      // Sessions is genuinely visible again.
      final service = FakeQuizSessionService(
        sessions: [
          _session(id: 's1', completed: false, currentQuestionIndex: 0),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [quizSessionsRouteObserver],
          home: QuizSessionsScreen(
            courseId: 'course-1',
            courseName: 'IS230',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final callsOnFirstLoad = service.fetchSessionsCalls;

      final navigatorState = tester.state<NavigatorState>(
        find.byType(Navigator),
      );

      // "Setup" pushed (mirrors _openSetup).
      unawaited(
        navigatorState.push(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Setup placeholder')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Setup" generates and replaces itself with "Play".
      unawaited(
        navigatorState.pushReplacement(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Play placeholder')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Must NOT have reloaded yet — we're mid-flow, not back on Sessions.
      expect(service.fetchSessionsCalls, callsOnFirstLoad);

      // "Play" finishes and replaces itself with "Summary".
      unawaited(
        navigatorState.pushReplacement(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Summary placeholder')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Still must not have reloaded.
      expect(service.fetchSessionsCalls, callsOnFirstLoad);

      // Genuinely back on Sessions now.
      navigatorState.pop();
      await tester.pumpAndSettle();

      expect(find.text('Quiz sessions'), findsOneWidget);
      expect(service.fetchSessionsCalls, callsOnFirstLoad + 1);
    },
  );
}
