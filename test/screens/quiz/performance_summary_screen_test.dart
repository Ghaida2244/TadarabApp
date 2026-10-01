import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/question.dart';
import 'package:tadarab_app/models/quiz_session.dart';
import 'package:tadarab_app/screens/quiz/performance_summary_screen.dart';
import 'package:tadarab_app/screens/quiz/quiz_navigation.dart';
import 'package:tadarab_app/screens/quiz/quiz_play_screen.dart';

import '../../helpers/fake_quiz_session_service.dart';

QuizSession _completedSession({
  required Mode mode,
  required int correct,
  required int total,
}) {
  return QuizSession(
    sessionId: 's1',
    createdAt: DateTime(2026, 1, 1),
    completedAt: DateTime(2026, 1, 1),
    earnedPoints: correct * 4,
    isSessionCompleted: true,
    difficultyLevels: const [DifficultyLevel.medium],
    email: 'a@b.com',
    courseId: 'course-1',
    materialIds: const ['m1'],
    numberOfQuestions: total,
    mode: mode,
    correctAnswers: correct,
    incorrectAnswers: total - correct,
  );
}

List<Question> _questionsWith({required int correct, required int total}) {
  return List.generate(total, (i) {
    final isCorrect = i < correct;
    return Question(
      questionId: 'q$i',
      questionText: 'Question $i',
      correctAnswer: 'Right',
      explanation: 'Because.',
      sourceLocation: 'Slide $i',
      studentAnswer: isCorrect ? 'Right' : 'Wrong',
      options: const ['Right', 'Wrong', 'Other', 'Another'],
      sessionId: 's1',
    );
  });
}

