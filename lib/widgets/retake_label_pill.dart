import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The "ORIGINAL" / "RETAKE N" pill shown on a session card — shared by
/// Quiz and Flashcards so the two can't drift apart. Per the Retake
/// Stacks hand-off's LABEL spec row: uppercase, 10sp/w900, tracking
/// .04em, navy #0B0F5B fill, white text, pill radius 999, padding 4 × 9.
/// Sits before the mode tag (Quiz) or the status row (Flashcards, which
/// has no mode tag).
///
/// [label] is whatever [sessionCardRetakeLabel]
/// (lib/models/session.dart) returns — "Original" or "Retake N" — the
/// label TEXT/logic is unchanged by this widget; only the rendering
/// (a filled pill, instead of plain grey text) is new.
class RetakeLabelPill extends StatelessWidget {
  const RetakeLabelPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.04 * 10,
          color: Colors.white,
        ),
      ),
    );
  }
}
