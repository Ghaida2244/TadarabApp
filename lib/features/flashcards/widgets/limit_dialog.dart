import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';

/// Shown on the Setup screen when generation returned fewer cards than
/// requested, before the first card is shown.
class FewerCardsDialog extends StatelessWidget {
  const FewerCardsDialog({
    super.key,
    required this.actualCount,
    required this.requestedCount,
    required this.onStartWithActual,
    required this.onChangeSetup,
  });

  final int actualCount;
  final int requestedCount;
  final VoidCallback onStartWithActual;
  final VoidCallback onChangeSetup;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      insetPadding: const EdgeInsets.all(26),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.warningBackground,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.warning_amber_rounded, size: 25, color: AppColors.warningText),
              ),
            ),
            const SizedBox(height: 13),
            Text(
              'Fewer cards than asked',
              textAlign: TextAlign.center,
              style: AppTypography.screenTitleCompact.copyWith(fontSize: 19),
            ),
            const SizedBox(height: 13),
            Text(
              'Your material supported $actualCount solid cards out of the '
              '$requestedCount you aimed for. Start with these $actualCount, '
              'or add another material.',
              textAlign: TextAlign.center,
              style: AppTypography.subtitle.copyWith(height: 1.6),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Start with these $actualCount',
              variant: AppButtonVariant.primary,
              height: 52,
              shadowColor: AppColors.navyShadow.withValues(alpha: 0.6),
              onPressed: () {
                Navigator.of(context).pop();
                onStartWithActual();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Change the setup',
              variant: AppButtonVariant.outlinedNeutral,
              height: 46,
              onPressed: () {
                Navigator.of(context).pop();
                onChangeSetup();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [FewerCardsDialog].
Future<void> showFewerCardsDialog(
  BuildContext context, {
  required int actualCount,
  required int requestedCount,
  required VoidCallback onStartWithActual,
  required VoidCallback onChangeSetup,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => FewerCardsDialog(
      actualCount: actualCount,
      requestedCount: requestedCount,
      onStartWithActual: onStartWithActual,
      onChangeSetup: onChangeSetup,
    ),
  );
}
