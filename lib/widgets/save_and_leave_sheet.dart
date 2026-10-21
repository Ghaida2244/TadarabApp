import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';

/// The "Leave this session?" confirmation sheet shown when a student exits
/// mid-session — used by both Quiz (quiz_play_screen.dart) and Flashcards
/// (flashcard_flip_deck_screen.dart, via its own showSaveAndLeaveSheet
/// wrapper). Quiz's own version was the source of truth for this shared
/// widget's appearance — Flashcards' copy had drifted to larger
/// title/body font sizes (26/w900 and 14/w700 instead of 19/w900 and
/// 13/w700) before this was extracted.
///
/// Only [body] and the two callbacks vary per caller; title, colors,
/// spacing and button sizes are fixed here so the two screens can't drift
/// apart again. Neither button pops its own sheet — that's each caller's
/// job via its own callback, exactly as Quiz's original did (Flashcards'
/// original popped internally before calling back; its wrapper now does
/// that itself, see flashcard_performance_summary_screen's sibling file).
class SaveAndLeaveSheet extends StatelessWidget {
  const SaveAndLeaveSheet({
    super.key,
    required this.body,
    required this.onSaveAndLeave,
    required this.onKeepGoing,
  });

  /// The progress line shown under the title, e.g. "You have answered 3
  /// of 10 so far. We will keep this session so you can pick it up where
  /// you left off."
  final String body;
  final VoidCallback onSaveAndLeave;
  final VoidCallback onKeepGoing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text('Leave this session?', style: AppTypography.quizDialogTitle),
          const SizedBox(height: 8),
          Text(body, style: AppTypography.quizEmptyBody),
          const SizedBox(height: 16),
          AppButton(
            label: 'Save and leave',
            onPressed: onSaveAndLeave,
            height: 52,
            shadowColor: AppColors.navy.withValues(alpha: 0.10),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Keep going',
            variant: AppButtonVariant.outlinedNeutral,
            height: 48,
            onPressed: onKeepGoing,
          ),
        ],
      ),
    );
  }
}

/// Shows [SaveAndLeaveSheet] as a modal bottom sheet, transparent-backed so
/// the widget's own white rounded-top [Container] is the only background
/// drawn (matches Quiz's original call exactly, rather than letting the
/// modal itself also paint a white/rounded background behind it).
Future<T?> showSaveAndLeaveSheetModal<T>(
  BuildContext context, {
  required String body,
  required VoidCallback onSaveAndLeave,
  required VoidCallback onKeepGoing,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SaveAndLeaveSheet(
      body: body,
      onSaveAndLeave: onSaveAndLeave,
      onKeepGoing: onKeepGoing,
    ),
  );
}
