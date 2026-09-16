import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';

/// The "Delete this event?" confirmation. A centered dialog rather than a
/// bottom sheet, matching 04_delete_event_confirmation.png.
///
/// Resolves to true when the student confirms, and to false when they
/// cancel *or* dismiss it by tapping outside — so callers can treat any
/// non-true result as "don't delete" without a null check.
Future<bool> showDeleteEventDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.navy.withValues(alpha: 0.38),
    builder: (context) => const _DeleteEventDialog(),
  );
  return confirmed ?? false;
}

class _DeleteEventDialog extends StatelessWidget {
  const _DeleteEventDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delete this event?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The selected event will be removed from your calendar.',
              style: AppTypography.subtitle.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 22),
            AppButton(
              label: 'Delete',
              variant: AppButtonVariant.accent,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.outlinedNeutral,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
