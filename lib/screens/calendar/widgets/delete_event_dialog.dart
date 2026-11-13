import 'package:flutter/material.dart';

import '../../../models/calendar_event.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/confirm_dialog.dart';

/// The two leading sentences of the confirmation body, chosen by whether the
/// event actually has a reminder to cancel.
const kDeleteBodyWithReminder = 'Its reminder will be cancelled too.';
const kDeleteBodyNoReminder = 'It will be removed from this day.';

/// The fixed tail appended to either of the above.
const kDeleteBodyTail = "This can't be undone.";

/// The body text for deleting [event]: a sentence about what else goes with
/// it, then the irreversibility warning.
///
/// A reminder is only mentioned when one is really scheduled — an event
/// whose reminder was stored as `false` (permission denied, or the platform
/// refused to schedule it) has nothing to cancel, so promising otherwise
/// would be a lie.
String deleteEventBody(CalendarEvent event) {
  final lead = event.reminderEnabled
      ? kDeleteBodyWithReminder
      : kDeleteBodyNoReminder;
  return '$lead $kDeleteBodyTail';
}

/// The "Delete this event?" confirmation — a centred dialog with a tinted
/// trash badge above the title.
///
/// Resolves to true when the student confirms, and to false when they
/// cancel *or* dismiss it by tapping outside — so callers can treat any
/// non-true result as "don't delete" without a null check.
Future<bool> showDeleteEventDialog(
  BuildContext context, {
  required CalendarEvent event,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.navy.withValues(alpha: 0.5),
    builder: (context) => ConfirmDialog(
      title: 'Delete this event?',
      message: deleteEventBody(event),
      confirmLabel: 'Delete event',
    ),
  );
  return confirmed ?? false;
}
