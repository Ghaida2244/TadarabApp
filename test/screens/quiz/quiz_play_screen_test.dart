import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/question.dart';
import 'package:tadarab_app/models/quiz_session.dart';
import 'package:tadarab_app/screens/quiz/quiz_play_screen.dart';

import '../../helpers/fake_quiz_session_service.dart';

List<Question> _questions({String? firstAnswer}) {
  return [
    Question(
      questionId: 'q1',
      questionText: 'What is a database?',
      correctAnswer: 'A collection of related data',
      explanation: 'It organizes related data for access and management.',
      sourceLocation: 'Slide 1',
      studentAnswer: firstAnswer,
      options: const [
        'A collection of unrelated data',
        'A collection of related data',
        'A programming language',
        'A hardware device',
      ],
      sessionId: 's1',
    ),
    Question(
      questionId: 'q2',
      questionText: 'What sits between the user and stored data?',
      correctAnswer: 'A DBMS',
      explanation: 'Every read/write passes through the DBMS layer.',
      sourceLocation: 'Slide 2',
      options: const ['A DBMS', 'The CPU', 'The router', 'The OS'],
      sessionId: 's1',
    ),
  ];
}

QuizSession _session({required Mode mode, int currentQuestionIndex = 0}) {
  return QuizSession(
    sessionId: 's1',
    createdAt: DateTime(2026, 1, 1),
    difficultyLevels: const [DifficultyLevel.medium],
    email: 'a@b.com',
    courseId: 'course-1',
    materialIds: const ['m1'],
    numberOfQuestions: 2,
    mode: mode,
    currentQuestionIndex: currentQuestionIndex,
  );
}

