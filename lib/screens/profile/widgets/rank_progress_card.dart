import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/rank.dart';
import '../profile_styles.dart';
import 'profile_header.dart';

/// The card under the summary pair: the current rank's name and colour, a
/// progress bar through that rank, how many points remain to the next one,
/// and a link to the Ranks screen.
///
/// Everything is derived from [points] through `rankForPoints` — the stored
/// `Student.currentRank` is deliberately not read (see `lib/utils/rank.dart`).
class RankProgressCard extends StatelessWidget {
  const RankProgressCard({
    super.key,
    required this.points,
    required this.onViewRanks,
  });

  /// The student's total points; null while the document is loading.
  final int? points;

  final VoidCallback onViewRanks;

  @override
  Widget build(BuildContext context) {
    final rank = rankForPoints(points);
    final next = nextRankAfter(rank);
    final remaining = pointsToNextRank(points);

    return ProfileCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: rank.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  rank.name,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileText.rankName,
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: onViewRanks,
                  behavior: HitTestBehavior.opaque,
                  child: Text('View Ranks', style: ProfileText.viewRanks),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressWithinRank(points),
              minHeight: 9,
              backgroundColor: AppColors.cardTint,
              valueColor: AlwaysStoppedAnimation<Color>(rank.color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  // "550 pts to Advanced" or, at the top, no next rank.
                  remaining == null || next == null
                      ? 'Highest rank reached'
                      : '${formatPoints(remaining)} pts to ${next.shortName}',
                  overflow: TextOverflow.ellipsis,
                  style: ProfileText.rankToNext,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  rank.isTop
                      ? '${formatPoints(points)} pts · top rank'
                      : '${formatPoints(points)} / '
                            '${formatPoints(rank.maxPoints)} pts',
                  overflow: TextOverflow.ellipsis,
                  style: ProfileText.rankProgress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
