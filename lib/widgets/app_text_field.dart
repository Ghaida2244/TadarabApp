import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visual state of an [AppTextField]. Callers compute this from their own
/// validation logic rather than the field inferring it, since "filled" vs
/// "empty" vs "invalid" means different things on different screens.
enum AppFieldState {
  /// Untouched or empty — grey border, placeholder-colored text/icon.
  empty,

  /// Has content and isn't erroring — navy border, navy text/icon.
  filled,

  /// Passed a live check (e.g. Forgot Password's email format) — green.
  success,

  /// Failed validation — red border/background, paired with [errorText].
  error,
}

/// The bordered input box used on every auth screen: label above, an icon +
/// text row, and either helper or error text below.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.leadingIcon,
    this.state = AppFieldState.empty,
    this.errorText,
    this.helperText,
    this.trailing,
    this.obscureText = false,
    this.keyboardType,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final IconData leadingIcon;
  final AppFieldState state;

  /// Shown in red with a warning icon under the field; takes priority over [helperText].
  final String? errorText;

  /// Shown in grey under the field when there's no [errorText].
  final String? helperText;

  /// e.g. the password show/hide toggle, or a "matched" checkmark.
  final Widget? trailing;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool enabled;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  Color get _borderColor {
    if (!enabled) return AppColors.borderDefault;
    switch (state) {
      case AppFieldState.empty:
        return AppColors.borderDefault;
      case AppFieldState.filled:
        return AppColors.navy;
      case AppFieldState.success:
        return AppColors.success;
      case AppFieldState.error:
        return AppColors.error;
    }
  }

  Color get _backgroundColor {
    if (!enabled) return AppColors.surfaceMuted;
    switch (state) {
      case AppFieldState.success:
        return AppColors.successBackground;
      case AppFieldState.error:
        return AppColors.errorBackground;
      case AppFieldState.empty:
      case AppFieldState.filled:
        return Colors.white;
    }
  }

  Color get _iconColor {
    if (!enabled) return AppColors.textSecondary;
    switch (state) {
      case AppFieldState.empty:
        return AppColors.placeholder;
      case AppFieldState.filled:
        return AppColors.navy;
      case AppFieldState.success:
        return AppColors.success;
      case AppFieldState.error:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.fieldLabel),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: AppDimens.fieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: _borderColor, width: 2),
          ),
          child: Row(
            children: [
              Icon(leadingIcon, size: 18, color: _iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  style: obscureText
                      ? AppTypography.fieldPassword
                      : AppTypography.fieldInput,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: AppTypography.fieldInput.copyWith(
                      color: AppColors.placeholder,
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
        if (showError || (helperText != null && helperText!.isNotEmpty)) ...[
          const SizedBox(height: AppSpacing.xs),
          if (showError)
            InlineFieldError(errorText!)
          else
            Text(helperText!, style: AppTypography.helper),
        ],
      ],
    );
  }
}

/// The red icon + text row used for field errors — extracted so screens that
/// need custom layout below a field (e.g. Create Account's password
/// strength bar sitting between the field and its error) can reuse the
/// exact same row instead of duplicating its styling.
class InlineFieldError extends StatelessWidget {
  const InlineFieldError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 15, color: AppColors.error),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: AppTypography.helper.copyWith(color: AppColors.errorText),
          ),
        ),
      ],
    );
  }
}
