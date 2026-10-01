import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';

/// The bottom sheet shown when the student taps X on the Flip Deck: confirms
/// leaving without finishing the deck. The session is never completed here —
/// its progress is already persisted per-card, so "Save and leave" is just a
/// navigation action.
class SaveAndLeaveSheet extends StatelessWidget {
  const SaveAndLeaveSheet({
    super.key,
    required this.reviewedCount,
    required this.total,
    required this.resumeCardNumber,
    required this.onSaveAndLeave,
  });

  final int reviewedCount;
  final int total;
  final int resumeCardNumber;
  final VoidCallback onSaveAndLeave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Leave this deck?', style: AppTypography.screenTitleCompact),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You have marked $reviewedCount of $total cards. We will keep '
              'this session so you can pick it up at card $resumeCardNumber.',
              style: AppTypography.subtitle,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Save and leave',
              variant: AppButtonVariant.primary,
              height: 52,
              shadowColor: AppColors.navyShadow.withValues(alpha: 0.6),
              onPressed: () {
                Navigator.of(context).pop();
                onSaveAndLeave();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Keep going',
              variant: AppButtonVariant.outlinedNeutral,
              height: 48,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [SaveAndLeaveSheet] as a modal bottom sheet.
Future<void> showSaveAndLeaveSheet(
  BuildContext context, {
  required int reviewedCount,
  required int total,
  required int resumeCardNumber,
  required VoidCallback onSaveAndLeave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => SaveAndLeaveSheet(
      reviewedCount: reviewedCount,
      total: total,
      resumeCardNumber: resumeCardNumber,
      onSaveAndLeave: onSaveAndLeave,
    ),
  );
}