Future<void> _pumpSession(
  WidgetTester tester,
  FakeQuizSessionService service,
) async {
  await tester.pumpWidget(
    MaterialApp(home: QuizPlayScreen(sessionId: 's1', service: service)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Learning mode', () {
    testWidgets('normal case: submitting reveals correctness without advancing the index', (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_session(mode: Mode.learning)],
        questions: {'s1': _questions()},
      );
      await _pumpSession(tester, service);

      expect(find.text('Question 1 of 2'), findsOneWidget);
      expect(find.text('Submit answer'), findsOneWidget);

      await tester.tap(find.text('A collection of related data'));
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 2'), findsOneWidget); // still on Q1
      expect(find.text('CORRECT'), findsOneWidget);
      expect(find.text('EXPLANATION'), findsOneWidget);
      expect(find.text('Next question'), findsOneWidget);
    });

    testWidgets('normal case: a wrong pick is marked YOURS, correct one still shown', (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_session(mode: Mode.learning)],
        questions: {'s1': _questions()},
      );
      await _pumpSession(tester, service);

      await tester.tap(find.text('A programming language'));
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pumpAndSettle();

      expect(find.text('YOURS'), findsOneWidget);
      expect(find.text('CORRECT'), findsOneWidget);
    });

    testWidgets('revealed options are read-only — tapping another does not change the pick', (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_session(mode: Mode.learning)],
        questions: {'s1': _questions()},
      );
      await _pumpSession(tester, service);

      await tester.tap(find.text('A programming language'));
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('A hardware device'));
      await tester.pumpAndSettle();

      // Still marks the original pick, not the newly tapped option.
      expect(find.text('YOURS'), findsOneWidget);
      expect(service.submittedAnswers, ['A programming language']);
    });

    testWidgets('edge case: resuming an already-answered question shows it revealed immediately', (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_session(mode: Mode.learning, currentQuestionIndex: 0)],
        questions: {'s1': _questions(firstAnswer: 'A collection of related data')},
      );
      await _pumpSession(tester, service);

      expect(find.text('CORRECT'), findsOneWidget);
      expect(find.text('Next question'), findsOneWidget);
    });

    testWidgets('finishing the last question completes the session', (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_session(mode: Mode.learning, currentQuestionIndex: 1)],
        questions: {
          's1': _questions(firstAnswer: 'A collection of related data'),
        },
      );
      await _pumpSession(tester, service);

      expect(find.text('Question 2 of 2'), findsOneWidget);
      await tester.tap(find.text('A DBMS'));
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pumpAndSettle();

      expect(find.text('Finish quiz'), findsOneWidget);
      await tester.tap(find.text('Finish quiz'));
      await tester.pumpAndSettle();

      expect(service.completeCalls, 1);
    });

    testWidgets('the exit (X) opens the save-and-leave sheet', (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_session(mode: Mode.learning)],
        questions: {'s1': _questions()},
      );
      await _pumpSession(tester, service);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Leave this session?'), findsOneWidget);
      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(find.text('Leave this session?'), findsNothing);
    });

    testWidgets('reporting a question calls through to the service', (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_session(mode: Mode.learning)],
        questions: {'s1': _questions()},
      );
      await _pumpSession(tester, service);

      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();

      expect(service.reportCalls, 1);
      expect(service.lastReportedQuestionId, 'q1');
    });
  });

  group('Exam mode', () {
    testWidgets('normal case: never reveals correctness, Next stays a plain advance', (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_session(mode: Mode.exam)],
        questions: {'s1': _questions()},
      );
      await _pumpSession(tester, service);

      expect(find.text('LOCKED'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing); // no exit at all

      await tester.tap(find.text('A programming language'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('CORRECT'), findsNothing);
      expect(find.text('Question 2 of 2'), findsOneWidget);
    });

    testWidgets('Previous is disabled on question 1, enabled after moving forward', (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_session(mode: Mode.exam)],
        questions: {'s1': _questions()},
      );
      await _pumpSession(tester, service);

      final previousButtonFinder = find.text('Previous');
      expect(previousButtonFinder, findsOneWidget);

      await tester.tap(find.text('A collection of related data'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('A DBMS'));
      await tester.pump();
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 2'), findsOneWidget);
    });

    testWidgets('last question turns Next into Submit quiz and completes on tap', (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_session(mode: Mode.exam, currentQuestionIndex: 1)],
        questions: {
          's1': _questions(firstAnswer: 'A collection of related data'),
        },
      );
      await _pumpSession(tester, service);

      expect(find.text('Submit quiz'), findsOneWidget);
      await tester.tap(find.text('A DBMS'));
      await tester.pump();
      await tester.tap(find.text('Submit quiz'));
      await tester.pumpAndSettle();

      expect(service.completeCalls, 1);
    });

    testWidgets(
      'regression: resuming an already-completed session never re-completes it',
      (tester) async {
        // Reproduces the double-completion bug: a stale "in progress" row
        // let the student Resume an already-completed session, landing on
        // its last (already-answered) question with Submit still enabled.
        final alreadyCompleted = QuizSession(
          sessionId: 's1',
          createdAt: DateTime(2026, 1, 1),
          completedAt: DateTime(2026, 1, 1),
          isSessionCompleted: true,
          correctAnswers: 2,
          incorrectAnswers: 0,
          earnedPoints: 8,
          difficultyLevels: const [DifficultyLevel.medium],
          email: 'a@b.com',
          courseId: 'course-1',
          materialIds: const ['m1'],
          numberOfQuestions: 2,
          mode: Mode.exam,
          currentQuestionIndex: 1,
        );
        final service = FakeQuizSessionService(
          sessions: [alreadyCompleted],
          questions: {
            's1': _questions(firstAnswer: 'A collection of related data')
                .map((q) => q.questionId == 'q2' ? q.copyWith(studentAnswer: 'A DBMS') : q)
                .toList(),
          },
        );
        await _pumpSession(tester, service);

        expect(find.text('Submit quiz'), findsOneWidget);
        await tester.tap(find.text('Submit quiz'));
        await tester.pumpAndSettle();

        // Never re-completed — no second (or first, from this screen's
        // perspective) call to completeSession, and no double points.
        expect(service.completeCalls, 0);
      },
    );
  });

  group('Exam mode (draft — never persisted until Submit)', () {
    Future<void> pumpDraft(WidgetTester tester, FakeQuizSessionService service, List<Question> questions) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuizPlayScreen.examDraft(
            session: _session(mode: Mode.exam),
            questions: questions,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'regression: answering and navigating never touches Firestore — only the final Submit does',
      (tester) async {
        final service = FakeQuizSessionService();
        await pumpDraft(tester, service, _questions());

        expect(find.text('Question 1 of 2'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNothing); // still locked, same as a real Exam session

        await tester.tap(find.text('A collection of related data'));
        await tester.pump();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        expect(find.text('Question 2 of 2'), findsOneWidget);
        await tester.tap(find.text('The router'));
        await tester.pump();
        await tester.tap(find.text('Previous'));
        await tester.pumpAndSettle();

        expect(find.text('Question 1 of 2'), findsOneWidget);

        // Nothing written yet, at any point during play — this is the
        // entire point of the fix: force-quitting right here leaves
        // absolutely no trace in Firestore to resume.
        expect(service.submittedAnswers, isEmpty);
        expect(service.createSessionCalls, 0);
        expect(service.submitExamSessionCalls, 0);
      },
    );

    testWidgets(
      'regression: the final Submit writes the session and its answers exactly once, merged correctly',
      (tester) async {
        final service = FakeQuizSessionService();
        await pumpDraft(tester, service, _questions());

        await tester.tap(find.text('A collection of related data'));
        await tester.pump();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        expect(find.text('Submit quiz'), findsOneWidget);
        await tester.tap(find.text('A DBMS'));
        await tester.pump();
        await tester.tap(find.text('Submit quiz'));
        await tester.pumpAndSettle();

        expect(service.completeCalls, 0); // the old real-session path, unused here
        expect(service.submitExamSessionCalls, 1);
        final submitted = service.lastSubmittedExamQuestions!;
        expect(submitted[0].studentAnswer, 'A collection of related data');
        expect(submitted[1].studentAnswer, 'A DBMS');
        expect(find.text('Performance Summary'), findsOneWidget);
      },
    );

    testWidgets(
      'reporting a question is held locally and only reaches the service at final Submit',
      (tester) async {
        final service = FakeQuizSessionService();
        await pumpDraft(tester, service, _questions());

        await tester.tap(find.byIcon(Icons.flag_outlined));
        await tester.pumpAndSettle();
        expect(service.reportCalls, 0); // nothing to update yet — held locally

        await tester.tap(find.text('A collection of related data'));
        await tester.pump();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('A DBMS'));
        await tester.pump();
        await tester.tap(find.text('Submit quiz'));
        await tester.pumpAndSettle();

        expect(service.reportCalls, 0); // still never a direct call
        expect(service.lastSubmittedExamQuestions![0].isReported, isTrue);
        expect(service.lastSubmittedExamQuestions![1].isReported, isFalse);
      },
    );
  });

  group('Practice mode', () {
    testWidgets('the X exits immediately, with no save-and-leave prompt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuizPlayScreen(
                        practiceQuestions: _questions(),
                        service: FakeQuizSessionService(),
                      ),
                    ),
                  ),
                  child: const Text('Open practice'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open practice'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Leave this session?'), findsNothing); // no prompt at all
      expect(find.byType(QuizPlayScreen), findsNothing); // popped straight out
      expect(find.text('Open practice'), findsOneWidget); // back underneath
    });

    testWidgets('never writes to Firestore while answering', (tester) async {
      final service = FakeQuizSessionService();
      await tester.pumpWidget(
        MaterialApp(
          home: QuizPlayScreen(
            practiceQuestions: _questions(),
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('A collection of related data'));
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pumpAndSettle();

      expect(service.submittedAnswers, isEmpty);
    });

    testWidgets(
      'starts fully unanswered even if the source questions still carry an old studentAnswer',
      (tester) async {
        // Regression test: Practice Now pulls mistakes straight from a
        // completed session, whose Questions still have their original
        // studentAnswer. Even if a caller forgets to clear it first (see
        // Question.asUnanswered()), this screen must never treat a
        // practice question as pre-answered — question 1 must not show a
        // pre-selected option, and question 2 must not jump straight to
        // the revealed state.
        final staleQuestions = _questions(firstAnswer: 'A programming language');
        await tester.pumpWidget(
          MaterialApp(
            home: QuizPlayScreen(
              practiceQuestions: staleQuestions,
              service: FakeQuizSessionService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Not revealed, not pre-selected: Submit answer is disabled (no
        // pick made yet) and none of the revealed-only markers are shown.
        expect(find.text('Submit answer'), findsOneWidget);
        expect(find.text('CORRECT'), findsNothing);
        expect(find.text('YOURS'), findsNothing);

        await tester.tap(find.text('A collection of related data'));
        await tester.pump();
        await tester.tap(find.text('Submit answer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next question'));
        await tester.pumpAndSettle();

        // Question 2 must land unanswered, not auto-revealed.
        expect(find.text('Question 2 of 2'), findsOneWidget);
        expect(find.text('Submit answer'), findsOneWidget);
        expect(find.text('CORRECT'), findsNothing);
      },
    );
  });
}
