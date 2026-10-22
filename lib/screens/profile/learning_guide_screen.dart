import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/rank.dart';
import 'content/learning_guide_content.dart';
import 'profile_styles.dart';
import 'widgets/profile_header.dart';

/// The Learning Guide: how points are earned, how ranks follow from them,
/// and what each practice mode does.
///
/// This is the design's **"lively"** variant — its own prop default and its
/// code fallback both specify it, over the plainer "classic" block layout
/// the other three About documents use.
///
/// [points] drives the rank ladder's highlight. It is optional because the
/// guide is readable without it; when absent the ladder shows no progress.
class LearningGuideScreen extends StatelessWidget {
  const LearningGuideScreen({super.key, this.points});

  final int? points;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const ProfileSubHeader(title: 'Learning Guide'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kGuideEarnHeading, style: ProfileText.guideEyebrow),
                  const SizedBox(height: 10),
                  // Same reason as the Profile summary pair: `stretch`
                  // needs a bounded height, and this row scrolls.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final tile in kGuidePointsTiles) ...[
                          Expanded(child: _PointsTile(tile: tile)),
                          if (tile != kGuidePointsTiles.last)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _RankLadderCard(points: points),
                  const SizedBox(height: 18),
                  for (final item in kGuideItems) ...[
                    _GuideItemCard(item: item),
                    if (item != kGuideItems.last) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One "+4 pts / Quiz / per correct answer" tile.
class _PointsTile extends StatelessWidget {
  const _PointsTile({required this.tile});

  final GuidePointsTile tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
      decoration: BoxDecoration(
        color: tile.tint,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(tile.icon, size: 18, color: tile.color),
          ),
          const SizedBox(height: 9),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  tile.points,
                  style: ProfileText.guideTileValue(tile.color),
                ),
                const SizedBox(width: 4),
                Text('pts', style: ProfileText.guideTileUnit(tile.color)),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(tile.label, style: ProfileText.guideTileLabel),
          const SizedBox(height: 1),
          Text(tile.unit, style: ProfileText.guideTileUnitLabel),
        ],
      ),
    );
  }
}

/// The "Rank Progress" card and its ten-rung ladder.
class _RankLadderCard extends StatelessWidget {
  const _RankLadderCard({required this.points});

  final int? points;

  @override
  Widget build(BuildContext context) {
    final current = rankForPoints(points);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardTint, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.successBackgroundStrong,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.trending_up,
                  size: 19,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kGuideRankHeading, style: ProfileText.guideHeading),
                    const SizedBox(height: 3),
                    Text(kGuideRankBody, style: ProfileText.guideBody),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          // Ten rungs of increasing height; those up to and including the
          // current rank are coloured, the rest are empty.
          SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final rank in kRanks) ...[
                  Expanded(
                    child: Container(
                      key: ValueKey('guide-rung-${rank.tier}'),
                      height: 10 + (rank.tier - 1) * 3,
                      decoration: BoxDecoration(
                        color: rank.tier <= current.tier
                            ? rank.color
                            : AppColors.cardTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  if (rank.tier != kRanks.length) const SizedBox(width: 5),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One explainer card (Retake, Practice Now, …).
class _GuideItemCard extends StatelessWidget {
  const _GuideItemCard({required this.item});

  final GuideItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardTint, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.tint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, size: 19, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(item.heading, style: ProfileText.guideHeading),
                    if (item.scope != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(item.scope!, style: ProfileText.guideScope),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(item.body, style: ProfileText.guideBody),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
