import 'package:flutter/material.dart';
import 'package:tadarab_app/services/profile_service.dart';

/// A controllable stand-in for [ProfileService], so the Profile widget tests
/// never touch a real Firestore. Mirrors FakeCalendarService's role.
class FakeProfileService extends ProfileService {
  FakeProfileService({this.nameError, this.reminderError});

  /// Thrown by [updateName] / [updateStudyReminder] when set, to drive the
  /// save-failure states.
  final ProfileFailure? nameError;
  final ProfileFailure? reminderError;

  final List<String> savedNames = [];
  final List<({bool enabled, TimeOfDay? time})> savedReminders = [];

  @override
  Future<void> updateName(String uid, String name) async {
    if (nameError != null) throw nameError!;
    savedNames.add(name);
  }

  @override
  Future<void> updateStudyReminder(
    String uid, {
    required bool enabled,
    required TimeOfDay? time,
  }) async {
    if (reminderError != null) throw reminderError!;
    savedReminders.add((enabled: enabled, time: time));
  }
}
