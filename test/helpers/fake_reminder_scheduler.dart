import 'package:flutter/material.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/services/reminder_scheduler.dart';

/// A stand-in for [ReminderScheduler] that records what it was asked to
/// schedule instead of touching the notifications plugin (which has no
/// implementation under `flutter test`).
class FakeReminderScheduler extends ReminderScheduler {
  FakeReminderScheduler({
    this.scheduleResult = true,
    this.permissionGranted = true,
  });

  /// What [scheduleReminder] reports back — false simulates a reminder the
  /// platform refused or that was already in the past.
  final bool scheduleResult;

  /// What [requestPermission] reports back — false simulates the student
  /// declining Android's notification permission dialog.
  final bool permissionGranted;

  final List<CalendarEvent> scheduled = [];

  /// The `courseName` each entry in [scheduled] was asked to schedule
  /// with, in the same order — so a test can check what name (or null) a
  /// given call passed, not just that a call happened.
  final List<String?> scheduledCourseNames = [];

  final List<String> cancelled = [];
  int permissionRequests = 0;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<bool> scheduleReminder(
    CalendarEvent event, {
    String? courseName,
  }) async {
    scheduled.add(event);
    scheduledCourseNames.add(courseName);
    return scheduleResult;
  }

  @override
  Future<void> cancelReminder(String eventId) async {
    cancelled.add(eventId);
  }

  /// Times the daily study reminder was scheduled for.
  final List<TimeOfDay> dailyScheduled = [];

  /// How many times the daily study reminder was cancelled.
  int dailyCancelled = 0;

  @override
  Future<bool> scheduleDailyStudyReminder(TimeOfDay time) async {
    dailyScheduled.add(time);
    return scheduleResult;
  }

  @override
  Future<void> cancelDailyStudyReminder() async {
    dailyCancelled++;
  }
}
