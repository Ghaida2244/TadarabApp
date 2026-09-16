import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';

/// Frame 1's "new student" onboarding prompt — shown instead of
/// [ContinueOrStartCard] when the student has zero courses. Only the
/// zero-courses state is built here; Frame 1's other two sub-states
/// ("course just created, now upload material" and "AI reading your
/// material") depend on the course-creation/upload flow itself, which is
/// Phase C — not built.
class NewStudentOnboardingCard extends StatelessWidget {
  const NewStudentOnboardingCard({
    super.key,
    required this.onCreateFirstCourse,
  });

  final VoidCallback onCreateFirstCourse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(color: AppColors.navyShadow, offset: Offset(0, 5)),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -26,
                top: -26,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      "Let's get you set up",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: const Text(
                      'Turn your lectures into quizzes.',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.02 * 27,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    // The mockup's <p> has no explicit font-weight, so it's
                    // Nunito's default (400) — not AppTypography.subtitle's
                    // baked-in 700, which is only correct for auth screens.
                    child: Text(
                      'Add a course, drop in your slides, and study from questions written on your own material.',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.55,
                        color: Colors.white,
                      ).copyWith(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _OnboardingStep(
          number: 1,
          title: 'Create a course',
          subtitle: 'Takes about ten seconds',
          active: true,
        ),
        const SizedBox(height: 10),
        _OnboardingStep(
          number: 2,
          title: 'Upload your material',
          subtitle: 'PPTX, DOCX or TXT',
          active: false,
        ),
        const SizedBox(height: 10),
        _OnboardingStep(
          number: 3,
          title: 'Start studying',
          subtitle: 'Quiz or flashcards, your call',
          active: false,
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Create my first course',
          variant: AppButtonVariant.accent,
          height: 58,
          borderRadius: 18,
          onPressed: onCreateFirstCourse,
        ),
      ],
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.active,
  });

  final int number;
  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: active ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.08),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.red : AppColors.cardTint,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : AppColors.navy,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.fieldLabel.copyWith(fontSize: 16),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.subtitle.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
