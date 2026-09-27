import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/question.dart';
import 'package:tadarab_app/models/quiz_session.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/screens/quiz/quiz_setup_screen.dart';
import 'package:tadarab_app/services/quiz_generation_client.dart';
import 'package:tadarab_app/services/quiz_session_service.dart';

import '../../helpers/fake_quiz_session_service.dart';

final _material = StudyMaterial(
  materialId: 'm1',
  title: 'Lecture 1 — Intro',
  type: 'pptx',
  document: '',
  courseId: 'course-1',
  extractedText: '',
);

QuizSession _newSession({int numberOfQuestions = 5, Mode mode = Mode.exam}) {
  return QuizSession(
    sessionId: 'new-session',
    createdAt: DateTime(2026, 1, 1),
    difficultyLevels: const [DifficultyLevel.medium],
    email: 'a@b.com',
    courseId: 'course-1',
    materialIds: const ['m1'],
    numberOfQuestions: numberOfQuestions,
    mode: mode,
  );
}

// createSession never persists anything at generation time, for either
// mode (see its doc comment) — QuizPlayScreen plays an Exam session from
// this in-memory draft directly, and a Learning session only after
// commitLearningSession actually writes it. Any test whose
// createSessionResult actually navigates away needs a questions list, or
// GeneratedSessionResult's now-required `questions` field has nothing to
// give it.
List<Question> _draftQuestions({int count = 5}) {
  return List.generate(
    count,
    (i) => Question(
      questionId: 'q$i',
      questionText: 'Question $i',
      correctAnswer: 'Right',
      explanation: 'Because.',
      sourceLocation: 'Slide $i',
      options: const ['Right', 'Wrong', 'Other', 'Another'],
      sessionId: 'new-session',
    ),
  );
}

