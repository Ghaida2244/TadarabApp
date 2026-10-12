/// Shared, pure helpers for the generation Worker's `coveredTopics`
/// (response) and `previousTopics` (request) fields — used by both Quiz's
/// [QuizGenerationClient] (quiz_generation_client.dart) and Flashcards'
/// [FlashcardService] (flashcard_service.dart) so the two features don't
/// duplicate (or drift on) this logic. New, neutral file — not owned by
/// either feature.
///
/// Limits mirror worker/src/generation.js's own
/// (MAX_PREVIOUS_TOPICS = 100, MAX_PREVIOUS_TOPIC_LENGTH = 80). The Worker
/// already enforces these server-side and never rejects an over-limit
/// list — it silently trims/caps instead (see `normalizePreviousTopics`
/// there) — but capping client-side too keeps the request itself honest
/// about what will actually be used, per the task's instruction.
const int kMaxPreviousTopics = 100;
const int kMaxPreviousTopicLength = 80;

/// Safely reads a Worker response's `coveredTopics` field: an empty list
/// for anything that isn't a list (missing, null, wrong type), and only
/// the `String` entries of one that is — never throws.
List<String> parseCoveredTopics(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

/// Builds the `previousTopics` to send on a retake, from the SOURCE
/// session's own stored `coveredTopics` only — never a union across other
/// sessions in the same retake group. Drops blank entries and
/// case-insensitive duplicates (keeping the first occurrence's casing),
/// then trims each surviving entry and the whole list to the Worker's own
/// limits. An old session with no stored `coveredTopics` yields an empty
/// list here, which the caller should then omit from the request entirely.
List<String> buildPreviousTopics(List<String> sourceCoveredTopics) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in sourceCoveredTopics) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    result.add(
      trimmed.length > kMaxPreviousTopicLength
          ? trimmed.substring(0, kMaxPreviousTopicLength)
          : trimmed,
    );
    if (result.length >= kMaxPreviousTopics) break;
  }
  return result;
}
