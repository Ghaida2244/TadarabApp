import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/calendar_event.dart';
import '../utils/event_time.dart';

/// Notification title for every event reminder, exactly as SRS Figure 107
/// shows it. Deliberately generic rather than the event's name: the same
/// text is used for all events, per the SRS.
const kEventReminderTitle = 'Event Reminder';

/// Notification body for every event reminder, exactly as SRS Figure 107
/// shows it.
const kEventReminderBody = "Don't forget your upcoming event.";

/// Schedules and cancels the local notification for a calendar event's
/// reminder.
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
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
}

/// Maps a Firestore document ID onto the 32-bit int the notification APIs
/// use for IDs, so an event's reminder can be cancelled later without
/// storing a second identifier alongside it.
///
/// `hashCode` is not stable across runs for arbitrary objects, but *is*
/// defined for String by its contents, which is what makes this usable as
/// a persistent handle. Masked to stay positive and within 32 bits.
int notificationIdFor(String eventId) => eventId.hashCode & 0x7FFFFFFF;
