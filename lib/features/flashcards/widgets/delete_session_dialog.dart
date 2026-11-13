import 'package:flutter/material.dart';

import '../../../widgets/confirm_dialog.dart';
import '../logic/flashcard_logic.dart';

/// Shows the shared delete-confirmation dialog for a flashcard session.
/// Body text differs for a completed vs. an in-progress session — see
/// [deleteSessionBody]. Calls [onDelete] only when the student confirms.
Future<void> showDeleteSessionDialog(
  BuildContext context, {
  required bool isCompleted,
  required int knownCount,
  required int needsReviewCount,
  required VoidCallback onDelete,
}) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Delete this session?',
    message: deleteSessionBody(
      isCompleted: isCompleted,
      knownCount: knownCount,
      needsReviewCount: needsReviewCount,
    ),
    confirmLabel: 'Delete session',
  );
  if (confirmed) onDelete();
}
