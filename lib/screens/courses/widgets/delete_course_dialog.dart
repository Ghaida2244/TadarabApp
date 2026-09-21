import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';

/// The "Delete [course name]?" confirmation dialog, opened only from the
/// trash icon inside Course Detail (courses_material_upload_spec.md §3).
/// Returns `true` if the student confirmed deletion, `false`/null if they
/// backed out.
Future<bool> showDeleteCourseDialog({
  required BuildContext context,
  required String courseName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _DeleteCourseDialog(courseName: courseName),
  );
  return result ?? false;
}

class _DeleteCourseDialog extends StatelessWidget {
  const _DeleteCourseDialog({required this.courseName});

  final String courseName;

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
              'Delete $courseName?',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Deleting this course will also delete all its materials, '
              "quizzes, and flashcard sessions. This can't be undone.",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: AppColors.disabledMuted,
              ),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Delete course',
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