Future<void> _pump(WidgetTester tester, FakeQuizSessionService service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: QuizSetupScreen(
        courseId: 'course-1',
        courseName: 'IS230',
        service: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('normal case: Generate does nothing until a material is selected', (tester) async {
    final service = FakeQuizSessionService(
      materials: [_material],
      createSessionResult: GeneratedSessionResult(
        session: _newSession(),
        note: null,
        requestedCount: 5,
        questions: _draftQuestions(),
      ),
    );
    await _pump(tester, service);

    await tester.tap(find.text('Generate quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Quiz setup'), findsOneWidget); // still here
    expect(service.createSessionCalls, 0);
  });

  testWidgets(
    'regression: an Exam-mode generation lands on an in-memory draft, not a persisted session',
    (tester) async {
      // The whole point of the Exam draft-until-submit design: nothing
      // about this session should be resumable if the student leaves
      // before finishing it. Answering a question here must not call
      // through to submitAnswer/setCurrentQuestionIndex at all — those
      // are exactly the incremental writes that used to make an
      // incomplete Exam session resumable.
      final service = FakeQuizSessionService(
        materials: [_material],
        createSessionResult: GeneratedSessionResult(
          session: _newSession(numberOfQuestions: 5),
          note: null,
          requestedCount: 5,
          questions: _draftQuestions(),
        ),
      );
      await _pump(tester, service);

      await tester.tap(find.text('Select materials'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lecture 1 — Intro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate quiz'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 5'), findsOneWidget);

      await tester.tap(find.text('Right'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Question 2 of 5'), findsOneWidget);
      expect(service.submittedAnswers, isEmpty);
      expect(service.submitExamSessionCalls, 0);
    },
  );

  testWidgets('materials expand/select, difficulty and count all drive Generate', (tester) async {
    final service = FakeQuizSessionService(
      materials: [_material],
      createSessionResult: GeneratedSessionResult(
        session: _newSession(),
        note: null,
        requestedCount: 5,
        questions: _draftQuestions(),
      ),
    );
    await _pump(tester, service);

    // Materials collapsed by default.
    expect(find.text('Select materials'), findsOneWidget);
    expect(find.text('Lecture 1 — Intro'), findsNothing);

    await tester.tap(find.text('Select materials'));
    await tester.pumpAndSettle();
    expect(find.text('Lecture 1 — Intro'), findsOneWidget);

    await tester.tap(find.text('Lecture 1 — Intro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Quiz setup'), findsNothing); // navigated away (pushReplacement)
  });

  testWidgets('edge case: the last selected difficulty cannot be deselected', (tester) async {
    await _pump(tester, FakeQuizSessionService(materials: [_material]));

    // Medium is selected by default; tapping it again should not clear it.
    await tester.tap(find.text('Medium'));
    await tester.pumpAndSettle();

    final mediumContainer = tester.widget<Container>(
      find
          .ancestor(of: find.text('Medium'), matching: find.byType(Container))
          .first,
    );
    final decoration = mediumContainer.decoration! as BoxDecoration;
    // Still selected (navy fill), not deselected to white.
    expect(decoration.color, isNot(Colors.white));
  });

  testWidgets('normal case: the count stepper respects the minimum of 5', (tester) async {
    await _pump(tester, FakeQuizSessionService(materials: [_material]));

    expect(find.text('5'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
    }
    expect(find.text('5'), findsOneWidget); // never drops below 5
  });

  testWidgets('normal case: incrementing the stepper has no upper cap', (tester) async {
    await _pump(tester, FakeQuizSessionService(materials: [_material]));

    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
    }
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('extra instructions: counter warns approaching, then at, the 300 limit', (tester) async {
    await _pump(tester, FakeQuizSessionService(materials: [_material]));

    await tester.enterText(find.byType(TextField).last, 'x' * 265);
    await tester.pump();
    expect(find.text('Approaching the limit'), findsOneWidget);
    expect(find.text('265/300'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'x' * 300);
    await tester.pump();
    expect(find.text('Character limit reached'), findsOneWidget);
    expect(find.text('300/300'), findsOneWidget);
  });

  testWidgets('a quick chip fills the extra-instructions field with its own text', (tester) async {
    await _pump(tester, FakeQuizSessionService(materials: [_material]));

    await tester.ensureVisible(find.text('Focus on definitions'));
    await tester.tap(find.text('Focus on definitions'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, 'Focus on definitions');
    expect(find.text('${'Focus on definitions'.length}/300'), findsOneWidget);
  });

  testWidgets('limit dialog: fewer questions generated than requested', (tester) async {
    final service = FakeQuizSessionService(
      materials: [_material],
      createSessionResult: GeneratedSessionResult(
        session: _newSession(numberOfQuestions: 3),
        note: null,
        requestedCount: 5,
        questions: _draftQuestions(count: 3),
      ),
    );
    await _pump(tester, service);

    await tester.tap(find.text('Select materials'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lecture 1 — Intro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Fewer questions than asked'), findsOneWidget);
    expect(
      find.textContaining('Your material supported 3 solid questions out of the 5'),
      findsOneWidget,
    );
  });

  testWidgets(
    'regression: declining the limit dialog for Learning mode leaves nothing committed',
    (tester) async {
      // The bug this closes: createSession used to write the session
      // immediately, before the student had even seen this dialog — so
      // "Change the setup" left an orphaned, permanently "in progress"
      // session behind. Now createSession never writes anything, for
      // either mode, so a decline here has nothing to clean up.
      final service = FakeQuizSessionService(
        materials: [_material],
        createSessionResult: GeneratedSessionResult(
          session: _newSession(numberOfQuestions: 3, mode: Mode.learning),
          note: null,
          requestedCount: 5,
          questions: _draftQuestions(count: 3),
        ),
      );
      await _pump(tester, service);

      await tester.tap(find.text('Select materials'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lecture 1 — Intro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate quiz'));
      await tester.pumpAndSettle();

      expect(find.text('Fewer questions than asked'), findsOneWidget);
      await tester.tap(find.text('Change the setup'));
      await tester.pumpAndSettle();

      expect(find.text('Quiz setup'), findsOneWidget); // still here
      expect(service.commitLearningSessionCalls, 0);
      expect(service.sessions, isEmpty); // nothing orphaned
    },
  );

  testWidgets(
    'regression: accepting the limit dialog for Learning mode commits exactly once, only then',
    (tester) async {
      final service = FakeQuizSessionService(
        materials: [_material],
        createSessionResult: GeneratedSessionResult(
          session: _newSession(numberOfQuestions: 3, mode: Mode.learning),
          note: null,
          requestedCount: 5,
          questions: _draftQuestions(count: 3),
        ),
      );
      await _pump(tester, service);

      await tester.tap(find.text('Select materials'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lecture 1 — Intro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate quiz'));
      await tester.pumpAndSettle();

      expect(service.commitLearningSessionCalls, 0); // not yet — dialog still open
      await tester.tap(find.text('Start with these'));
      await tester.pumpAndSettle();

      expect(service.commitLearningSessionCalls, 1);
      expect(find.text('Question 1 of 3'), findsOneWidget); // real, persisted session
    },
  );

  testWidgets(
    'regression: Learning mode with no shortfall commits immediately, no dialog',
    (tester) async {
      final service = FakeQuizSessionService(
        materials: [_material],
        createSessionResult: GeneratedSessionResult(
          session: _newSession(numberOfQuestions: 5, mode: Mode.learning),
          note: null,
          requestedCount: 5,
          questions: _draftQuestions(count: 5),
        ),
      );
      await _pump(tester, service);

      await tester.tap(find.text('Select materials'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lecture 1 — Intro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate quiz'));
      await tester.pumpAndSettle();

      expect(find.text('Fewer questions than asked'), findsNothing);
      expect(service.commitLearningSessionCalls, 1);
      expect(find.text('Question 1 of 5'), findsOneWidget);
    },
  );

  testWidgets(
    'regression: declining the limit dialog for Exam mode also leaves nothing committed',
    (tester) async {
      final service = FakeQuizSessionService(
        materials: [_material],
        createSessionResult: GeneratedSessionResult(
          session: _newSession(numberOfQuestions: 3), // mode: Mode.exam (default)
          note: null,
          requestedCount: 5,
          questions: _draftQuestions(count: 3),
        ),
      );
      await _pump(tester, service);

      await tester.tap(find.text('Select materials'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lecture 1 — Intro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate quiz'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change the setup'));
      await tester.pumpAndSettle();

      expect(find.text('Quiz setup'), findsOneWidget); // still here
      expect(service.submitExamSessionCalls, 0);
      expect(service.sessions, isEmpty);
    },
  );

  testWidgets('failure case: a generation error shows an error banner, not a crash', (tester) async {
    final service = FakeQuizSessionService(
      materials: [_material],
      createSessionError: GenerationFailure('The quiz generator returned an error. Please try again.'),
    );
    await _pump(tester, service);

    await tester.tap(find.text('Select materials'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lecture 1 — Intro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate quiz'));
    await tester.pumpAndSettle();

    expect(
      find.text('The quiz generator returned an error. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Quiz setup'), findsOneWidget); // stayed on Setup
  });

  testWidgets('failure case: zero items generated shows the note, not a blank quiz', (tester) async {
    final service = FakeQuizSessionService(
      materials: [_material],
      createSessionError: NoQuestionsGeneratedException(
        "Your material doesn't cover enough distinct concepts.",
      ),
    );
    await _pump(tester, service);

    await tester.tap(find.text('Select materials'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lecture 1 — Intro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate quiz'));
    await tester.pumpAndSettle();

    expect(
      find.text("Your material doesn't cover enough distinct concepts."),
      findsOneWidget,
    );
  });
}
