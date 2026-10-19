import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/session.dart';

void main() {
  group('SessionFields.fromMap', () {
    Map<String, dynamic> baseMap({List<String>? difficultyLevels}) => {
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'completedAt': null,
      'earnedPoints': 12,
      'isSessionCompleted': false,
      'difficultyLevels': difficultyLevels ?? ['easy', 'hard'],
      'customPrompt': 'focus on definitions',
      'email': 'student@example.com',
      'courseId': 'course-1',
      'materialIds': ['mat-1', 'mat-2'],
    };

    test('normal case: reads a multi-select difficulty list in order', () {
      final fields = SessionFields.fromMap(baseMap(), sessionId: 's1');
      expect(fields.difficultyLevels, [
        DifficultyLevel.easy,
        DifficultyLevel.hard,
      ]);
      expect(fields.earnedPoints, 12);
      expect(fields.materialIds, ['mat-1', 'mat-2']);
    });

    test('edge case: a single-entry difficulty list still parses', () {
      final fields = SessionFields.fromMap(
        baseMap(difficultyLevels: ['medium']),
        sessionId: 's1',
      );
      expect(fields.difficultyLevels, [DifficultyLevel.medium]);
    });

    test(
      'failure case: a missing difficultyLevels field falls back to Medium, does not throw',
      () {
        final map = baseMap()..remove('difficultyLevels');
        final fields = SessionFields.fromMap(map, sessionId: 's1');
        expect(fields.difficultyLevels, [DifficultyLevel.medium]);
      },
    );

    test(
      'failure case: an empty difficultyLevels list falls back to Medium, does not throw',
      () {
        final fields = SessionFields.fromMap(
          baseMap(difficultyLevels: []),
          sessionId: 's1',
        );
        expect(fields.difficultyLevels, [DifficultyLevel.medium]);
      },
    );

    test(
      'failure case: an unrecognized difficulty value falls back to Medium, does not throw',
      () {
        // e.g. a document hand-edited in the Firebase console with a typo
        // or a value from before the enum's current names.
        final fields = SessionFields.fromMap(
          baseMap(difficultyLevels: ['legendary']),
          sessionId: 's1',
        );
        expect(fields.difficultyLevels, [DifficultyLevel.medium]);
      },
    );

    test(
      'normal case: rootSessionId/retakeNumber/retakeOfSessionId/coveredTopics '
      'round-trip when present',
      () {
        final map = baseMap()
          ..addAll({
            'rootSessionId': 'root-1',
            'retakeNumber': 2,
            'retakeOfSessionId': 'prev-session',
            'coveredTopics': ['Normalization', 'ACID'],
          });
        final fields = SessionFields.fromMap(map, sessionId: 's1');
        expect(fields.rootSessionId, 'root-1');
        expect(fields.retakeNumber, 2);
        expect(fields.retakeOfSessionId, 'prev-session');
        expect(fields.coveredTopics, ['Normalization', 'ACID']);
      },
    );

    test(
      'failure case: an old document missing rootSessionId/retakeNumber/'
      'retakeOfSessionId/coveredTopics defaults them (original, no retake, '
      'no topics), not a crash',
      () {
        final fields = SessionFields.fromMap(baseMap(), sessionId: 'doc-7');
        expect(fields.rootSessionId, 'doc-7');
        expect(fields.retakeNumber, 0);
        expect(fields.retakeOfSessionId, isNull);
        expect(fields.coveredTopics, isEmpty);
      },
    );

    test(
      'failure case: a non-list coveredTopics value falls back to empty, '
      'not a crash',
      () {
        final map = baseMap()..['coveredTopics'] = 'not a list';
        final fields = SessionFields.fromMap(map, sessionId: 's1');
        expect(fields.coveredTopics, isEmpty);
      },
    );

    test(
      'failure case: a coveredTopics list with non-string entries keeps '
      'only the String ones',
      () {
        final map = baseMap()..['coveredTopics'] = ['Normalization', 42, null];
        final fields = SessionFields.fromMap(map, sessionId: 's1');
        expect(fields.coveredTopics, ['Normalization']);
      },
    );
  });

  group('Session.sharedFieldsToFirestore (via QuizSession)', () {
    test('round-trips a multi-select difficulty list', () {
      final now = DateTime(2026, 2, 1);
      final session = _ConcreteSession(
        sessionId: 's1',
        createdAt: now,
        difficultyLevels: [DifficultyLevel.easy, DifficultyLevel.medium],
        email: 'a@b.com',
        courseId: 'c1',
        materialIds: const ['m1'],
      );

      final map = session.sharedFieldsToFirestore();

      expect(map['difficultyLevels'], ['easy', 'medium']);
      final roundTripped = SessionFields.fromMap(map, sessionId: session.sessionId);
      expect(roundTripped.difficultyLevels, [
        DifficultyLevel.easy,
        DifficultyLevel.medium,
      ]);
    });

    test('asserts at least one difficulty level is given', () {
      expect(
        () => _ConcreteSession(
          sessionId: 's1',
          createdAt: DateTime(2026, 1, 1),
          difficultyLevels: const [],
          email: 'a@b.com',
          courseId: 'c1',
          materialIds: const [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      'normal case: a plain original session defaults rootSessionId to its '
      'own id, retakeNumber to 0, retakeOfSessionId to null, coveredTopics '
      'to empty, and writes all four',
      () {
        final session = _ConcreteSession(
          sessionId: 's1',
          createdAt: DateTime(2026, 1, 1),
          difficultyLevels: const [DifficultyLevel.easy],
          email: 'a@b.com',
          courseId: 'c1',
          materialIds: const [],
        );

        expect(session.rootSessionId, 's1');
        expect(session.retakeNumber, 0);
        expect(session.retakeOfSessionId, isNull);
        expect(session.coveredTopics, isEmpty);

        final map = session.sharedFieldsToFirestore();
        expect(map['rootSessionId'], 's1');
        expect(map['retakeNumber'], 0);
        expect(map['retakeOfSessionId'], isNull);
        expect(map['coveredTopics'], isEmpty);
      },
    );

    test(
      'normal case: a retake session carries its own explicit root/retake '
      'chain fields through, not the sessionId-based default',
      () {
        final session = _ConcreteSession(
          sessionId: 'retake-1',
          createdAt: DateTime(2026, 1, 2),
          difficultyLevels: const [DifficultyLevel.hard],
          email: 'a@b.com',
          courseId: 'c1',
          materialIds: const [],
          rootSessionId: 'original-1',
          retakeNumber: 1,
          retakeOfSessionId: 'original-1',
          coveredTopics: const ['Normalization'],
        );

        expect(session.rootSessionId, 'original-1');
        expect(session.retakeNumber, 1);
        expect(session.retakeOfSessionId, 'original-1');
        expect(session.coveredTopics, ['Normalization']);
      },
    );
  });

  group('sessionRetakeLabel', () {
    test('normal case: retakeNumber 0 is "Original"', () {
      expect(sessionRetakeLabel(0), 'Original');
    });

    test('normal case: retakeNumber 1 is "Retake 1"', () {
      expect(sessionRetakeLabel(1), 'Retake 1');
    });

    test('edge case: a higher retakeNumber still reads correctly', () {
      expect(sessionRetakeLabel(7), 'Retake 7');
    });
  });

  group('sessionCardRetakeLabel', () {
    _ConcreteSession original({int retakeNumber = 0, List<String>? coveredTopics}) =>
        _ConcreteSession(
          sessionId: 'original-1',
          createdAt: DateTime(2026, 1, 1),
          difficultyLevels: const [DifficultyLevel.easy],
          email: 'a@b.com',
          courseId: 'c1',
          materialIds: const [],
          retakeNumber: retakeNumber,
        );

    _ConcreteSession retakeOf(String rootId, {int retakeNumber = 1}) =>
        _ConcreteSession(
          sessionId: 'retake-$retakeNumber',
          createdAt: DateTime(2026, 1, 2),
          difficultyLevels: const [DifficultyLevel.easy],
          email: 'a@b.com',
          courseId: 'c1',
          materialIds: const [],
          rootSessionId: rootId,
          retakeNumber: retakeNumber,
          retakeOfSessionId: rootId,
        );

    test(
      'normal case: a retake (retakeNumber > 0) always shows "Retake N", '
      'regardless of who else is in the list',
      () {
        final retake = retakeOf('original-1', retakeNumber: 2);
        expect(sessionCardRetakeLabel(retake, [retake]), 'Retake 2');
      },
    );

    test(
      'normal case: an original with at least one retake in the list is '
      'labeled "Original"',
      () {
        final orig = original();
        final retake = retakeOf(orig.sessionId);
        expect(sessionCardRetakeLabel(orig, [orig, retake]), 'Original');
      },
    );

    test(
      'edge case: an original with no retakes currently in the list shows '
      'no label at all',
      () {
        final orig = original();
        expect(sessionCardRetakeLabel(orig, [orig]), isNull);
      },
    );

    test(
      'failure case: an old session (defaults — rootSessionId == its own '
      'id, retakeNumber 0, as if it predates these fields) shows no label, '
      'same as a never-retaken original',
      () {
        final old = original(); // no explicit rootSessionId -> defaults to own id
        expect(sessionCardRetakeLabel(old, [old]), isNull);
      },
    );

    test(
      'edge case: the label disappears again once every retake is gone '
      'from the list (e.g. deleted)',
      () {
        final orig = original();
        // Only the original left — as if its retake(s) were deleted.
        expect(sessionCardRetakeLabel(orig, [orig]), isNull);
      },
    );

    test(
      'failure-adjacent: another session merely sharing courseId (not '
      'rootSessionId) does not count as a retake',
      () {
        final orig = original();
        final unrelated = _ConcreteSession(
          sessionId: 'unrelated-1',
          createdAt: DateTime(2026, 1, 3),
          difficultyLevels: const [DifficultyLevel.easy],
          email: 'a@b.com',
          courseId: 'c1',
          materialIds: const [],
        );
        expect(sessionCardRetakeLabel(orig, [orig, unrelated]), isNull);
      },
    );
  });

  group('nextRetakeNumber', () {
    test('normal case: a group with only the original (0) gives 1', () {
      expect(nextRetakeNumber([0]), 1);
    });

    test('normal case: picks one more than the highest in the group, '
        'regardless of input order', () {
      expect(nextRetakeNumber([0, 2, 1]), 3);
    });

    test('edge case: an empty group (shouldn\'t normally happen — the '
        'source session is always in its own group) still returns 1, not '
        'a crash', () {
      expect(nextRetakeNumber(const <int>[]), 1);
    });

    test('failure-adjacent: duplicate retakeNumbers in the group are '
        'tolerated, not double-counted', () {
      expect(nextRetakeNumber([0, 1, 1, 1]), 2);
    });
  });
}

/// A minimal concrete Session for testing the shared base-class logic —
/// Session itself is abstract.
class _ConcreteSession extends Session {
  _ConcreteSession({
    required super.sessionId,
    required super.createdAt,
    required super.difficultyLevels,
    required super.email,
    required super.courseId,
    required super.materialIds,
    super.rootSessionId,
    super.retakeNumber,
    super.retakeOfSessionId,
    super.coveredTopics,
  });
}
