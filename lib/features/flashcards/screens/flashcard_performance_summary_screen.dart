import 'package:flutter/material.dart';

import '../../../models/enums.dart';
import '../../../services/flashcard_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../logic/flashcard_logic.dart';
import 'flashcard_review_pass_screen.dart';

/// Screen 5: shown after finishing a deck (or a Retake). Reachable either
/// from completing a deck (pushReplacement over the Flip Deck) or from
/// "View performance summary" on the Sessions list — in both cases this
/// screen sits directly on top of the Sessions list in the nav stack.
/// Retake intentionally lives only on the Sessions list, not duplicated
/// here.
class FlashcardPerformanceSummaryScreen extends StatelessWidget {
  const FlashcardPerformanceSummaryScreen({
    super.key,
    required this.uid,
    required this.courseId,
    required this.sessionId,
    required this.knownCount,
    required this.needsReviewCount,
    required this.earnedPoints,
    this.service,
  });

  final String uid;
  final String courseId;
  final String sessionId;
  final int knownCount;
  final int needsReviewCount;
  final int earnedPoints;

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final FlashcardService? service;

  int get _total => knownCount + needsReviewCount;

  FlashcardService _serviceFor(BuildContext context) =>
      service ?? FlashcardService(uid: uid, courseId: courseId);

  Future<void> _reviewNow(BuildContext context) async {
    final flashcardService = _serviceFor(context);
    final flashcards = await flashcardService.fetchFlashcards(sessionId);
    final needsReview = flashcards
        .where((f) => f.reviewStatus == ReviewStatus.needsReview)
        .toList();
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardReviewPassScreen(flashcards: needsReview),
      ),
    );
  }

  void _backToCourse(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tier = performanceTierFor(knownCount: knownCount, total: _total);
    final tierInfo = _tierInfoFor(tier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const Text(
                    'Performance Summary',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.02 * 26,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_total CARDS REVIEWED',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.06 * 12,
                      color: Color(0x8CFFFFFF), // white @ 55% alpha
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle,
                          iconColor: AppColors.success,
                          iconBg: AppColors.successBackgroundStrong,
                          label: 'I know it',
                          value: '$knownCount',
                          valueColor: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.refresh,
                          iconColor: AppColors.red,
                          iconBg: AppColors.errorBannerBackground,
                          label: 'Need review',
                          value: '$needsReviewCount',
                          valueColor: AppColors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: tierInfo.background,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: tierInfo.shadow, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: Icon(tierInfo.icon, size: 24, color: tierInfo.ink),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            tierInfo.message,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1.5,
                              color: tierInfo.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.warningBackground,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Points earned',
                          style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.warningText),
                        ),
                        Text(
                          '+$earnedPoints',
                          style: const TextStyle(fontFamily: 'Nunito', fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.warningText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (needsReviewCount >= 1) ...[
                    AppButton(
                      label: 'Review now',
                      height: 56,
                      shadowColor: AppColors.navyShadow.withValues(alpha: 0.6),
                      onPressed: () => _reviewNow(context),
                    ),
                    const SizedBox(height: 11),
                  ],
                  AppButton(
                    label: 'Back to course',
                    variant: AppButtonVariant.accent,
                    height: 56,
                    shadowColor: AppColors.redShadow.withValues(alpha: 0.6),
                    onPressed: () => _backToCourse(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierInfo {
  const _TierInfo({
    required this.icon,
    required this.background,
    required this.shadow,
    required this.ink,
    required this.message,
  });

  final IconData icon;
  final Color background;
  final Color shadow;
  final Color ink;
  final String message;
}

/// Tier message copy is deliberately NOT sourced from the design handoff —
/// it comes from a separate, research-cited product decision (Bloom 1968;
/// Mueller & Dweck 1998) that takes priority over the mockup's own copy.
/// Tier background/shadow/ink colors below ARE sourced from the handoff
/// (`moodBg`/`moodShadow`/`moodInk` in `Tadarab Phase 2b -
/// Flashcards.dc.html`) — note its "developing" tier is actually a light
/// navy/lavender tint (`#EEF0FF` + navy ink), not purple; see the
/// conversation notes for why this differs from this screen's previous
/// (invented, not handoff-sourced) purple.
_TierInfo _tierInfoFor(PerformanceTier tier) {
  switch (tier) {
    case PerformanceTier.mastery:
      return const _TierInfo(
        icon: Icons.emoji_events,
        background: Color(0xFFE6F7EC),
        shadow: Color(0x3816A34A), // rgba(22,163,74,0.22)
        ink: Color(0xFF15803D),
        message: "You've mastered this.",
      );
    case PerformanceTier.developing:
      return const _TierInfo(
        icon: Icons.star,
        background: AppColors.cardTint,
        shadow: Color(0x1F0B0F5B), // rgba(11,15,91,0.12)
        ink: AppColors.navy,
        message:
            "You're building real understanding; a bit more practice on "
            "the tricky parts will get you there.",
      );
    case PerformanceTier.needsReview:
      return const _TierInfo(
        icon: Icons.arrow_upward,
        background: AppColors.errorBannerBackground,
        shadow: Color(0x2EE31B23), // rgba(227,27,35,0.18)
        ink: Color(0xFFA8141B),
        message:
            "This one needs more work before it clicks — let's go through "
            "it again together.",
      );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardTint, width: 2),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.1), offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(height: 9),
          Text(value, style: TextStyle(fontFamily: 'Nunito', fontSize: 34, fontWeight: FontWeight.w900, height: 1, color: valueColor)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.06 * 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
