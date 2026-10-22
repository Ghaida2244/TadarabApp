import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../profile_styles.dart';

/// The confirmation body, as the design words it.
const kLogOutTitle = 'Log out of Tadarab?';
const kLogOutBody =
    'Your courses, points and sessions stay safe — you will just need to '
    'sign in again.';

/// Asks the student to confirm before logging out.
///
/// **A team decision that departs from the SRS**, whose
/// `Profile Page Log Out Option.png` logs out immediately with no dialog.
/// The unified design adds this confirm and its own notes call for it;
/// recorded in CLAUDE.md.
///
/// Resolves to true only when the student confirms — cancelling or
/// dismissing by tapping outside both resolve to false, so a caller can
/// treat anything but true as "stay signed in".
Future<bool> showLogOutDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.navy.withValues(alpha: 0.5),
    builder: (context) => const _LogOutDialog(),
  );
  return confirmed ?? false;
}

class _LogOutDialog extends StatelessWidget {
  const _LogOutDialog();

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
                color: AppColors.errorBannerBackground,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.logout,
                size: 24,
                color: AppColors.red,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              kLogOutTitle,
              textAlign: TextAlign.center,
              style: ProfileText.docHeading.copyWith(fontSize: 19),
            ),
            const SizedBox(height: 13),
            Text(
              kLogOutBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 13),
            AppButton(
              label: 'Log out',
              variant: AppButtonVariant.accent,
              height: 52,
              borderRadius: 16,
              fontSize: 15,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 13),
            AppButton(
              label: 'Stay signed in',
              variant: AppButtonVariant.outlinedNeutral,
              height: 46,
              borderRadius: 16,
              borderColor: AppColors.borderDefault,
              fontSize: 14,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
