import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/calendar_event.dart';
import '../theme/app_theme.dart';
import '../utils/event_time.dart';

/// Notification title for every event reminder, exactly as SRS Figure 107
/// shows it. Deliberately generic rather than the event's name: the same
/// text is used for all events, per the SRS.
const kEventReminderTitle = 'Event Reminder';

/// Notification body for every event reminder, exactly as SRS Figure 107
/// shows it.
const kEventReminderBody = "Don't forget your upcoming event.";

/// Notification title for the daily study reminder, exactly as the SRS
/// specifies. Distinct from the event reminder above: this one nudges the
/// student to study at all, not about a specific event.
const kStudyReminderTitle = 'Time to Study!';

/// Notification body for the daily study reminder, exactly as the SRS
/// specifies.
const kStudyReminderBody = 'Open Tadarab and continue your learning journey.';

/// The notification ID reserved for the daily study reminder.
///
/// **Negative on purpose, and that is what makes it collision-proof.**
/// [notificationIdFor] masks an event's hash with `& 0x7FFFFFFF`, so it can
/// only ever return a value in `[0, 2^31-1]` — no event ID can produce a
/// negative number, for any input. The plugin takes a bare `int id` with no
/// validation, and Android accepts negative notification IDs and
/// PendingIntent request codes.
///
/// The alternative — reserving a positive constant — would carry the same
/// (vanishingly small) hash-collision risk that event IDs already carry
/// against each other, and renumbering event IDs to free up a range would
/// orphan every reminder already scheduled on a device.
const int kStudyReminderNotificationId = -1;

/// Schedules and cancels the local notification for a calendar event's
/// reminder, and the student's daily study reminder.
///
/// Every method is a no-op that swallows platform errors rather than
/// throwing: a reminder is a convenience on top of the event, so failing to
/// schedule one must never stop the event itself from being saved or
/// deleted. Whether the notification was scheduled is reported by the
/// return value instead, so callers can tell the student when a reminder
/// couldn't be set.
///
/// Declared as a plain class (not abstract) with overridable methods so
/// widget tests can subclass it, matching the AuthService/HomeDataService
/// fake pattern used elsewhere.
class ReminderScheduler {
  ReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _pluginOverride = plugin;

  final FlutterLocalNotificationsPlugin? _pluginOverride;

  static final FlutterLocalNotificationsPlugin _sharedPlugin =
      FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get _plugin =>
      _pluginOverride ?? _sharedPlugin;

  bool _initialized = false;

  /// Android notification channel for event reminders. Created implicitly
  /// on the first scheduled notification.
  static const _androidDetails = AndroidNotificationDetails(
    'event_reminders',
    'Event reminders',
    channelDescription: 'Reminders for events you added to your calendar.',
    importance: Importance.high,
    priority: Priority.high,
    color: AppColors.navy,
  );

  /// Android notification channel for the daily study reminder. Separate
  /// from the event channel so a student can silence study nudges without
  /// losing event reminders, and vice versa.
  static const _studyAndroidDetails = AndroidNotificationDetails(
    'study_reminder',
    'Daily study reminder',
    channelDescription: 'Your daily nudge to open Tadarab and study.',
    importance: Importance.high,
    priority: Priority.high,
    color: AppColors.navy,
  );

  /// Loads the timezone database and points it at the device's zone, which
  /// `zonedSchedule` needs to fire at the right local wall-clock time
  /// (rather than drifting by the UTC offset).
  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
        ),
      );
      _initialized = true;
    } catch (_) {
      // Leave _initialized false; scheduling will simply report failure.
    }
  }

  /// Asks for the Android 13+ POST_NOTIFICATIONS permission. Returns false
  /// if the student declines or the platform call fails.
  Future<bool> requestPermission() async {
    await init();
    if (!_initialized) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return false;
      return await android.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Schedules [event]'s reminder. Returns false — without throwing — when
  /// the event has no usable reminder, when its fire time has already
  /// passed, or when the platform refuses the request.
  ///
  /// A fire time in the past is a normal case, not an error: a student can
  /// legitimately add an event for later today with a 1-day reminder.
  Future<bool> scheduleReminder(CalendarEvent event) async {
    final fireTime = reminderFireTime(event);
    if (fireTime == null) return false;

    await init();
    if (!_initialized) return false;

    final scheduled = tz.TZDateTime.from(fireTime, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return false;

    try {
      await _plugin.zonedSchedule(
        id: notificationIdFor(event.eventId),
        title: kEventReminderTitle,
        body: kEventReminderBody,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: _androidDetails,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cancels a previously scheduled reminder. Safe to call for an event
  /// that never had one.
  Future<void> cancelReminder(String eventId) async {
    try {
      await _plugin.cancel(id: notificationIdFor(eventId));
    } catch (_) {
      // Nothing to do — the reminder is gone either way.
    }
  }

  /// Schedules the daily study reminder for [time], replacing any previous
  /// one, and reports whether it was actually set.
  ///
  /// Repeats every day at the same wall-clock time via
  /// `DateTimeComponents.time`. The first occurrence is today if [time] is
  /// still ahead, otherwise tomorrow — so enabling a 9am reminder at 10am
  /// doesn't fire immediately or wait a day to start repeating.
  ///
  /// Like [scheduleReminder], this never throws: a reminder that can't be
  /// set must not stop the student's choice from being saved, so the caller
  /// is told by the return value instead.
  Future<bool> scheduleDailyStudyReminder(TimeOfDay time) async {
    await init();
    if (!_initialized) return false;

    try {
      await _plugin.zonedSchedule(
        id: kStudyReminderNotificationId,
        title: kStudyReminderTitle,
        body: kStudyReminderBody,
        scheduledDate: _nextOccurrenceOf(time),
        notificationDetails: const NotificationDetails(
          android: _studyAndroidDetails,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // What makes it daily rather than one-shot: the plugin re-fires it
        // whenever the clock next matches this time-of-day.
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cancels the daily study reminder. Safe to call when none is set.
  Future<void> cancelDailyStudyReminder() async {
    try {
      await _plugin.cancel(id: kStudyReminderNotificationId);
    } catch (_) {
      // Nothing to do — the reminder is gone either way.
    }
  }

  /// The next moment the clock reads [time], today or tomorrow.
  tz.TZDateTime _nextOccurrenceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }
}

/// Maps a Firestore document ID onto the 32-bit int the notification APIs
/// use for IDs, so an event's reminder can be cancelled later without
/// storing a second identifier alongside it.
///
/// `hashCode` is not stable across runs for arbitrary objects, but *is*
/// defined for String by its contents, which is what makes this usable as
/// a persistent handle. Masked to stay positive and within 32 bits.
int notificationIdFor(String eventId) => eventId.hashCode & 0x7FFFFFFF;
