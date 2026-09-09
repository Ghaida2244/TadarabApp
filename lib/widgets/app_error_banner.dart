import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The red "something went wrong" banner shown on Login (wrong credentials)
/// and Create Account (email already registered). [actions], if given, are
/// rendered as underlined inline links below the body (e.g. "Log in
/// instead" / "Reset password").
class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({
    super.key,
    required this.heading,
    required this.body,
    this.actions,
  });

  final String heading;
  final String body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.errorBannerBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.errorBannerBorder, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.error_outline,
                size: 19,
                color: AppColors.errorText,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(heading, style: AppTypography.bannerHeading),
                  const SizedBox(height: 3),
                  Text(body, style: AppTypography.bannerBody),
                  if (actions != null) ...[
                    const SizedBox(height: 2),
                    Row(children: actions!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
