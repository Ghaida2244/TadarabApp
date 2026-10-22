import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/rank.dart';
import 'profile_styles.dart';
import 'widgets/profile_header.dart';
import 'widgets/rank_icon.dart';

/// Whether a rank row shows the "CURRENT" pill.
///
/// The design exposes this as a prop defaulting to **false**, so the badge
/// is off: the current rank is already identifiable by its tinted card, its
/// coloured border, its "IN PROGRESS" status and its points-to-next line.
/// Kept as a constant so turning it on is a one-line change.
const bool kShowCurrentRankBadge = false;

/// The Ranks screen: all ten tiers, with the student's progress through
/// them.
///
/// Rank is derived from [points] via `rankForPoints`, not read from the
/// stored `Student.currentRank` — see `lib/utils/rank.dart`.
class RanksScreen extends StatelessWidget {
  const RanksScreen({super.key, required this.points});

  /// The student's total points.
  final int points;

  @override
  Widget build(BuildContext context) {
    final current = rankForPoints(points);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const ProfileSubHeader(title: 'Ranks'),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              itemCount: kRanks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 11),
              itemBuilder: (context, index) => _RankRow(
                rank: kRanks[index],
                points: points,
                currentTier: current.tier,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One rank's card.
class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.points,
    required this.currentTier,
  });

  final Rank rank;
  final int points;
  final int currentTier;

  @override
  Widget build(BuildContext context) {
    final isCurrent = rank.tier == currentTier;
    final isDone = rank.tier < currentTier;
    final reached = isCurrent || isDone;

    // Only the current rank shows partial progress; ranks behind it read as
    // complete and ranks ahead read as empty.
    final fraction = isDone ? 1.0 : (isCurrent ? progressWithinRank(points) : 0.0);
    final percentLabel = '${(fraction * 100).round()}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: isCurrent ? rank.color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? rank.color.withValues(alpha: 0.3)
                : AppColors.cardTint,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: reached
                      ? rank.color.withValues(alpha: 0.12)
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: rank.color.withValues(alpha: 0.2),
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
                child: RankIcon(
                  key: ValueKey('rank-icon-${rank.tier}'),
                  tier: rank.tier,
                  color: reached ? rank.color : AppColors.textOnDisabled,
                  size: 22,
                  // The design outlines a rank not yet reached and fills one
                  // the student has.
                  filled: reached,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            rank.name,
                            overflow: TextOverflow.ellipsis,
                            style: ProfileText.rankRowName(
                              reached
                                  ? AppColors.navy
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (isCurrent && kShowCurrentRankBadge) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'CURRENT',
                              style: ProfileText.rankBadge,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        // Flexible so a six-figure range can't overflow the
                        // row on a narrow screen or at a large text scale.
                        Flexible(
                          child: Text(
                            rank.rangeLabel,
                            overflow: TextOverflow.ellipsis,
                            style: ProfileText.rankRange,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.textOnDisabled,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            '${rank.tier} / ${kRanks.length}',
                            overflow: TextOverflow.ellipsis,
                            style: ProfileText.rankTier,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  isDone
                      ? 'COMPLETED'
                      : (isCurrent ? 'IN PROGRESS' : 'LOCKED'),
                  style: ProfileText.rankStatus(
                    isDone
                        ? AppColors.navy
                        : (isCurrent
                              ? ProfileColors.statusCurrent
                              : AppColors.placeholder),
                  ),
                ),
              ),
              Text(percentLabel, style: ProfileText.rankPercent),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 7,
              backgroundColor: AppColors.cardTint,
              valueColor: AlwaysStoppedAnimation<Color>(rank.color),
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(height: 10),
            Text(
              rank.isTop
                  ? 'Highest rank reached — nothing left to climb'
                  : '${formatPoints(pointsToNextRank(points))} pts until '
                        'next rank',
              style: ProfileText.rankUntilNext,
            ),
          ],
        ],
      ),
    );
  }
}
