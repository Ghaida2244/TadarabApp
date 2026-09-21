import 'dart:math';

import '../../../models/flashcard.dart';

/// Points awarded per flashcard marked "I Know It" at session (or Retake)
/// completion — see CLAUDE.md's Points system section.
const kPointsPerKnownFlashcard = 2;

/// +2 points per flashcard marked "I Know It". Computed and persisted once,
/// at completion — never recomputed by the (read-only) Review Pass screen.
int calculateEarnedPoints({required int knownCount}) {
  assert(knownCount >= 0, 'knownCount cannot be negative');
  return knownCount * kPointsPerKnownFlashcard;
}

/// The three Performance Summary message-block tiers.
enum PerformanceTier { mastery, developing, needsReview }

/// Selects the Performance Summary tier from the knownCount/total ratio:
/// >= 0.80 mastery, [0.50, 0.80) developing, below that (including a
/// zero-known session) needsReview. A zero-card session (total == 0) can't
/// happen in practice but is treated as needsReview rather than dividing by
/// zero.
PerformanceTier performanceTierFor({
  required int knownCount,
  required int total,
}) {
  assert(knownCount >= 0, 'knownCount cannot be negative');
  assert(total >= 0, 'total cannot be negative');
  final ratio = total == 0 ? 0.0 : knownCount / total;
  if (ratio >= 0.80) return PerformanceTier.mastery;
  if (ratio >= 0.50) return PerformanceTier.developing;
  return PerformanceTier.needsReview;
}

/// Clamps a stored `currentFlashcardIndex` into the valid `[0, total - 1]`
/// range before Resume opens the Flip Deck, so a corrupted/stale index
/// (e.g. from data written by a future version of the app) can't crash the
/// screen by pointing past the end of the deck.
int resumeIndexFor({required int currentFlashcardIndex, required int total}) {
  if (total <= 0) return 0;
  if (currentFlashcardIndex < 0) return 0;
  if (currentFlashcardIndex > total - 1) return total - 1;
  return currentFlashcardIndex;
}

/// The Session-document fields a Retake resets, alongside the reshuffled
/// deck — see CLAUDE.md's Retake section for the exact list.
typedef RetakeSessionFields = ({
  int knownCount,
  int needsReviewCount,
  int currentFlashcardIndex,
  bool isSessionCompleted,
  DateTime? completedAt,
  int earnedPoints,
});

const kRetakeSessionFields = (
  knownCount: 0,
  needsReviewCount: 0,
  currentFlashcardIndex: 0,
  isSessionCompleted: false,
  completedAt: null,
  earnedPoints: 0,
);

/// Result of [prepareRetake]: the same cards in a freshly-shuffled order
/// (new [Flashcard.cardIndex] per card, [Flashcard.reviewStatus] cleared)
/// plus the session-document fields to reset alongside them. Pure — the
/// caller (FlashcardService) persists both to Firestore.
typedef RetakeResult = ({
  List<Flashcard> flashcards,
  RetakeSessionFields sessionFields,
});

/// Reshuffles the same session's existing flashcards into a new random
/// order and clears every card's review status, per the Retake spec.
/// [random] is injectable so tests can assert on a fixed shuffle.
RetakeResult prepareRetake({
  required List<Flashcard> flashcards,
  Random? random,
}) {
  final shuffled = List<Flashcard>.from(flashcards)
    ..shuffle(random ?? Random());
  final reset = [
    for (var i = 0; i < shuffled.length; i++)
      shuffled[i].copyWith(reviewStatus: () => null, cardIndex: i),
  ];
  return (flashcards: reset, sessionFields: kRetakeSessionFields);
}

/// The Delete-session dialog's body text, which differs for a completed vs.
/// an in-progress session — see CLAUDE.md's Screen 6 section.
String deleteSessionBody({
  required bool isCompleted,
  required int knownCount,
  required int needsReviewCount,
}) {
  if (isCompleted) {
    return "Its counts and review list will go with it. This can't be undone.";
  }
  final marked = knownCount + needsReviewCount;
  return "You will lose the $marked cards already marked. This can't be undone.";
}
