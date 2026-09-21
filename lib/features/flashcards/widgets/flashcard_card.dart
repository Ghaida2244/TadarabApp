import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Colors from `Tadarab Phase 2b - Flashcards.dc.html`'s flip-card face,
/// not in `AppColors` (Flashcards-only, avoids touching the shared frozen
/// theme file). Note: the design handoff's front face also has an optional
/// "EXAMPLE" panel — see the file-level doc comment on [FlashcardCard] for
/// why that isn't reproduced here.
const _kQuestionTagBg = Color(0xFFFFE9EA);
const _kQuestionTagInk = Color(0xFFA8141B);
const _kAnswerTagBg = Color(0xFFE6F7EC);
const _kAnswerTagInk = Color(0xFF15803D);
const _kFrontRing = Color(0xFFEEF0FF);
const _kBackRing = Color(0xFFC8EED8);

// Fixed size for the navy source-location strip, so it never grows or
// shrinks with the length of sourceLocation — both text lines are capped
// at one line with an ellipsis instead. Deliberately narrower than the
// card (not edge-to-edge): ~74% of the card's inner content width
// (352 card − 40 padding = 312 inner width; 230/312 ≈ 74%), centered by
// the surrounding Column's default center cross-axis alignment.
const _kSourceStripWidth = 230.0;
const _kSourceStripHeight = 54.0;

/// The flip card shown on both the Flip Deck (studying) and Review Pass
/// screens (same widget, reused, per the design handoff): front shows the
/// question, tapping flips to the answer + source location. Rating/
/// navigation controls live outside this widget.
///
/// The design handoff's front face also shows an optional "EXAMPLE" panel
/// with content distinct from the question — the [Flashcard] model (and the
/// Worker's generation contract) has no field for that, so it's not
/// rendered here; this is a data-model gap, not an oversight, flagged
/// separately.
///
/// The back face's source-location strip is a deliberate departure from
/// the design handoff (which, as of the current `.dc.html`, uses a light
/// `#EEF0FF` tint with navy text and no heading) — explicitly requested:
/// a navy strip with a white icon and two stacked lines, a dim "FIND IT IN
/// YOUR MATERIAL" label above the bold location line, narrower than the
/// card and horizontally centered rather than edge-to-edge.
class FlashcardCard extends StatelessWidget {
  const FlashcardCard({
    super.key,
    required this.frontText,
    required this.backText,
    required this.sourceLocation,
    required this.flipped,
    required this.onTap,
  });

  final String frontText;
  final String backText;
  final String sourceLocation;
  final bool flipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: flipped
            ? _CardFace(
                key: const ValueKey('flashcard-back'),
                ringColor: _kBackRing,
                child: _back(),
              )
            : _CardFace(
                key: const ValueKey('flashcard-front'),
                ringColor: _kFrontRing,
                child: _front(),
              ),
      ),
    );
  }

  Widget _front() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Tag(label: 'QUESTION', background: _kQuestionTagBg, ink: _kQuestionTagInk),
        const SizedBox(height: AppSpacing.lg),
        Text(
          frontText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.4,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.replay_outlined, size: 15, color: AppColors.placeholder),
            const SizedBox(width: 7),
            Text('Tap to flip', style: AppTypography.helper.copyWith(color: AppColors.placeholder)),
          ],
        ),
      ],
    );
  }

  Widget _back() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Tag(label: 'ANSWER', background: _kAnswerTagBg, ink: _kAnswerTagInk),
        const SizedBox(height: AppSpacing.lg),
        Text(
          backText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.4,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Container(
          key: const ValueKey('source-strip'),
          width: _kSourceStripWidth,
          height: _kSourceStripHeight,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 17,
                color: Colors.white,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FIND IT IN YOUR MATERIAL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.07 * 10,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sourceLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({super.key, required this.child, required this.ringColor});

  final Widget child;
  final Color ringColor;

  // The design handoff has no literal card size — the card is fluid
  // (width:100% of its container, height auto-sized to content) in the
  // prototype, so front/back and short/long content can render at
  // different sizes there. This app deliberately fixes that instead (a
  // card changing shape between front and back reads as a glitch, not a
  // feature).
  //
  // Sized against the two screens that actually host this widget
  // (flashcard_flip_deck_screen.dart / flashcard_review_pass_screen.dart):
  // both wrap it in `Padding(all: 22)`, i.e. 44px of fixed horizontal
  // budget regardless of device. Against the handoff's own reference
  // phone frame (412px wide — the same reference the previous 320px size
  // used), that leaves ~368px available. 352 is bigger than the previous
  // 320 (per request) while keeping a 16px safety margin under that
  // ceiling — width is the binding dimension here; the vertical budget in
  // both screens (after their header and bottom controls) has much more
  // room to spare even at this larger size.
  static const double _size = 352;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: ringColor, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0B0F5B), // navy @ ~10% alpha
            offset: Offset(0, 5),
          ),
        ],
      ),
      // Fixed size means content can overflow it once text is long enough
      // — handled by scrolling within the card (vertically) rather than
      // growing the card itself. Short content still reads as centered:
      // the ConstrainedBox forces the scroll area to at least fill the
      // available height, so Center has room to center into when there's
      // nothing to scroll.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          );
        },
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.background, required this.ink});

  final String label;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: ink,
          letterSpacing: 0.07 * 10,
        ),
      ),
    );
  }
}
