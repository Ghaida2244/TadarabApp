import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/confirm_dialog.dart';

/// Shows the shared confirmation dialog when generation returned fewer
/// cards than requested, before the first card is shown. Not dismissible
/// by tapping outside — the student must pick one of the two options.
Future<void> showFewerCardsDialog(
  BuildContext context, {
  required int actualCount,
  required int requestedCount,
  required VoidCallback onStartWithActual,
  required VoidCallback onChangeSetup,
}) => _showCountMismatchDialog(
  context,
  title: 'Fewer cards than asked',
  message:
      'Your material supported $actualCount solid cards out of the '
      '$requestedCount you aimed for. Start with these $actualCount, '
      'or add another material.',
  actualCount: actualCount,
  onStartWithActual: onStartWithActual,
  onChangeSetup: onChangeSetup,
);

/// Shows the shared confirmation dialog when generation returned more
/// cards than requested, before the first card is shown. Not dismissible
/// by tapping outside — the student must pick one of the two options.
Future<void> showMoreCardsDialog(
  BuildContext context, {
  required int actualCount,
  required int requestedCount,
  required VoidCallback onStartWithActual,
  required VoidCallback onChangeSetup,
}) => _showCountMismatchDialog(
  context,
  title: 'More cards than asked',
  message:
      'Your material supported $actualCount solid cards, more than the '
      '$requestedCount you aimed for. Start with these $actualCount, '
      'or change the setup.',
  actualCount: actualCount,
  onStartWithActual: onStartWithActual,
  onChangeSetup: onChangeSetup,
);

/// Shared confirm/cancel plumbing for [showFewerCardsDialog] and
/// [showMoreCardsDialog] — only the title and message differ between them.
Future<void> _showCountMismatchDialog(
  BuildContext context, {
  required String title,
  required String message,
  required int actualCount,
  required VoidCallback onStartWithActual,
  required VoidCallback onChangeSetup,
}) async {
  final startWithActual = await showConfirmDialog(
    context,
    title: title,
    message: message,
    confirmLabel: 'Start with these $actualCount',
    cancelLabel: 'Change the setup',
    icon: Icons.warning_amber_rounded,
    iconColor: AppColors.warningText,
    iconBackgroundColor: AppColors.warningBackground,
    confirmVariant: AppButtonVariant.primary,
    confirmShadowColor: AppColors.navyShadow.withValues(alpha: 0.6),
    barrierDismissible: false,
  );
  if (startWithActual) {
    onStartWithActual();
  } else {
    onChangeSetup();
  }
}
