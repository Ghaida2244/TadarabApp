import 'package:flutter/material.dart';

import '../../../models/calendar_event.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../calendar_styles.dart';

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
    builder: (context) => _DeleteEventDialog(body: deleteEventBody(event)),
  );
  return confirmed ?? false;
}

class _DeleteEventDialog extends StatelessWidget {
  const _DeleteEventDialog({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.errorBannerBackground,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 24,
                color: AppColors.red,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              'Delete this event?',
              textAlign: TextAlign.center,
              style: CalendarText.dialogTitle,
            ),
            const SizedBox(height: 13),
            Text(
              body,
              textAlign: TextAlign.center,
              style: CalendarText.dialogBody,
            ),
            const SizedBox(height: 13),
            AppButton(
              label: 'Delete event',
              variant: AppButtonVariant.accent,
              height: 52,
              borderRadius: 16,
              fontSize: 15,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 13),
            AppButton(
              label: 'Keep it',
              variant: AppButtonVariant.outlinedNeutral,
              height: 46,
              borderRadius: 16,
              borderColor: AppColors.borderDefault,
              fontSize: 14,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
