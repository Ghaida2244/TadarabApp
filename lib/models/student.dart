import 'package:cloud_firestore/cloud_firestore.dart';

/// A student account. Stored at users/{uid}; the document ID is the Firebase
/// Auth UID, not the email, since UIDs never change.
///
/// Deliberately has no password field: Firebase Auth owns credentials, so
/// storing one here would duplicate a secret we don't need and shouldn't hold.
class Student {
  Student({
    required this.uid,
    required this.email,
    required this.name,
    this.totalPoints = 0,
    this.currentRank = 'Beginner Learner',
    this.reminderTime,
    this.reminderEnabled = false,
    this.currentStreak = 0,
    this.lastStudyDate,
  });

  /// Firebase Auth UID; also the Firestore document ID.
  final String uid;

  /// Uniquely identifies the student (also used to reference them from other entities).
  final String email;

  /// The student's display name.
  final String name;

  /// Total points earned across all completed sessions.
  final int totalPoints;

  /// The rank name derived from totalPoints (see rank thresholds).
  final String currentRank;

  /// Time of day the daily study reminder should fire, as "HH:mm"; null if never set.
  final String? reminderTime;

  /// Whether the daily study reminder notification is turned on.
  final bool reminderEnabled;

  /// Consecutive calendar days (local time) with at least one committed
  /// study session, up to and including [lastStudyDate]. Not in the
  /// Attributes Dictionary Table — an approved deviation (see
  /// lib/services/streak_service.dart for how it's computed), same pattern
  /// as the earlier StudyMaterial.document deviation. Independent of the
  /// points system: never affects, and is never affected by, totalPoints.
  final int currentStreak;

  /// Calendar date (local time, time-of-day discarded) of the most recent
  /// committed study session; null if the student has never completed one.
  /// Paired with [currentStreak] — see lib/services/streak_service.dart.
  final DateTime? lastStudyDate;

  factory Student.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Student(
      uid: doc.id,
      email: data['email'] as String,
      name: data['name'] as String,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      currentRank: data['currentRank'] as String? ?? 'Beginner Learner',
      reminderTime: data['reminderTime'] as String?,
      reminderEnabled: data['reminderEnabled'] as bool? ?? false,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      lastStudyDate: (data['lastStudyDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'totalPoints': totalPoints,
      'currentRank': currentRank,
      'reminderTime': reminderTime,
      'reminderEnabled': reminderEnabled,
      'currentStreak': currentStreak,
      'lastStudyDate': lastStudyDate == null
          ? null
          : Timestamp.fromDate(lastStudyDate!),
    };
  }

  Student copyWith({int? currentStreak, DateTime? lastStudyDate}) {
    return Student(
      uid: uid,
      email: email,
      name: name,
      totalPoints: totalPoints,
      currentRank: currentRank,
      reminderTime: reminderTime,
      reminderEnabled: reminderEnabled,
      currentStreak: currentStreak ?? this.currentStreak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
    );
  }
}
