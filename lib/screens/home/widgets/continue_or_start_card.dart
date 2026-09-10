import 'package:flutter/material.dart';

import '../../../services/home_data_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';

/// The card below Today's Progress: resumes an incomplete session if one
/// exists, otherwise offers to start a new quiz or flashcard set.
///
/// [inProgress] is always null in the running app today — nothing creates a
/// session until Phase C's Quiz/Flashcard generation exists — but the
/// resume path is fully built (not skipped) so that feature can wire
/// straight into it, and it's covered by widget tests with injected fake
/// data even though it's currently unreachable for real.
class ContinueOrStartCard extends StatelessWidget {
  const ContinueOrStartCard({
    super.key,
    required this.inProgress,
    required this.onResume,
    required this.onNewQuiz,
    required this.onFlashcards,
  });

  final InProgressSession? inProgress;
  final VoidCallback onResume;
  final VoidCallback onNewQuiz;
  final VoidCallback onFlashcards;

  @override
  Widget build(BuildContext context) {
    final session = inProgress;
    if (session != null) {
      final kindLabel = session.kind == SessionKind.quiz
          ? 'Quiz'
          : 'Flashcards';
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.errorBannerBackground,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withValues(alpha: 0.18),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pick up where you left off',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.errorBannerBody,
                  ),
                ),
                Text(
                  '${session.currentIndex}/${session.total}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.errorBannerBody,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${session.courseName} — $kindLabel',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.2,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: session.total == 0
                    ? 0
                    : session.currentIndex / session.total,
                backgroundColor: AppColors.red.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(AppColors.red),
              ),
            ),
            const SizedBox(height: 14),
            AppButton(
              label: 'Resume',
              variant: AppButtonVariant.accent,
              height: 52,
              onPressed: onResume,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nothing in progress',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new session',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.25,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'New quiz',
                  variant: AppButtonVariant.accent,
                  height: 52,
                  onPressed: onNewQuiz,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Flashcards',
                  variant: AppButtonVariant.outlinedBrand,
                  height: 52,
                  borderColor: AppColors.borderLight,
                  shadowColor: AppColors.navy.withValues(alpha: 0.1),
                  onPressed: onFlashcards,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
