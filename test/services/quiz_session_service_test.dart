import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/question.dart';
import 'package:tadarab_app/models/quiz_session.dart';
import 'package:tadarab_app/services/quiz_session_service.dart';

QuizSession _session({
  required String id,
  required bool completed,
  DateTime? completedAt,
  DateTime? createdAt,
}) {
  return QuizSession(
    sessionId: id,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    isSessionCompleted: completed,
    completedAt: completedAt,
    difficultyLevels: const [DifficultyLevel.medium],
    email: 'a@b.com',
    courseId: 'c1',
    materialIds: const ['m1'],
    mode: Mode.exam,
  );
}

Question _question({String? studentAnswer, String correctAnswer = 'B'}) {
  return Question(
    questionId: 'q',
    questionText: 'Q',
    correctAnswer: correctAnswer,
    explanation: 'E',
    sourceLocation: 'Slide 1',
    studentAnswer: studentAnswer,
    options: const ['A', 'B', 'C', 'D'],
    sessionId: 's1',
  );
}

void main() {
  group('pointsForCorrectAnswers', () {
    test('normal case: 4 points per correct answer', () {
      expect(pointsForCorrectAnswers(5), 20);
    });

    test('edge case: zero correct answers earns zero points', () {
      expect(pointsForCorrectAnswers(0), 0);
    });
  });

  group('groupQuizSessions', () {
    test('normal case: in-progress sessions sort before completed ones', () {
      final sessions = [
        _session(id: 'done-1', completed: true),
        _session(id: 'inprogress-1', completed: false),
        _session(id: 'done-2', completed: true),
      ];

      final entries = groupQuizSessions(sessions);

      expect(entries.map((e) => e.session.sessionId), [
        'inprogress-1',
        'done-1',
        'done-2',
      ]);
    });

    test('normal case: a header is shown only at each group boundary', () {
      final sessions = [
        _session(id: 'inprogress-1', completed: false),
        _session(id: 'inprogress-2', completed: false),
        _session(id: 'done-1', completed: true),
      ];

      final entries = groupQuizSessions(sessions);

      expect(entries[0].showHeader, isTrue);
      expect(entries[0].headerLabel, 'IN PROGRESS');
      expect(entries[1].showHeader, isFalse);
      expect(entries[2].showHeader, isTrue);
      expect(entries[2].headerLabel, 'COMPLETED');
    });

    test('edge case: an empty list produces an empty result', () {
      expect(groupQuizSessions(const []), isEmpty);
    });

    test('edge case: original relative order is preserved within a group', () {
      final sessions = [
        _session(id: 'a', completed: false),
        _session(id: 'b', completed: false),
        _session(id: 'c', completed: false),
      ];
      final entries = groupQuizSessions(sessions);
      expect(entries.map((e) => e.session.sessionId), ['a', 'b', 'c']);
    });

    test(
      'normal case: completed sessions sort newest-completed-first, regardless of input order',
      () {
        final sessions = [
          _session(id: 'oldest', completed: true, completedAt: DateTime(2026, 1, 1)),
          _session(id: 'newest', completed: true, completedAt: DateTime(2026, 1, 3)),
          _session(id: 'middle', completed: true, completedAt: DateTime(2026, 1, 2)),
        ];

        final entries = groupQuizSessions(sessions);

        expect(entries.map((e) => e.session.sessionId), [
          'newest',
          'middle',
          'oldest',
        ]);
      },
    );

    test(
      'edge case: a completed session missing completedAt falls back to original order, not a crash',
      () {
        final sessions = [
          _session(id: 'has-date', completed: true, completedAt: DateTime(2026, 1, 1)),
          _session(id: 'no-date', completed: true),
        ];

        final entries = groupQuizSessions(sessions);

        expect(entries.map((e) => e.session.sessionId), ['has-date', 'no-date']);
      },
    );

    test(
      'normal case: in-progress sessions sort newest-created-first too, regardless of input order',
      () {
        final sessions = [
          _session(id: 'oldest', completed: false, createdAt: DateTime(2026, 1, 1)),
          _session(id: 'newest', completed: false, createdAt: DateTime(2026, 1, 3)),
          _session(id: 'middle', completed: false, createdAt: DateTime(2026, 1, 2)),
        ];

        final entries = groupQuizSessions(sessions);

        expect(entries.map((e) => e.session.sessionId), [
          'newest',
          'middle',
          'oldest',
        ]);
      },
    );
  });

  group('isRevealedState', () {
    test('normal case: Learning mode, already answered -> revealed', () {
      expect(
        isRevealedState(mode: Mode.learning, current: _question(studentAnswer: 'B')),
        isTrue,
      );
    });

    test('edge case: Learning mode, not yet answered -> not revealed', () {
      expect(isRevealedState(mode: Mode.learning, current: _question()), isFalse);
    });

    test('failure/exam case: Exam mode never reveals, even if answered', () {
      expect(
        isRevealedState(mode: Mode.exam, current: _question(studentAnswer: 'B')),
        isFalse,
      );
    });

    test('edge case: a null current question is never revealed', () {
      expect(isRevealedState(mode: Mode.learning, current: null), isFalse);
    });
  });

  group('nextButtonLabel', () {
    test('normal case: Learning, not revealed -> Submit answer', () {
      expect(
        nextButtonLabel(mode: Mode.learning, revealed: false, isLastQuestion: false),
        'Submit answer',
      );
    });

    test('normal case: Learning, revealed, not last -> Next question', () {
      expect(
        nextButtonLabel(mode: Mode.learning, revealed: true, isLastQuestion: false),
        'Next question',
      );
    });

    test('edge case: Learning, revealed, last -> Finish quiz', () {
      expect(
        nextButtonLabel(mode: Mode.learning, revealed: true, isLastQuestion: true),
        'Finish quiz',
      );
    });

    test('normal case: Exam, not last -> Next', () {
      expect(
        nextButtonLabel(mode: Mode.exam, revealed: false, isLastQuestion: false),
        'Next',
      );
    });

    test('edge case: Exam, last -> Submit quiz', () {
      expect(
        nextButtonLabel(mode: Mode.exam, revealed: false, isLastQuestion: true),
        'Submit quiz',
      );
    });
  });

  group('generatedFewerThanRequested', () {
    test('normal case: fewer generated than requested is true', () {
      expect(
        generatedFewerThanRequested(requestedCount: 10, actualCount: 4),
        isTrue,
      );
    });

    test('edge case: exactly the requested count is false', () {
      expect(
        generatedFewerThanRequested(requestedCount: 10, actualCount: 10),
        isFalse,
      );
    });
  });

  group('resultMoodFor', () {
    test('normal case: 90% is the top tier', () {
      expect(resultMoodFor(correct: 9, total: 10), ResultMood.great);
    });

    test('edge case: exactly 80% is still the top tier (inclusive boundary)', () {
      expect(resultMoodFor(correct: 8, total: 10), ResultMood.great);
    });

    test('edge case: exactly 50% is the middle tier (inclusive boundary)', () {
      expect(resultMoodFor(correct: 5, total: 10), ResultMood.solid);
    });

    test('normal case: below 50% is the lowest tier', () {
      expect(resultMoodFor(correct: 2, total: 10), ResultMood.keepPractising);
    });

    test('failure case: a zero total does not throw, falls back to lowest tier', () {
      expect(resultMoodFor(correct: 0, total: 0), ResultMood.keepPractising);
    });
  });

  group('resultMessageFor', () {
    test('every tier has distinct, non-empty copy', () {
      final messages = ResultMood.values.map(resultMessageFor).toSet();
      expect(messages.length, ResultMood.values.length);
      for (final m in messages) {
        expect(m, isNotEmpty);
      }
    });
  });
}
