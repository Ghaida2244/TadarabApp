import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../logic/flashcard_logic.dart';

/// Screen 6: confirms deleting a flashcard session. Body text differs for a
/// completed vs. an in-progress session — see [deleteSessionBody].
class DeleteSessionDialog extends StatelessWidget {
  const DeleteSessionDialog({
    super.key,
    required this.isCompleted,
    required this.knownCount,
    required this.needsReviewCount,
    required this.onDelete,
  });

  final bool isCompleted;
  final int knownCount;
  final int needsReviewCount;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      insetPadding: const EdgeInsets.all(26),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.errorBannerBackground,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.delete_outline, size: 24, color: AppColors.red),
              ),
            ),
            const SizedBox(height: 13),
            Text(
              'Delete this session?',
              textAlign: TextAlign.center,
              style: AppTypography.screenTitleCompact.copyWith(fontSize: 19),
            ),
            const SizedBox(height: 13),
            Text(
              deleteSessionBody(
                isCompleted: isCompleted,
                knownCount: knownCount,
                needsReviewCount: needsReviewCount,
              ),
              textAlign: TextAlign.center,
              style: AppTypography.subtitle.copyWith(height: 1.6),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Delete session',
              variant: AppButtonVariant.accent,
              height: 52,
              shadowColor: AppColors.redShadow.withValues(alpha: 0.6),
              onPressed: () {
                Navigator.of(context).pop();
                onDelete();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Keep it',
              variant: AppButtonVariant.outlinedNeutral,
              height: 46,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [DeleteSessionDialog] and returns once dismissed.
Future<void> showDeleteSessionDialog(
  BuildContext context, {
  required bool isCompleted,
  required int knownCount,
  required int needsReviewCount,
  required VoidCallback onDelete,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => DeleteSessionDialog(
      isCompleted: isCompleted,
      knownCount: knownCount,
      needsReviewCount: needsReviewCount,
      onDelete: onDelete,
    ),
  );
}
