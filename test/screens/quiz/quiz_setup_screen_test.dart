import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/question.dart';
import 'package:tadarab_app/models/quiz_session.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/screens/quiz/quiz_setup_screen.dart';
import 'package:tadarab_app/services/quiz_generation_client.dart';
import 'package:tadarab_app/services/quiz_session_service.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/app_button.dart';

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

  testWidgets('materials list is already open on entry, and selecting a '
      'material there drives Generate', (tester) async {
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

    // NOTE 13e: open immediately, matching the Flashcards setup screen —
    // no need to tap the summary row first to reveal the material.
    expect(find.text('Select materials'), findsOneWidget);
    expect(find.text('Lecture 1 — Intro'), findsOneWidget);

    await tester.tap(find.text('Lecture 1 — Intro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Quiz setup'), findsNothing); // navigated away (pushReplacement)
  });

  testWidgets(
    'the materials list still opens on entry even when the course has no '
    'materials yet, showing the empty-state message',
    (tester) async {
      await _pump(tester, FakeQuizSessionService(materials: const []));

      expect(
        find.text('No materials available for this course yet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('edge case: the last selected difficulty cannot be deselected', (tester) async {
    await _pump(tester, FakeQuizSessionService(materials: [_material]));

    // Easy is selected by default (NOTE 13a); tapping it again should not
    // clear it.
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();

    final easyContainer = tester.widget<Container>(
      find
          .ancestor(of: find.text('Easy'), matching: find.byType(Container))
          .first,
    );
    final decoration = easyContainer.decoration! as BoxDecoration;
    // Still selected (navy fill), not deselected to white.
    expect(decoration.color, isNot(Colors.white));
  });

  testWidgets(
    'the subtle shadow appears only on the selected difficulty button',
    (tester) async {
      await _pump(tester, FakeQuizSessionService(materials: [_material]));

      final easyContainer = tester.widget<Container>(
        find
            .ancestor(of: find.text('Easy'), matching: find.byType(Container))
            .first,
      );
      final easyShadow =
          (easyContainer.decoration! as BoxDecoration).boxShadow!.single;
      expect(easyShadow.color, AppColors.navy.withValues(alpha: 0.15));
      expect(easyShadow.blurRadius, 6);
      expect(easyShadow.offset, const Offset(0, 2));

      final mediumContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Medium'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (mediumContainer.decoration! as BoxDecoration).boxShadow,
        isNull,
      );
    },
  );

  testWidgets('normal case: default count is 10, and the stepper respects '
      'the minimum of 5', (tester) async {
    await _pump(tester, FakeQuizSessionService(materials: [_material]));

    // NOTE 13b: default count is 10 on both setup screens.
    expect(find.text('10'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
    }
    expect(find.text('5'), findsOneWidget);
    // At the minimum, the decrement button is disabled (matching the
    // Flashcards counter — no further taps change anything).
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text('5'), findsOneWidget); // never drops below 5
  });

  testWidgets(
    'normal case: the stepper now has an upper cap of 150, matching the '
    'Flashcards counter (no more "no upper limit")',
    (tester) async {
      await _pump(tester, FakeQuizSessionService(materials: [_material]));

      // NOTE 13c: the "Minimum 5 — no upper limit" helper text is gone.
      expect(find.textContaining('no upper limit'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('count-field')), '150');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('150'), findsOneWidget);

      // At the maximum, the increment button is disabled.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('150'), findsOneWidget); // never exceeds 150
    },
  );

  testWidgets(
    'invalid or empty typed input reverts to the last valid count once '
    'committed, matching the Flashcards counter',
    (tester) async {
      await _pump(tester, FakeQuizSessionService(materials: [_material]));

      await tester.enterText(find.byKey(const ValueKey('count-field')), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('10'), findsOneWidget); // reverted, not left empty
    },
  );

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

    await tester.tap(find.text('Lecture 1 — Intro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate quiz'));
    await tester.pumpAndSettle();

    expect(
      find.text("Your material doesn't cover enough distinct concepts."),
      findsOneWidget,
    );
  });

  testWidgets(
    'the footer matches Flashcards setup\'s own footer: top corners '
    'radius 26, and the button\'s shadow is red when enabled and none '
    'when disabled',
    (tester) async {
      await _pump(tester, FakeQuizSessionService(materials: [_material]));

      final footerContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Generate quiz'),
              matching: find.byType(Container),
            )
            .last,
      );
      final footerDecoration = footerContainer.decoration! as BoxDecoration;
      expect(
        footerDecoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(26)),
      );

      // No material/difficulty selected yet: Generate is disabled, so its
      // shadow is fully transparent (none), not just dim.
      final disabledButton = tester.widget<AppButton>(
        find.byWidgetPredicate(
          (w) => w is AppButton && w.label == 'Generate quiz',
        ),
      );
      expect(disabledButton.shadowColor, Colors.transparent);
      expect(disabledButton.onPressed, isNull);

      await tester.tap(find.text('Lecture 1 — Intro'));
      await tester.pumpAndSettle();

      final enabledButton = tester.widget<AppButton>(
        find.byWidgetPredicate(
          (w) => w is AppButton && w.label == 'Generate quiz',
        ),
      );
      expect(enabledButton.shadowColor, AppColors.redShadow.withValues(alpha: 0.6));
      expect(enabledButton.onPressed, isNotNull);
    },
  );
}
