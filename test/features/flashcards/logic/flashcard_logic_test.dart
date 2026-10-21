import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/logic/flashcard_logic.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard_session.dart';

FlashcardSession _session(
  String id,
  DateTime createdAt, {
  DateTime? completedAt,
  bool isSessionCompleted = false,
}) {
  return FlashcardSession(
    sessionId: id,
    createdAt: createdAt,
    completedAt: completedAt,
    isSessionCompleted: isSessionCompleted,
    difficultyLevels: const [DifficultyLevel.medium],
    email: 'student@example.com',
    courseId: 'course-1',
    materialIds: const ['material-1'],
    materialTitles: const ['Lecture 1'],
  );
}

void main() {
  group('calculateEarnedPoints', () {
    test('normal: awards 2 points per known card', () {
      expect(calculateEarnedPoints(knownCount: 5), 10);
    });

    test('edge: zero known cards awards zero points', () {
      expect(calculateEarnedPoints(knownCount: 0), 0);
    });

    test('failure: a negative knownCount throws', () {
      expect(() => calculateEarnedPoints(knownCount: -1), throwsA(isA<AssertionError>()));
    });
  });

  // The performance-tier logic moved to a shared `lib/logic/performance_tier.dart`
  // (NOTE 6), used by both Quiz and Flashcards — see
  // test/logic/performance_tier_test.dart.

  group('resumeIndexFor', () {
    test('normal: an in-range index is returned unchanged', () {
      expect(resumeIndexFor(currentFlashcardIndex: 3, total: 10), 3);
    });

    test('edge: the last valid index is returned unchanged', () {
      expect(resumeIndexFor(currentFlashcardIndex: 9, total: 10), 9);
    });

    test('failure: an index past the end is clamped to the last card', () {
      expect(resumeIndexFor(currentFlashcardIndex: 15, total: 10), 9);
    });

    test('failure: a negative index is clamped to zero', () {
      expect(resumeIndexFor(currentFlashcardIndex: -2, total: 10), 0);
    });

    test('failure: a zero-card deck never returns a positive index', () {
      expect(resumeIndexFor(currentFlashcardIndex: 4, total: 0), 0);
    });
  });

  group('deleteSessionBody', () {
    test('normal: an in-progress session with marked cards names the '
        'count', () {
      final body = deleteSessionBody(
        isCompleted: false,
        knownCount: 3,
        needsReviewCount: 2,
      );
      expect(
        body,
        "You will lose the 5 cards already marked. This can't be undone.",
      );
    });

    test('edge: an in-progress session with nothing marked yet still says '
        'zero', () {
      final body = deleteSessionBody(
        isCompleted: false,
        knownCount: 0,
        needsReviewCount: 0,
      );
      expect(
        body,
        "You will lose the 0 cards already marked. This can't be undone.",
      );
    });

    test('failure: a completed session ignores the counts entirely', () {
      final body = deleteSessionBody(
        isCompleted: true,
        knownCount: 999,
        needsReviewCount: 999,
      );
      expect(
        body,
        "Its counts and review list will go with it. This can't be undone.",
      );
    });
  });

  group('sortSessionsNewestFirst', () {
    test('normal: sorts sessions newest-createdAt first', () {
      final oldest = _session('a', DateTime(2026, 1, 1));
      final middle = _session('b', DateTime(2026, 2, 1));
      final newest = _session('c', DateTime(2026, 3, 1));

      final sorted = sortSessionsNewestFirst([middle, oldest, newest]);

      expect(
        sorted.map((s) => s.sessionId).toList(),
        ['c', 'b', 'a'],
      );
    });

    test('edge: an empty list returns an empty list, not an error', () {
      expect(sortSessionsNewestFirst(const []), isEmpty);
    });

    test('edge: a single session is returned unchanged', () {
      final only = _session('a', DateTime(2026, 1, 1));
      expect(sortSessionsNewestFirst([only]), [only]);
    });

    test('failure-adjacent: does not mutate the input list', () {
      final oldest = _session('a', DateTime(2026, 1, 1));
      final newest = _session('b', DateTime(2026, 2, 1));
      final input = [oldest, newest];

      sortSessionsNewestFirst(input);

      expect(input.map((s) => s.sessionId).toList(), ['a', 'b']);
    });
  });

  group('planRetakeCardWrites', () {
    test('normal: the new set is the same size as the old — all overwrites, '
        'no adds or deletes', () {
      final plan = planRetakeCardWrites(existingCount: 10, newCount: 10);
      expect(plan.overwriteCount, 10);
      expect(plan.addCount, 0);
      expect(plan.deleteCount, 0);
    });

    test('normal: the new set is larger — overwrite all old ones, add the '
        'rest', () {
      final plan = planRetakeCardWrites(existingCount: 8, newCount: 12);
      expect(plan.overwriteCount, 8);
      expect(plan.addCount, 4);
      expect(plan.deleteCount, 0);
    });

    test('normal: the new set is smaller — overwrite what fits, delete the '
        'leftover old ones', () {
      final plan = planRetakeCardWrites(existingCount: 12, newCount: 8);
      expect(plan.overwriteCount, 8);
      expect(plan.addCount, 0);
      expect(plan.deleteCount, 4);
    });

    test('edge: no existing cards at all — every new card is an add', () {
      final plan = planRetakeCardWrites(existingCount: 0, newCount: 5);
      expect(plan.overwriteCount, 0);
      expect(plan.addCount, 5);
      expect(plan.deleteCount, 0);
    });
  });

  group('batchSizes', () {
    test('normal: fewer operations than the cap fit in a single batch', () {
      expect(batchSizes(totalOperations: 42), [42]);
    });

    test('edge: exactly the cap fits in a single batch', () {
      expect(batchSizes(totalOperations: 500), [500]);
    });

    test('normal: one more than the cap splits into two batches', () {
      expect(batchSizes(totalOperations: 501), [500, 1]);
    });

    test('normal: a large count splits into as many full batches as needed, '
        'plus a smaller remainder', () {
      expect(batchSizes(totalOperations: 1042), [500, 500, 42]);
    });

    test('edge: zero operations needs no batches at all', () {
      expect(batchSizes(totalOperations: 0), isEmpty);
    });

    test('failure-adjacent: a custom maxPerBatch is respected', () {
      expect(batchSizes(totalOperations: 25, maxPerBatch: 10), [10, 10, 5]);
    });
  });
}
