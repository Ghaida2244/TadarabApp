import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/confirm_dialog.dart';

/// The confirmation body, as the design words it.
const kLogOutTitle = 'Log out of Tadarab?';
const kLogOutBody =
    'Your courses, points and sessions stay safe. You will just need to '
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
Future<bool> showLogOutDialog(BuildContext context) {
  return showConfirmDialog(
    context,
    title: kLogOutTitle,
    message: kLogOutBody,
    confirmLabel: 'Log out',
    cancelLabel: 'Stay signed in',
    icon: Icons.logout,
    iconColor: AppColors.red,
    iconBackgroundColor: AppColors.errorBannerBackground,
  );
}
