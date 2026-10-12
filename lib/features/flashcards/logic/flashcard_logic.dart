import 'dart:math';

import '../../../models/flashcard.dart';
import '../../../models/flashcard_session.dart';

/// Points awarded per flashcard marked "I Know It" at session (or Retake)
/// completion — see CLAUDE.md's Points system section.
const kPointsPerKnownFlashcard = 2;

/// +2 points per flashcard marked "I Know It". Computed and persisted once,
/// at completion — never recomputed by the (read-only) Review Pass screen.
int calculateEarnedPoints({required int knownCount}) {
  assert(knownCount >= 0, 'knownCount cannot be negative');
  return knownCount * kPointsPerKnownFlashcard;
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

/// What a Retake-via-Worker outcome gives back to the UI: the fresh card
/// count, how many were actually requested (so the caller can tell if it
/// fell short, same as [FlashcardGenerationResult.requestedCount]), and the
/// Worker's own `note` if it sent one. See [FlashcardService.retake].
typedef RetakeOutcome = ({int requestedCount, int actualCount, String? note});

/// Retake's card-write plan, given how many cards the session already had
/// and how many the Worker generated this time: the first
/// `min(existingCount, newCount)` existing card docs are overwritten in
/// place with the new content (reusing their ids); if there are more new
/// cards than old ones, the rest are added as brand-new docs; if there are
/// fewer, the leftover old ones are deleted. See
/// [FlashcardService.retake].
typedef RetakeCardWritePlan = ({int overwriteCount, int addCount, int deleteCount});

RetakeCardWritePlan planRetakeCardWrites({
  required int existingCount,
  required int newCount,
}) {
  assert(existingCount >= 0, 'existingCount cannot be negative');
  assert(newCount >= 0, 'newCount cannot be negative');
  final overwriteCount = existingCount < newCount ? existingCount : newCount;
  return (
    overwriteCount: overwriteCount,
    addCount: newCount - overwriteCount,
    deleteCount: existingCount - overwriteCount,
  );
}

/// Splits [totalOperations] Firestore writes into batches of at most
/// [maxPerBatch] (Firestore's hard per-batch cap is 500) — returns each
/// batch's size, e.g. 1042 operations at the default cap -> [500, 500, 42].
List<int> batchSizes({required int totalOperations, int maxPerBatch = 500}) {
  assert(totalOperations >= 0, 'totalOperations cannot be negative');
  assert(maxPerBatch > 0, 'maxPerBatch must be positive');
  final sizes = <int>[];
  var remaining = totalOperations;
  while (remaining > 0) {
    final size = remaining < maxPerBatch ? remaining : maxPerBatch;
    sizes.add(size);
    remaining -= size;
  }
  return sizes;
}

/// Sorts a course's flashcard sessions newest first. Pulled out as a pure
/// function (rather than a Firestore `orderBy('createdAt')`) so
/// [FlashcardService.watchSessions] doesn't need a composite index for its
/// `where('courseId', ...)` + ordering — and so the sort itself is directly
/// unit-testable without a real or fake Firestore.
List<FlashcardSession> sortSessionsNewestFirst(
  List<FlashcardSession> sessions,
) {
  return List<FlashcardSession>.from(sessions)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// Sorts the "IN PROGRESS" section (Screen 1) newest-created first — the
/// most recently started session leads. Same ordering as
/// [sortSessionsNewestFirst]; kept as its own named function so each of the
/// screen's two sections has an explicit, independently-testable sort step,
/// even though today they happen to share one implementation.
List<FlashcardSession> sortInProgressSessions(
  List<FlashcardSession> sessions,
) => sortSessionsNewestFirst(sessions);

/// Sorts the "COMPLETED" section (Screen 1) most-recently-completed first.
/// Falls back to [FlashcardSession.createdAt] when
/// [FlashcardSession.completedAt] is null — shouldn't happen for a
/// genuinely completed session, but keeps this sortable rather than
/// crashing or silently pushing it to one end if it ever does.
List<FlashcardSession> sortCompletedSessions(
  List<FlashcardSession> sessions,
) {
  DateTime effectiveDate(FlashcardSession s) => s.completedAt ?? s.createdAt;
  return List<FlashcardSession>.from(sessions)
    ..sort((a, b) => effectiveDate(b).compareTo(effectiveDate(a)));
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
