import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/logic/flashcard_logic.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';

Flashcard _card(String id, {ReviewStatus? status, int cardIndex = 0}) {
  return Flashcard(
    flashcardId: id,
    frontText: 'front-$id',
    backText: 'back-$id',
    reviewStatus: status,
    sourceLocation: 'Lecture 1 - Slide 1',
    sessionId: 'session-1',
    cardIndex: cardIndex,
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

  group('performanceTierFor', () {
    test('normal: 80% or more is mastery', () {
      expect(
        performanceTierFor(knownCount: 8, total: 10),
        PerformanceTier.mastery,
      );
    });

    test('normal: between 50% and 80% is developing', () {
      expect(
        performanceTierFor(knownCount: 6, total: 10),
        PerformanceTier.developing,
      );
    });

    test('normal: below 50% is needsReview', () {
      expect(
        performanceTierFor(knownCount: 3, total: 10),
        PerformanceTier.needsReview,
      );
    });

    test('boundary: exactly 80% is mastery, not developing', () {
      expect(
        performanceTierFor(knownCount: 4, total: 5),
        PerformanceTier.mastery,
      );
    });

    test('boundary: exactly 50% is developing, not needsReview', () {
      expect(
        performanceTierFor(knownCount: 5, total: 10),
        PerformanceTier.developing,
      );
    });

    test('edge: exactly 0% is needsReview', () {
      expect(
        performanceTierFor(knownCount: 0, total: 10),
        PerformanceTier.needsReview,
      );
    });

    test('failure: a zero-card session is treated as needsReview, not a '
        'division-by-zero crash', () {
      expect(
        performanceTierFor(knownCount: 0, total: 0),
        PerformanceTier.needsReview,
      );
    });
  });

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

  group('prepareRetake', () {
    test('normal: reshuffles multiple cards, keeping the same set and '
        'clearing review status', () {
      final cards = [
        _card('a', status: ReviewStatus.knowIt, cardIndex: 0),
        _card('b', status: ReviewStatus.needsReview, cardIndex: 1),
        _card('c', cardIndex: 2),
      ];

      final result = prepareRetake(flashcards: cards, random: Random(1));

      expect(result.flashcards.map((f) => f.flashcardId).toSet(), {
        'a',
        'b',
        'c',
      });
      expect(result.flashcards.every((f) => f.reviewStatus == null), isTrue);
      expect(
        result.flashcards.map((f) => f.cardIndex).toList(),
        List.generate(cards.length, (i) => i),
      );
      expect(result.sessionFields.knownCount, 0);
      expect(result.sessionFields.needsReviewCount, 0);
      expect(result.sessionFields.currentFlashcardIndex, 0);
      expect(result.sessionFields.isSessionCompleted, isFalse);
      expect(result.sessionFields.completedAt, isNull);
      expect(result.sessionFields.earnedPoints, 0);
    });

    test('edge: a single-card deck still resets status and index', () {
      final cards = [_card('solo', status: ReviewStatus.knowIt, cardIndex: 0)];

      final result = prepareRetake(flashcards: cards);

      expect(result.flashcards, hasLength(1));
      expect(result.flashcards.single.reviewStatus, isNull);
      expect(result.flashcards.single.cardIndex, 0);
    });

    test('failure: an empty deck does not crash and resets session fields '
        'regardless', () {
      final result = prepareRetake(flashcards: const []);

      expect(result.flashcards, isEmpty);
      expect(result.sessionFields.knownCount, 0);
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
}
