/// Pure, generic grouping logic for the "Retake Stacks" design — groups a
/// course's sessions into [SessionStack]s by shared retake-chain root,
/// computed separately within each section (in-progress vs completed) so
/// a stack never mixes an in-progress attempt with a completed one.
///
/// Generic over callbacks rather than a concrete model (Quiz's
/// `QuizSession` or Flashcards' `FlashcardSession`), so both features can
/// use this file without it depending on either one's models. Entirely
/// client-side over whatever sessions the caller already loaded — no new
/// Firestore query or index.
library;

/// One row the stacking algorithm produces for a single section: either a
/// lone session (today's plain card) or 2+ sessions sharing the same
/// retake-chain root (a stack). [sessions] is always latest-first and
/// never empty.
class SessionStack<T> {
  SessionStack({required this.sessions, required this.isCompleted})
    : assert(sessions.isNotEmpty, 'A SessionStack needs at least one session');

  final List<T> sessions;

  /// Which section this group belongs to — true for "completed", false
  /// for "in progress". A group's sessions are always all the same.
  final bool isCompleted;

  /// The latest attempt — what a single card, or a collapsed stack's top
  /// card, represents.
  T get top => sessions.first;

  /// Whether this group renders as a stack (2+ attempts) rather than a
  /// plain single card.
  bool get isStack => sessions.length > 1;
}

/// Groups [sessions] into [SessionStack]s. See the library doc comment for
/// the section-separation rule.
///
/// Ordering:
/// - WITHIN a stack (latest first): completed attempts by [completedAt]
///   descending (falling back to [createdAt] when null); in-progress
///   attempts by [retakeNumber] descending (falling back to [createdAt]).
/// - BETWEEN stacks/cards within one section: exactly the criterion the
///   pre-stacking list already used, applied to each group's own top
///   (already-sorted) attempt — completed by [completedAt] descending
///   (fallback [createdAt]), in-progress by [createdAt] descending. This
///   is deliberately NOT [retakeNumber]-aware, so introducing stacking
///   never changes the section's overall order from before stacks existed.
///
/// Both comparisons fall back to each session's original position in
/// [sessions] to break ties deterministically (list sorts aren't
/// guaranteed stable).
List<SessionStack<T>> groupSessionsIntoStacks<T>({
  required List<T> sessions,
  required bool Function(T session) isCompleted,
  required String Function(T session) rootSessionId,
  required int Function(T session) retakeNumber,
  required DateTime Function(T session) createdAt,
  required DateTime? Function(T session) completedAt,
}) {
  List<SessionStack<T>> forSection(bool completed) {
    final sectionIndices = <int>[
      for (var i = 0; i < sessions.length; i++)
        if (isCompleted(sessions[i]) == completed) i,
    ];

    int compareWithinStack(int ia, int ib) {
      final a = sessions[ia];
      final b = sessions[ib];
      if (completed) {
        final ca = completedAt(a) ?? createdAt(a);
        final cb = completedAt(b) ?? createdAt(b);
        final cmp = cb.compareTo(ca);
        if (cmp != 0) return cmp;
      } else {
        final cmp = retakeNumber(b).compareTo(retakeNumber(a));
        if (cmp != 0) return cmp;
        final cmp2 = createdAt(b).compareTo(createdAt(a));
        if (cmp2 != 0) return cmp2;
      }
      return ia.compareTo(ib);
    }

    int compareBetweenGroups(int ia, int ib) {
      final a = sessions[ia];
      final b = sessions[ib];
      if (completed) {
        final ca = completedAt(a) ?? createdAt(a);
        final cb = completedAt(b) ?? createdAt(b);
        final cmp = cb.compareTo(ca);
        if (cmp != 0) return cmp;
      } else {
        final cmp = createdAt(b).compareTo(createdAt(a));
        if (cmp != 0) return cmp;
      }
      return ia.compareTo(ib);
    }

    final indicesByRoot = <String, List<int>>{};
    for (final i in sectionIndices) {
      indicesByRoot.putIfAbsent(rootSessionId(sessions[i]), () => []).add(i);
    }

    final groupedIndices = indicesByRoot.values
        .map((indices) => List<int>.from(indices)..sort(compareWithinStack))
        .toList()
      ..sort((groupA, groupB) => compareBetweenGroups(groupA.first, groupB.first));

    return [
      for (final indices in groupedIndices)
        SessionStack<T>(
          sessions: [for (final i in indices) sessions[i]],
          isCompleted: completed,
        ),
    ];
  }

  return [...forSection(false), ...forSection(true)];
}
