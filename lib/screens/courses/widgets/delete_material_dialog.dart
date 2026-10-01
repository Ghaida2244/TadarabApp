import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';

/// The "Delete [material title]?" confirmation dialog, opened from the
/// trash icon next to a material in Course Detail's materials list.
/// Returns `true` if the student confirmed deletion, `false`/null if they
/// backed out. Deliberately a separate widget from the course-delete
/// dialog (rather than a shared generic one) so that flow stays untouched.
Future<bool> showDeleteMaterialDialog({
  required BuildContext context,
  required String materialTitle,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _DeleteMaterialDialog(materialTitle: materialTitle),
  );
  return result ?? false;
}

class _DeleteMaterialDialog extends StatelessWidget {
  const _DeleteMaterialDialog({required this.materialTitle});

  final String materialTitle;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.errorBannerBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 26,
                color: AppColors.red,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Delete $materialTitle?',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This material will be permanently deleted. '
              "This can't be undone.",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: AppColors.disabledMuted,
              ),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Delete material',
              onPressed: () => Navigator.of(context).pop(true),
              variant: AppButtonVariant.accent,
              height: 54,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Keep it',
              onPressed: () => Navigator.of(context).pop(false),
              variant: AppButtonVariant.outlinedNeutral,
              height: 52,
            ),
          ],
        ),
      ),
    );
  }
}
