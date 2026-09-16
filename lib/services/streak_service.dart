import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student.dart';

/// Strips the time-of-day off [dateTime], in local time, so day comparisons
/// are midnight-to-midnight rather than a rolling 24-hour window.
DateTime dateOnly(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

/// Computes the streak that results from a committed study activity on
/// [activityDate], given the student's current streak state. Pure and
/// Firestore-free so it's trivially unit-testable.
///
/// Rules: the streak is entirely independent of week boundaries and the
/// points system — it only cares about the gap, in whole local calendar
/// days, since the last recorded activity.
/// - No prior activity: this is day 1 of a new streak.
/// - Same calendar day as the last activity: no change (a second session
///   the same day doesn't double-count, but doesn't need a minimum count
///   either — the first one already started/continued the streak).
/// - Exactly one day later: consecutive — extends the streak by 1.
/// - Two or more days later: at least one full calendar day passed with
///   zero activity — the streak is broken and restarts at 1.
int computeNextStreak({
  required int currentStreak,
  required DateTime? lastStudyDate,
  required DateTime activityDate,
}) {
  final today = dateOnly(activityDate);
  if (lastStudyDate == null) return 1;

  final last = dateOnly(lastStudyDate);
  final gapInDays = today.difference(last).inDays;

  if (gapInDays <= 0) return currentStreak;
  if (gapInDays == 1) return currentStreak + 1;
  return 1;
}

/// Firestore-backed wrapper around [computeNextStreak]. Intended to be
/// called once a quiz or flashcard session is actually committed
/// (completed) — there's no session-completion flow built yet (that's
/// Phase C), so nothing calls this today, but it's ready for that flow to
/// call. Never touches totalPoints — the streak is fully independent of
/// the points system.
class StreakService {
  StreakService({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  Future<void> recordStudyActivity({
    required String uid,
    required DateTime activityDate,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final student = Student.fromFirestore(snapshot);
    final nextStreak = computeNextStreak(
      currentStreak: student.currentStreak,
      lastStudyDate: student.lastStudyDate,
      activityDate: activityDate,
    );

    await docRef.update({
      'currentStreak': nextStreak,
      'lastStudyDate': Timestamp.fromDate(dateOnly(activityDate)),
    });
  }
}
