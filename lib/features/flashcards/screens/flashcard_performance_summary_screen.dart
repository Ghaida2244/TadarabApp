import 'package:flutter/material.dart';

import '../../../logic/performance_tier.dart';
import '../../../models/enums.dart';
import '../../../services/flashcard_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../flashcard_navigation.dart';
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

  // Was a plain Navigator.pop() ("Back to course") — unreliable, since
  // this screen is reachable both via the Sessions list (pop lands there,
  // fine) AND via Resume from Home (pop lands on Home instead, never on
  // the course page either way). popToFlashcardSessions deterministically
  // reaches the Sessions list regardless of entry path, mirroring Quiz's
  // own popToQuizSessions.
  void _backToSessions(BuildContext context) {
    popToFlashcardSessions(context);
  }

  @override
  Widget build(BuildContext context) {
    final tier = performanceTierFor(numerator: knownCount, denominator: _total);
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
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 12),
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
                            performanceTierMessage(tier),
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
                ],
              ),
            ),
          ),
          // Fixed at the bottom, outside the scrollable content above —
          // anchored to the screen's actual bottom regardless of how
          // short that content is, same pattern as Quiz's own Performance
          // Summary screen. SafeArea(top: false) since the header above
          // already handles the top inset itself.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    label: 'Back to sessions',
                    variant: AppButtonVariant.accent,
                    height: 56,
                    shadowColor: AppColors.redShadow.withValues(alpha: 0.6),
                    onPressed: () => _backToSessions(context),
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
  });

  final IconData icon;
  final Color background;
  final Color shadow;
  final Color ink;
}

/// Tier message copy now comes from the shared `performanceTierMessage`
/// (NOTE 6) — identical wording to Quiz's own Performance Summary screen.
/// Tier background/shadow/ink colors below are still sourced from the
/// handoff (`moodBg`/`moodShadow`/`moodInk` in `Tadarab Phase 2b -
/// Flashcards.dc.html`) and kept exactly as before — note its "developing"
/// (now "nice") tier is actually a light navy/lavender tint (`#EEF0FF` +
/// navy ink), not purple; see the conversation notes for why this differs
/// from this screen's previous (invented, not handoff-sourced) purple.
_TierInfo _tierInfoFor(PerformanceTier tier) {
  switch (tier) {
    case PerformanceTier.excellent:
      return const _TierInfo(
        icon: Icons.emoji_events,
        background: Color(0xFFE6F7EC),
        shadow: Color(0x3816A34A), // rgba(22,163,74,0.22)
        ink: Color(0xFF15803D),
      );
    case PerformanceTier.nice:
      return const _TierInfo(
        icon: Icons.star,
        background: AppColors.cardTint,
        shadow: Color(0x1F0B0F5B), // rgba(11,15,91,0.12)
        ink: AppColors.navy,
      );
    case PerformanceTier.needsWork:
      return const _TierInfo(
        icon: Icons.arrow_upward,
        background: AppColors.errorBannerBackground,
        shadow: Color(0x2EE31B23), // rgba(227,27,35,0.18)
        ink: Color(0xFFA8141B),
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
