import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The circular "←" chip used to leave Create Account / Forgot Password.
/// Dims (per the mockup's loading frames) when [enabled] is false, so it
/// can't be tapped away from mid-submit.
class BackButtonChip extends StatelessWidget {
  const BackButtonChip({super.key, required this.onTap, this.enabled = true});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: AppDimens.backButtonSize,
        height: AppDimens.backButtonSize,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.chipBackground,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_back,
          size: 20,
          color: enabled ? AppColors.navy : AppColors.textOnDisabled,
        ),
      ),
    );
  }
}
