import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/services/reminder_scheduler.dart';

/// A stand-in for [ReminderScheduler] that records what it was asked to
/// schedule instead of touching the notifications plugin (which has no
/// implementation under `flutter test`).
class FakeReminderScheduler extends ReminderScheduler {
  FakeReminderScheduler({this.scheduleResult = true});

  /// What [scheduleReminder] reports back — false simulates a reminder the
  /// platform refused or that was already in the past.
  final bool scheduleResult;

  final List<CalendarEvent> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> scheduleReminder(CalendarEvent event) async {
    scheduled.add(event);
    return scheduleResult;
  }

  @override
  Future<void> cancelReminder(String eventId) async {
    cancelled.add(eventId);
  }
}