Future<void> _pumpReal(WidgetTester tester, FakeQuizSessionService service) async {
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (_) => MaterialPageRoute(
        settings: const RouteSettings(name: quizSessionsRouteName),
        builder: (_) => const Scaffold(body: Text('Quiz sessions placeholder')),
      ),
    ),
  );
  // Push the real summary on top of the base route (named
  // quizSessionsRouteName) so "Back to Sessions" (popToQuizSessions) has
  // somewhere real to land. Not awaited: NavigatorState.push()'s Future only
  // completes when the pushed route is later *popped*, not when the push
  // itself finishes — awaiting it here would deadlock the test.
  final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
  unawaited(
    navigatorState.push(
      MaterialPageRoute(
        builder: (_) => PerformanceSummaryScreen(sessionId: 's1', service: service),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Exam mode with mistakes shows Review mistakes + Back to Sessions', (tester) async {
    final service = FakeQuizSessionService(
      sessions: [_completedSession(mode: Mode.exam, correct: 7, total: 10)],
      questions: {'s1': _questionsWith(correct: 7, total: 10)},
    );
    await _pumpReal(tester, service);

    expect(find.text('7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('CORRECT'), findsOneWidget);
    expect(find.text('WRONG'), findsOneWidget);
    expect(find.text('Review mistakes'), findsOneWidget);
    expect(find.text('Practice Now'), findsNothing);
    expect(find.text('Back to Sessions'), findsOneWidget);
    expect(find.text('Points earned'), findsOneWidget);
    expect(find.text('+28'), findsOneWidget);
  });

  testWidgets('Learning mode with mistakes shows Practice Now, not Review mistakes', (tester) async {
    final service = FakeQuizSessionService(
      sessions: [_completedSession(mode: Mode.learning, correct: 4, total: 10)],
      questions: {'s1': _questionsWith(correct: 4, total: 10)},
    );
    await _pumpReal(tester, service);

    expect(find.text('Practice Now'), findsOneWidget);
    expect(find.text('Review mistakes'), findsNothing);
  });

  testWidgets(
    'tapping Practice Now hands QuizPlayScreen fully unanswered questions, not the originals',
    (tester) async {
      final service = FakeQuizSessionService(
        sessions: [_completedSession(mode: Mode.learning, correct: 4, total: 10)],
        // _questionsWith sets a real studentAnswer ('Wrong') on every
        // incorrect question — exactly the stale state Practice Now must
        // not carry forward.
        questions: {'s1': _questionsWith(correct: 4, total: 10)},
      );
      await _pumpReal(tester, service);

      await tester.ensureVisible(find.text('Practice Now'));
      await tester.tap(find.text('Practice Now'));
      await tester.pumpAndSettle();

      final playScreen = tester.widget<QuizPlayScreen>(find.byType(QuizPlayScreen));
      expect(playScreen.practiceQuestions, isNotEmpty);
      for (final q in playScreen.practiceQuestions!) {
        expect(q.studentAnswer, isNull);
      }
    },
  );

  testWidgets('a perfect score has no Review/Practice action at all', (tester) async {
    final service = FakeQuizSessionService(
      sessions: [_completedSession(mode: Mode.exam, correct: 10, total: 10)],
      questions: {'s1': _questionsWith(correct: 10, total: 10)},
    );
    await _pumpReal(tester, service);

    expect(find.text('Review mistakes'), findsNothing);
    expect(find.text('Practice Now'), findsNothing);
    expect(find.text('Back to Sessions'), findsOneWidget);
  });

  testWidgets(
    'regression: a short summary (no mistakes) still anchors its button to the actual screen bottom, no empty space beneath it',
    (tester) async {
      // A perfect score has only one action ("Back to Sessions") and no
      // points/mistakes content tall enough to reach the bottom on its
      // own — this is exactly the short-content case that used to leave
      // the button following normal content flow with empty space below
      // it instead of sitting at the screen's actual bottom edge.
      final service = FakeQuizSessionService(
        sessions: [_completedSession(mode: Mode.exam, correct: 10, total: 10)],
        questions: {'s1': _questionsWith(correct: 10, total: 10)},
      );
      await _pumpReal(tester, service);

      final screenHeight = tester.getSize(find.byType(MaterialApp)).height;
      final buttonBottom = tester.getBottomLeft(find.text('Back to Sessions')).dy;

      // The button's own bottom padding is 26px (see the fixed footer's
      // Padding in PerformanceSummaryScreen) — anything close to that
      // proves it's pinned to the real bottom, not stranded mid-screen
      // with a large gap below it.
      expect(
        screenHeight - buttonBottom,
        lessThan(50),
        reason: 'the action button should sit near the screen bottom, not float above empty space',
      );
    },
  );

  testWidgets('mood tiers: a low score shows the keep-practising message, not the top tier', (tester) async {
    final service = FakeQuizSessionService(
      sessions: [_completedSession(mode: Mode.exam, correct: 2, total: 10)],
      questions: {'s1': _questionsWith(correct: 2, total: 10)},
    );
    await _pumpReal(tester, service);

    expect(find.text('Keep practising, you are improving.'), findsOneWidget);
  });

  testWidgets('Back to Sessions pops back to the Quiz sessions route', (tester) async {
    final service = FakeQuizSessionService(
      sessions: [_completedSession(mode: Mode.exam, correct: 7, total: 10)],
      questions: {'s1': _questionsWith(correct: 7, total: 10)},
    );
    await _pumpReal(tester, service);

    await tester.ensureVisible(find.text('Back to Sessions'));
    await tester.tap(find.text('Back to Sessions'));
    await tester.pumpAndSettle();

    expect(find.text('Quiz sessions placeholder'), findsOneWidget);
  });

  group('Practice result (ephemeral)', () {
    Future<void> pumpPracticeResult(WidgetTester tester, {required int correct, required int total}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceSummaryScreen.practiceResult(correct: correct, total: total),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows counts and a mood message but no points strip', (tester) async {
      await pumpPracticeResult(tester, correct: 3, total: 5);

      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Points earned'), findsNothing);
    });

    testWidgets('has no Review Mistakes and no Practice Now — only Back to Sessions', (tester) async {
      await pumpPracticeResult(tester, correct: 1, total: 5);

      expect(find.text('Review mistakes'), findsNothing);
      expect(find.text('Practice Now'), findsNothing);
      expect(find.text('Back to Sessions'), findsOneWidget);
    });
  });
}
