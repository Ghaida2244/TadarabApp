import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';


/// Copy and colours for the "lively" Learning Guide, transcribed verbatim
/// from the Profile design handoff's `GUIDE` constant.
///
/// The handoff ships two variants of this screen and its own prop default
/// — and its code fallback — both say **lively**, so that is the one built.
/// The "classic" variant would render it with the same block layout as the
/// other three About documents.
/// A "how to earn points" tile.
class GuidePointsTile {
  const GuidePointsTile({
    required this.label,
    required this.points,
    required this.unit,
    required this.color,
    required this.tint,
    required this.icon,
  });

  /// "Quiz" / "Flashcards".
  final String label;

  /// "+4" / "+2".
  final String points;

  /// "per correct answer" / "per card marked Known".
  final String unit;

  final Color color;
  final Color tint;
  final IconData icon;
}

/// An explainer card lower down the guide.
class GuideItem {
  const GuideItem({
    required this.heading,
    required this.body,
    required this.color,
    required this.tint,
    required this.icon,
    this.scope,
  });

  final String heading;
  final String body;
  final Color color;
  final Color tint;
  final IconData icon;

  /// The chip beside the heading, e.g. "LEARNING MODE"; null when the item
  /// applies everywhere.
  final String? scope;
}

/// The eyebrow above the points tiles.
const kGuideEarnHeading = 'HOW TO EARN POINTS';

/// The two point values, which match the code that actually awards them
/// (`pointsPerCorrectAnswer` = 4 and `kPointsPerKnownFlashcard` = 2).
const kGuidePointsTiles = [
  GuidePointsTile(
    label: 'Quiz',
    points: '+4',
    unit: 'per correct answer',
    color: AppColors.red,
    tint: AppColors.errorBannerBackground,
    icon: Icons.help_outline,
  ),
  GuidePointsTile(
    label: 'Flashcards',
    points: '+2',
    unit: 'per card marked Known',
    color: AppColors.navy,
    tint: AppColors.cardTint,
    icon: Icons.collections_bookmark_outlined,
  ),
];

/// The "Rank Progress" card's heading and line.
const kGuideRankHeading = 'Rank Progress';
const kGuideRankBody =
    'Points move you through 10 ranks. Nothing else affects it.';

/// The five explainer cards, in the design's order.
const kGuideItems = [
  GuideItem(
    heading: 'Retake',
    body:
        'Redoes the session with the same settings but new questions.\n'
        'Replaces your old results completely (correct, wrong, and points).',
    color: Color(0xFF2563EB),
    tint: Color(0xFFE8F0FE),
    icon: Icons.refresh,
  ),
  GuideItem(
    heading: 'Practice Now',
    scope: 'LEARNING MODE',
    body:
        'Gathers every question you got wrong into one session. Solve them '
        'again at your own pace, with no points, and come back anytime.',
    color: AppColors.pointsBadgeDot,
    tint: AppColors.warningBackground,
    icon: Icons.play_arrow,
  ),
  GuideItem(
    heading: 'Review Mistakes',
    scope: 'EXAM MODE',
    body:
        'Look back at the questions you got wrong. View-only (not re-solving '
        'them), and you can revisit it anytime.',
    color: Color(0xFF0891B2),
    tint: Color(0xFFE0F5FA),
    icon: Icons.visibility_outlined,
  ),
  GuideItem(
    heading: 'Review Now',
    scope: 'FLASHCARDS',
    body:
        'Goes through only the cards marked "Needs Review," with '
        'Next/Previous to move at your pace.',
    color: Color(0xFF7C3AED),
    tint: Color(0xFFF1EAFE),
    icon: Icons.collections_bookmark_outlined,
  ),
  GuideItem(
    heading: 'Streak',
    body:
        'Finish one full session (quiz or flashcards) each day to keep your '
        'streak alive.',
    color: AppColors.red,
    tint: AppColors.errorBannerBackground,
    icon: Icons.local_fire_department,
  ),
];
