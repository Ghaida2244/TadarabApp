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

/// What a Retake-via-Worker outcome gives back to the UI: the fresh card
/// count, how many were actually requested (so the caller can tell if it
/// fell short, same as [FlashcardGenerationResult.requestedCount]), the
/// Worker's own `note` if it sent one, and the id of the brand-new session
/// the retake created (a retake no longer overwrites the session it was
/// started from — see [FlashcardService.retake]).
typedef RetakeOutcome = ({
  int requestedCount,
  int actualCount,
  String? note,
  String newSessionId,
});

/// Retake's card-write plan for its new session's cards, given how many
/// cards that new session already had (always 0 — it's brand new) and how
/// many the Worker generated this time. Kept in this shape (rather than a
/// plain "write N new docs") so [FlashcardService.retake] reuses the exact
/// same write-planning function it did before the new-session-per-retake
/// redesign. See [FlashcardService.retake].
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
