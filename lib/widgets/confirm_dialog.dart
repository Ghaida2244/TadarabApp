import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';

/// The shared confirmation dialog used across the app — a centered, white
/// rounded dialog with a tinted icon badge, a bold navy title, a grey-blue
/// body, a primary action and an active-looking secondary action. Dialog
/// size, padding, radius, spacing, and the title/body/secondary-button
/// styles are fixed here so every caller stays visually identical on those;
/// only the icon and the primary button's style are overridable, for
/// callers like the "fewer than asked" limit dialogs or Log out that aren't
/// delete confirmations.
///
/// Defaults (icon, icon colours, primary button style) match the
/// delete-confirmation look this was first built for — colours/layout
/// follow the Calendar "Delete this event?" dialog; the exact spacing
/// values are taken from the flashcard sessions screen's original delete
/// dialog.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Keep it',
    this.icon = Icons.delete_outline,
    this.iconColor = AppColors.red,
    this.iconBackgroundColor = AppColors.errorBannerBackground,
    this.confirmVariant = AppButtonVariant.accent,
    this.confirmShadowColor,
  });

  /// e.g. "Delete IS463?" / "Delete this event?" / "Log out of Tadarab?".
  final String title;

  /// e.g. "This can't be undone." / "Fewer cards than asked"'s body.
  final String message;

  /// e.g. "Delete course" / "Log out" / "Start with these".
  final String confirmLabel;

  /// The secondary, non-destructive action's label.
  final String cancelLabel;

  /// The icon badge's glyph.
  final IconData icon;

  /// The icon badge's glyph colour.
  final Color iconColor;

  /// The icon badge's rounded-square background colour.
  final Color iconBackgroundColor;

  /// The primary (confirm) button's [AppButton] variant.
  final AppButtonVariant confirmVariant;

  /// Overrides the primary button's shadow. When left null, an
  /// [AppButtonVariant.accent] button falls back to the delete dialogs'
  /// own lighter red shadow (half the strength of the variant's normal
  /// one); any other variant falls back to [AppButton]'s own default for
  /// that variant.
  final Color? confirmShadowColor;

  static const _titleStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 19,
    fontWeight: FontWeight.w900,
    color: AppColors.navy,
  );

  static const _bodyStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(height: 13),
            Text(title, textAlign: TextAlign.center, style: _titleStyle),
            const SizedBox(height: 13),
            Text(message, textAlign: TextAlign.center, style: _bodyStyle),
            const SizedBox(height: 18),
            AppButton(
              label: confirmLabel,
              variant: confirmVariant,
              height: 52,
              // Half the strength of AppButtonVariant.accent's own default
              // shadow (AppColors.redShadow, fully opaque) — a soft shadow,
              // not a hard dark edge. Only applied when the caller hasn't
              // chosen its own shadow and is using the red accent look.
              shadowColor: confirmShadowColor ??
                  (confirmVariant == AppButtonVariant.accent
                      ? AppColors.redShadow.withValues(alpha: 0.5)
                      : null),
              onPressed: () => Navigator.of(context).pop(true),
            ),
            SizedBox(height: AppSpacing.sm),
            AppButton(
              label: cancelLabel,
              variant: AppButtonVariant.outlinedNeutral,
              height: 46,
              // Exactly the enabled "Previous" button look.
              activeBorderColor: AppColors.navy.withValues(alpha: 0.32),
              activeTextColor: AppColors.navy,
              activeShadowColor: AppColors.navy.withValues(alpha: 0.10),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [ConfirmDialog] and resolves to `true` only when the student taps
/// the confirm button — `false` on the secondary button, the back gesture,
/// or (when [barrierDismissible] is true, the default) tapping outside —
/// so callers never need a null check.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Keep it',
  IconData icon = Icons.delete_outline,
  Color iconColor = AppColors.red,
  Color iconBackgroundColor = AppColors.errorBannerBackground,
  AppButtonVariant confirmVariant = AppButtonVariant.accent,
  Color? confirmShadowColor,
  bool barrierDismissible = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      iconColor: iconColor,
      iconBackgroundColor: iconBackgroundColor,
      confirmVariant: confirmVariant,
      confirmShadowColor: confirmShadowColor,
    ),
  );
  return confirmed ?? false;
}
