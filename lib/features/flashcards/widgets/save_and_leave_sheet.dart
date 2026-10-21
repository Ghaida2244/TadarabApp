import 'package:flutter/material.dart';

import '../../../widgets/save_and_leave_sheet.dart';

/// Shows the shared "Leave this session?" sheet
/// (lib/widgets/save_and_leave_sheet.dart) for the Flashcards Flip Deck.
///
/// The sheet widget itself now lives in that shared file — identical to
/// Quiz's own leave sheet (title/body/typography/spacing/button sizes),
/// so the two can't visually drift apart again (they previously had, with
/// this screen's title/body rendering several points larger than Quiz's).
/// This function only supplies the Flashcards-specific progress wording
/// and preserves this screen's original behavior: "Save and leave" closes
/// the sheet itself before calling [onSaveAndLeave] (the shared widget's
/// buttons don't pop on their own — that's left to each caller).
Future<void> showSaveAndLeaveSheet(
  BuildContext context, {
  required int reviewedCount,
  required int total,
  required VoidCallback onSaveAndLeave,
}) {
  return showSaveAndLeaveSheetModal<void>(
    context,
    body: 'You have marked $reviewedCount of $total so far. We will keep '
        'this session so you can pick it up where you left off.',
    onSaveAndLeave: () {
      Navigator.of(context).pop();
      onSaveAndLeave();
    },
    onKeepGoing: () => Navigator.of(context).pop(),
  );
}
