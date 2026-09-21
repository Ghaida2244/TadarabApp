import 'package:flutter/material.dart';

import '../../../models/enums.dart';
import '../../../theme/app_theme.dart';

/// Colors from the design handoff's `pips` mapping in
/// `Tadarab Phase 2b - Flashcards.dc.html` — rendered against the navy
/// header, so "untouched"/"needs review" are translucent white, not opaque
/// greys. Not in `AppColors` (Flashcards-only, avoids touching the shared
/// frozen theme file).
const _kPipKnown = Color(0xFF7BE0A0);
const _kPipNeedsReview = Color(0xBFFFFFFF); // white @ 75% alpha
const _kPipUntouched = Color(0x38FFFFFF); // white @ 22% alpha

/// One pip per card, shown against the navy header on both the Flip Deck
/// and the Review Pass (same component, reused, per the design handoff):
/// red/filled for the current card, green for "I know it", translucent
/// white for "Need review", faint translucent white for not yet reached.
class ProgressPips extends StatelessWidget {
  const ProgressPips({
    super.key,
    required this.total,
    required this.currentIndex,
    required this.statuses,
  });

  final int total;
  final int currentIndex;

  /// One entry per card, in deck order; null means not yet rated.
  final List<ReviewStatus?> statuses;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              key: ValueKey('pip-$i'),
              height: 6,
              decoration: BoxDecoration(
                color: _colorFor(i),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _colorFor(int index) {
    if (index == currentIndex) return AppColors.red;
    final status = index < statuses.length ? statuses[index] : null;
    if (status == ReviewStatus.knowIt) return _kPipKnown;
    if (status == ReviewStatus.needsReview) return _kPipNeedsReview;
    return _kPipUntouched;
  }
}
