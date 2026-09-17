import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/enums.dart';
import '../services/streak_service.dart' show dateOnly;

/// Pure date/time helpers behind the Calendar screens. Kept free of widgets
/// and Firestore so the month-grid maths and the reminder arithmetic — the
/// parts most likely to be wrong at a month or DST boundary — can be unit
/// tested directly instead of only through the UI.

/// Weekday column headers, Sunday-first, matching the mockup's grid.
const List<String> kWeekdayHeaders = [
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

/// Two-letter weekday headers for the Add Event date picker sheet, which
/// uses a narrower grid than the Calendar tab (Figure 98).
const List<String> kWeekdayHeadersShort = [
  'Su',
  'Mo',
  'Tu',
  'We',
  'Th',
  'Fr',
  'Sa',
];

/// Full month names used by the month title ("May 2026") and the
/// event-details sheet heading ("May 14, 2026").
const List<String> kMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Number of days in [month] of [year]. Day 0 of the *next* month is the
/// last day of this one, which gets leap years right without a special case.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// The first of the month containing [date], with time-of-day stripped.
/// The Calendar screen holds its "currently viewed month" in this form.
DateTime firstOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

/// Steps [month] forward ([delta] positive) or back, rolling the year over.
/// Always returns the first of the resulting month, so repeatedly stepping
/// from a 31st never skips a short month.
DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta, 1);

/// The month grid's cells, Sunday-first: leading `null`s for the blank cells
/// before the 1st, then one entry per day of the month. There is no trailing
/// padding — the mockup's last row simply ends after the final day.
List<DateTime?> monthGridCells(DateTime month) {
  final first = firstOfMonth(month);
  // DateTime.weekday is Monday=1..Sunday=7; `% 7` maps Sunday to column 0.
  final leadingBlanks = first.weekday % 7;
  final total = daysInMonth(first.year, first.month);
  return [
    for (var i = 0; i < leadingBlanks; i++) null,
    for (var day = 1; day <= total; day++) DateTime(first.year, first.month, day),
  ];
}

/// True when [a] and [b] fall on the same local calendar day.
bool isSameDay(DateTime a, DateTime b) => dateOnly(a) == dateOnly(b);

/// Parses the `"HH:mm"` form stored on [CalendarEvent.eventTime]. Returns
/// null for anything malformed rather than throwing, since a bad stored
/// value should degrade the display, not crash the Calendar.
TimeOfDay? parseEventTime(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// Formats a [TimeOfDay] as `"HH:mm"` for storage.
String formatEventTimeForStorage(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// Converts the time picker's 12-hour selection into a [TimeOfDay].
///
/// 12 is the edge case both ways: 12 AM is midnight (hour 0) and 12 PM is
/// noon (hour 12) — naively adding 12 for PM would turn noon into 24.
/// Returns null for an hour outside 1–12 or a minute outside 0–59 rather
/// than building an invalid time.
TimeOfDay? timeOfDayFrom12Hour({
  required int hour12,
  required int minute,
  required bool isPm,
}) {
  if (hour12 < 1 || hour12 > 12 || minute < 0 || minute > 59) return null;
  final base = hour12 % 12; // 12 -> 0, so AM/PM can be added uniformly.
  return TimeOfDay(hour: isPm ? base + 12 : base, minute: minute);
}

/// Formats a [TimeOfDay] for display as `"12:00 PM"`. Deliberately not
/// locale-aware: every mockup frame shows 12-hour time with an uppercase
/// meridiem, and the app is English-only.
String formatEventTimeForDisplay(TimeOfDay time) {
  final meridiem = time.hour < 12 ? 'AM' : 'PM';
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$hour12:${time.minute.toString().padLeft(2, '0')} $meridiem';
}

/// Formats the stored `"HH:mm"` string straight to display form, falling
/// back to the raw stored value if it can't be parsed.
String formatStoredTimeForDisplay(String stored) {
  final parsed = parseEventTime(stored);
  return parsed == null ? stored : formatEventTimeForDisplay(parsed);
}

/// "May 5, 2026" — the Add Event date field and details-sheet heading.
String formatLongDate(DateTime date) =>
    '${kMonthNames[date.month - 1]} ${date.day}, ${date.year}';

/// "May 2026" — the month title between the ‹ › arrows.
String formatMonthTitle(DateTime month) =>
    '${kMonthNames[month.month - 1]} ${month.year}';

/// The event's date and time-of-day as a single local [DateTime].
/// Falls back to midnight when [CalendarEvent.eventTime] is unparseable.
DateTime eventDateTime(CalendarEvent event) {
  final time = parseEventTime(event.eventTime);
  final date = dateOnly(event.eventDate);
  if (time == null) return date;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// [amount] of [unit] as a [Duration]. Weeks and days are treated as fixed
/// 7×24h / 24h spans; a reminder is a rough "remind me this far ahead", not
/// a wall-clock guarantee across a DST shift.
Duration reminderLeadTime(int amount, ReminderUnit unit) {
  switch (unit) {
    case ReminderUnit.minutes:
      return Duration(minutes: amount);
    case ReminderUnit.hours:
      return Duration(hours: amount);
    case ReminderUnit.days:
      return Duration(days: amount);
    case ReminderUnit.weeks:
      return Duration(days: 7 * amount);
  }
}

/// When this event's reminder should fire, or null when it has no usable
/// reminder — disabled, or missing its amount/unit (both are nullable on
/// the model, so an enabled-but-incomplete reminder is representable and
/// must not be scheduled).
DateTime? reminderFireTime(CalendarEvent event) {
  if (!event.reminderEnabled) return null;
  final amount = event.reminderBefore;
  final unit = event.reminderUnit;
  if (amount == null || unit == null) return null;
  return eventDateTime(event).subtract(reminderLeadTime(amount, unit));
}

/// True when [event] has a usable reminder whose fire time is already at or
/// before [now] — so it can never be delivered and must not be saved as if
/// it will be. An event with no reminder (or an incomplete one) is not
/// "passed"; there is simply nothing to schedule.
bool reminderAlreadyPassed(CalendarEvent event, DateTime now) {
  final fireTime = reminderFireTime(event);
  if (fireTime == null) return false;
  return !fireTime.isAfter(now);
}

/// Singular/plural unit label for the reminder row: "1 Day", "2 Days".
String formatReminderUnitLabel(int amount, ReminderUnit unit) {
  final singular = switch (unit) {
    ReminderUnit.minutes => 'Minute',
    ReminderUnit.hours => 'Hour',
    ReminderUnit.days => 'Day',
    ReminderUnit.weeks => 'Week',
  };
  return amount == 1 ? singular : '${singular}s';
}
