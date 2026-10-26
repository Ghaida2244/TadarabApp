import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/question.dart';
import 'package:tadarab_app/models/quiz_session.dart';
import 'package:tadarab_app/services/quiz_session_service.dart';
import 'package:tadarab_app/services/streak_service.dart';

/// Supplies a fixed signed-in identity without needing a real/fake
/// FirebaseAuth — [QuizSessionService.currentUid]/[currentEmail] are
/// public exactly so a test subclass can override them this way, the same
/// approach test/services/calendar_service_test.dart uses for
/// [CalendarService.currentEmail].
class _SignedInQuizSessionService extends QuizSessionService {
  _SignedInQuizSessionService({super.firestore, super.streakService});

  @override
  String? get currentUid => 'uid-1';

  @override
  String? get currentEmail => 'student@example.com';
}

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

      expect(entries.map((e) => e.group.top.sessionId), [
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
      expect(entries.map((e) => e.group.top.sessionId), ['a', 'b', 'c']);
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

        expect(entries.map((e) => e.group.top.sessionId), [
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

        expect(entries.map((e) => e.group.top.sessionId), ['has-date', 'no-date']);
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

        expect(entries.map((e) => e.group.top.sessionId), [
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

  // The result-mood/message logic moved to a shared
  // `lib/logic/performance_tier.dart` (NOTE 6), used by both Quiz and
  // Flashcards — see test/logic/performance_tier_test.dart.

  group('batchWriteSizes', () {
    test('normal: fewer operations than the cap fit in a single batch', () {
      expect(batchWriteSizes(totalOperations: 42), [42]);
    });

    test('edge: exactly the cap fits in a single batch', () {
      expect(batchWriteSizes(totalOperations: 500), [500]);
    });

    test('normal: one more than the cap splits into two batches', () {
      expect(batchWriteSizes(totalOperations: 501), [500, 1]);
    });

    test(
      'normal: a large count splits into as many full batches as needed, '
      'plus a smaller remainder',
      () {
        expect(batchWriteSizes(totalOperations: 1042), [500, 500, 42]);
      },
    );

    test('edge: zero operations needs no batches at all', () {
      expect(batchWriteSizes(totalOperations: 0), isEmpty);
    });

    test('failure-adjacent: a custom maxPerBatch is respected', () {
      expect(batchWriteSizes(totalOperations: 25, maxPerBatch: 10), [10, 10, 5]);
    });
  });

  group('completeSession / submitExamSession — points and rank', () {
    late FakeFirebaseFirestore firestore;
    late QuizSessionService service;

    DocumentReference<Map<String, dynamic>> studentDoc() =>
        firestore.collection('users').doc('uid-1');

    CollectionReference<Map<String, dynamic>> sessionsRef() =>
        studentDoc().collection('quizSessions');

    Future<void> seedStudent({int? totalPoints}) async {
      final data = <String, dynamic>{
        'email': 'student@example.com',
        'name': 'Student',
      };
      if (totalPoints != null) data['totalPoints'] = totalPoints;
      await studentDoc().set(data);
    }

    Future<void> seedSessionWithQuestions(
      QuizSession session,
      List<Question> questions,
    ) async {
      final sessionRef = sessionsRef().doc(session.sessionId);
      await sessionRef.set(session.toFirestore());
      for (final q in questions) {
        await sessionRef.collection('questions').doc(q.questionId).set(q.toFirestore());
      }
    }

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = _SignedInQuizSessionService(
        firestore: firestore,
        streakService: StreakService(firestore: firestore),
      );
    });

    test(
      'normal case: completeSession, just above a rank threshold — '
      'currentRank is updated to match the new total',
      () async {
        // Active Learner starts at 100; one correct answer is 4 points.
        await seedStudent(totalPoints: 96);
        await seedSessionWithQuestions(
          _session(id: 's1', completed: false),
          [_question(studentAnswer: 'B', correctAnswer: 'B')],
        );

        await service.completeSession('s1');

        final data = (await studentDoc().get()).data()!;
        expect(data['totalPoints'], 100);
        expect(data['currentRank'], 'Active Learner');
      },
    );

    test(
      'edge case: completeSession, just below a rank threshold — '
      'currentRank stays at the current rank',
      () async {
        await seedStudent(totalPoints: 90);
        await seedSessionWithQuestions(
          // No correct answers: 0 points earned, stays well below 100.
          _session(id: 's2', completed: false),
          [_question(studentAnswer: 'wrong', correctAnswer: 'B')],
        );

        await service.completeSession('s2');

        final data = (await studentDoc().get()).data()!;
        expect(data['totalPoints'], 90);
        expect(data['currentRank'], 'Beginner Learner');
      },
    );

    test(
      'edge case: a student doc with no totalPoints field at all is '
      'treated as 0, not a crash',
      () async {
        await seedStudent(); // no totalPoints field
        await seedSessionWithQuestions(
          _session(id: 's3', completed: false),
          [_question(studentAnswer: 'B', correctAnswer: 'B')],
        );

        await service.completeSession('s3');

        final data = (await studentDoc().get()).data()!;
        expect(data['totalPoints'], 4);
        expect(data['currentRank'], 'Beginner Learner');
      },
    );

    test(
      'failure case: a failed read of the student doc still saves the '
      'session and totalPoints, and skips currentRank entirely',
      () async {
        await seedStudent(totalPoints: 10);
        await seedSessionWithQuestions(
          _session(id: 's4', completed: false),
          [_question(studentAnswer: 'B', correctAnswer: 'B')],
        );
        whenCalling(
          Invocation.method(#get, null),
        ).on(studentDoc()).thenThrow(FirebaseException(plugin: 'cloud_firestore'));
        // StreakService reads the very same student doc path right after
        // completeSession's own rank read — give it an entirely separate
        // Firestore so the registered failure above (which isn't scoped to
        // a single call) doesn't also break the unrelated streak write
        // this test isn't exercising.
        final serviceWithIsolatedStreak = _SignedInQuizSessionService(
          firestore: firestore,
          streakService: StreakService(firestore: FakeFirebaseFirestore()),
        );

        final result = await serviceWithIsolatedStreak.completeSession('s4');

        expect(result.isSessionCompleted, isTrue);
        // A plain studentDoc().get() (and even a collection-level query —
        // fake_cloud_firestore's own .get() fetches each matching document
        // via its own .get() internally) would hit the same registered
        // failure above, since it throws on every matching call, not just
        // the first. .snapshots() reads the current in-memory state
        // directly and isn't instrumented by mock_exceptions at all.
        final data = (await studentDoc().snapshots().first).data()!;
        expect(data['totalPoints'], 14);
        expect(data.containsKey('currentRank'), isFalse);
      },
    );

    test(
      'normal case: submitExamSession also updates currentRank, just '
      'above a threshold',
      () async {
        await seedStudent(totalPoints: 696); // Focused Learner: 300-699
        final draft = QuizSession(
          sessionId: 'exam-1',
          createdAt: DateTime(2026, 1, 1),
          difficultyLevels: const [DifficultyLevel.medium],
          email: 'a@b.com',
          courseId: 'c1',
          materialIds: const ['m1'],
          mode: Mode.exam,
        );
        final answered = [
          Question(
            questionId: 'q1',
            questionText: 'Q',
            correctAnswer: 'B',
            explanation: 'E',
            sourceLocation: 'Slide 1',
            studentAnswer: 'B',
            options: const ['A', 'B', 'C', 'D'],
            sessionId: 'exam-1',
          ),
        ];

        await service.submitExamSession(
          draftSession: draft,
          answeredQuestions: answered,
        );

        final data = (await studentDoc().get()).data()!;
        expect(data['totalPoints'], 700);
        expect(data['currentRank'], 'Rising Learner');
      },
    );
  });
}
