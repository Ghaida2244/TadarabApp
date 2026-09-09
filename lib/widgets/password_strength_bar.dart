import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../validators/auth_validators.dart';

/// The three-segment Weak/Medium/Strong bar shown under the Create Account
/// password field. Purely a strength indicator — see [passwordStrength]'s
/// doc comment for why it never affects pass/fail validation.
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = passwordStrength(password);
    final int litSegments = switch (strength) {
      PasswordStrength.weak => 1,
      PasswordStrength.medium => 2,
      PasswordStrength.strong => 3,
    };
    final Color litColor = switch (strength) {
      PasswordStrength.weak => AppColors.error,
      PasswordStrength.medium => AppColors.strengthMedium,
      PasswordStrength.strong => AppColors.success,
    };
    final Color labelColor = switch (strength) {
      PasswordStrength.weak => AppColors.errorText,
      PasswordStrength.medium => AppColors.strengthMediumText,
      PasswordStrength.strong => AppColors.successDark,
    };
    final String label = switch (strength) {
      PasswordStrength.weak => 'Weak',
      PasswordStrength.medium => 'Medium',
      PasswordStrength.strong => 'Strong',
    };

    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                color: i < litSegments
                    ? litColor
                    : AppColors.strengthTrackEmpty,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.strengthLabel.copyWith(color: labelColor),
        ),
      ],
    );
  }
}
