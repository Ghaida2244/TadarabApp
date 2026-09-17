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
      final fields = SessionFields.fromMap(baseMap());
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
      );
      expect(fields.difficultyLevels, [DifficultyLevel.medium]);
    });

    test('failure case: missing difficultyLevels throws', () {
      final map = baseMap()..remove('difficultyLevels');
      expect(() => SessionFields.fromMap(map), throwsStateError);
    });

    test('failure case: empty difficultyLevels list throws', () {
      expect(
        () => SessionFields.fromMap(baseMap(difficultyLevels: [])),
        throwsStateError,
      );
    });
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
      final roundTripped = SessionFields.fromMap(map);
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
  });
}
