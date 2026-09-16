import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visual treatment of an [AppButton]. Matches the three button looks used
/// across the auth screens: solid navy (primary actions), solid red (the
/// Forgot Password screen's primary action), navy-outlined (secondary
/// actions with their own shadow, e.g. "Create Account" on Welcome), and
/// grey-outlined with no shadow (e.g. "Resend link").
enum AppButtonVariant { primary, accent, outlinedBrand, outlinedNeutral }

/// A button with the design's hard-offset shadow that flattens on press
/// (translateY + shrinking shadow), plus a built-in loading state so every
/// screen shows the same "in flight" look instead of each reinventing one.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.loadingLabel,
    this.height,
    this.borderRadius,
    this.borderColor,
    this.shadowColor,
  });

  final String label;

  /// Null (rather than a callback) disables the button — used for the
  /// loading state and can also be used for "submit disabled until valid".
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;

  /// Label shown while [loading] is true, e.g. "Signing in…". Defaults to [label].
  final String? loadingLabel;

  /// Overrides the variant's default height. Button height isn't fixed per
  /// variant across the app — the same [AppButtonVariant.accent] is 56px on
  /// auth screens but 52px (Resume, New quiz) or 58px (Create my first
  /// course) on Home — so callers set the exact mockup value explicitly.
  final double? height;

  /// Overrides the default 16px corner radius (e.g. Home's "Create my
  /// first course" is 18px).
  final double? borderRadius;

  /// Overrides the variant's default border color (outlined variants only).
  final Color? borderColor;

  /// Overrides the variant's default shadow color.
  final Color? shadowColor;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final bool outlined =
        widget.variant == AppButtonVariant.outlinedBrand ||
        widget.variant == AppButtonVariant.outlinedNeutral;
    final double height =
        widget.height ??
        (outlined && widget.variant == AppButtonVariant.outlinedNeutral
            ? AppDimens.secondaryButtonHeight
            : AppDimens.buttonHeight);

    var colors = _colorsFor(widget.variant, loading: widget.loading);
    if (widget.borderColor != null) {
      colors = colors.copyWithBorder(widget.borderColor);
    }
    if (widget.shadowColor != null) {
      colors = colors.copyWithShadow(widget.shadowColor);
    }
    final double shadowOffset = colors.hasShadow ? (_pressed ? 1 : 3) : 0;

    return GestureDetector(
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      onTap: _enabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          0,
          colors.hasShadow && _pressed ? 4 : 0,
          0,
        ),
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(
            widget.borderRadius ?? AppRadius.lg,
          ),
          border: colors.border != null
              ? Border.all(color: colors.border!, width: 2)
              : null,
          boxShadow: colors.hasShadow
              ? [
                  BoxShadow(
                    color: colors.shadow!,
                    offset: Offset(0, shadowOffset),
                  ),
                ]
              : null,
        ),
        child: Center(child: _buildContent(colors)),
      ),
    );
  }

  Widget _buildContent(_ButtonColors colors) {
    if (widget.loading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              backgroundColor: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(width: 11),
          Text(
            widget.loadingLabel ?? widget.label,
            style: AppTypography.button,
          ),
        ],
      );
    }
    final style =
        widget.variant == AppButtonVariant.outlinedBrand ||
            widget.variant == AppButtonVariant.outlinedNeutral
        ? AppTypography.buttonSecondary.copyWith(color: colors.text)
        : AppTypography.button.copyWith(color: colors.text);
    return Text(widget.label, style: style);
  }

  _ButtonColors _colorsFor(AppButtonVariant variant, {required bool loading}) {
    if (loading) {
      return _ButtonColors(
        background: AppColors.disabledMuted,
        shadow: AppColors.disabledShadow,
        text: Colors.white,
      );
    }
    switch (variant) {
      case AppButtonVariant.primary:
        return _ButtonColors(
          background: AppColors.navy,
          shadow: AppColors.navyShadow,
          text: Colors.white,
        );
      case AppButtonVariant.accent:
        return _ButtonColors(
          background: AppColors.red,
          shadow: AppColors.redShadow,
          text: Colors.white,
        );
      case AppButtonVariant.outlinedBrand:
        // #0B0F5B80 in the mockup — navy at ~50% alpha (hex 0x80/0xFF), not opaque.
        return _ButtonColors(
          background: Colors.white,
          border: AppColors.navy,
          shadow: AppColors.navy.withValues(alpha: 0x80 / 0xFF),
          text: AppColors.navy,
        );
      case AppButtonVariant.outlinedNeutral:
        return _ButtonColors(
          background: Colors.white,
          border: AppColors.borderDefault,
          text: AppColors.textSecondary,
        );
    }
  }
}

class _ButtonColors {
  _ButtonColors({
    required this.background,
    this.border,
    this.shadow,
    required this.text,
  });

  final Color background;
  final Color? border;
  final Color? shadow;
  final Color text;

  bool get hasShadow => shadow != null;

  _ButtonColors copyWithBorder(Color? border) => _ButtonColors(
    background: background,
    border: border,
    shadow: shadow,
    text: text,
  );

  _ButtonColors copyWithShadow(Color? shadow) => _ButtonColors(
    background: background,
    border: border,
    shadow: shadow,
    text: text,
  );
}
