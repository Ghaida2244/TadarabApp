import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/event_time.dart';

/// Thrown when a profile write fails, carrying a message fit to show the
/// student. Mirrors `CalendarFailure` / `CoursesFailure`.
class ProfileFailure implements Exception {
  ProfileFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

const _saveFailureMessage =
    "Couldn't save your changes. Check your connection and try again.";

/// Writes the student's own profile fields.
///
/// Deliberately narrow field updates rather than writing a whole [Student]:
/// the model is a shared file frozen after Phase B, and its `copyWith` only
/// accepts the streak fields, so saving a name through it isn't possible
/// without editing it. Same approach `CalendarService` takes.
///
/// Reading is not this service's job — the Profile screen watches the
/// student document through `HomeDataService.watchStudent`, which already
/// exists and which Home already uses.
///
/// Declared as a plain class with overridable methods so widget tests can
/// subclass it, matching the AuthService/CalendarService fake pattern.
class ProfileService {
  ProfileService({FirebaseFirestore? firestore}) : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _studentDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Saves a new display name.
  ///
  /// Only the Firestore `name` field is written. Firebase Auth's
  /// `displayName` is deliberately left alone: it is set once at signup and
  /// read nowhere in the app, so updating it would add an auth round-trip
  /// (and a second failure mode) for a value nothing displays. Noted in
  /// CLAUDE.md, since it means the two can drift.
  Future<void> updateName(String uid, String name) async {
    try {
      await _studentDoc(uid).update({'name': name.trim()});
    } catch (_) {
      throw ProfileFailure(_saveFailureMessage);
    }
  }

  /// Saves the daily study reminder's state.
  ///
  /// [time] is stored as `"HH:mm"` to match `Student.reminderTime`, and is
  /// cleared along with the flag when [enabled] is false — the same shape as
  /// an account that never set one, per the Attributes Dictionary's
  /// `reminderEnabled: false` / `reminderTime: null` default.
  Future<void> updateStudyReminder(
    String uid, {
    required bool enabled,
    required TimeOfDay? time,
  }) async {
    try {
      await _studentDoc(uid).update({
        'reminderEnabled': enabled,
        'reminderTime': enabled && time != null
            ? formatEventTimeForStorage(time)
            : null,
      });
    } catch (_) {
      throw ProfileFailure(_saveFailureMessage);
    }
  }
}
