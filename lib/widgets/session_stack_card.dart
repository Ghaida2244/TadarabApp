import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Wraps a single card (whatever [cardBuilder] returns — the latest
/// attempt, rendered without its own action buttons or delete button when
/// [stackSize] is 2+, per the Retake Stacks design) with up to two "peek"
/// layers behind it, and makes the whole thing tappable to open the
/// group's focus view. Feature-agnostic — Quiz and Flashcards both use
/// this for their Sessions list's grouped-by-retake-chain cards; see
/// [groupSessionsIntoStacks] (lib/logic/session_stacking.dart) for the
/// grouping itself.
///
/// Exact values from docs/mockups/redesign-handoff_stacks_quiz_flashcard/
/// .../SessionStackCard.dc.html's hand-off spec (LAYERS / RESERVED SPACE
/// rows) — "1a below" look only, the approved option (older attempts peek
/// out below the top card, not above).
class SessionStackCard extends StatelessWidget {
  const SessionStackCard({
    super.key,
    required this.stackSize,
    required this.cardBuilder,
    this.onOpenStack,
  });

  /// Total attempts in this group. 1 renders [cardBuilder] alone, with no
  /// peek layers and no tap-to-open — a plain card is the caller's own
  /// business, same as before stacking existed.
  final int stackSize;

  /// Builds the latest attempt's card — the caller decides whether to
  /// render its action buttons/delete button (hidden when [stackSize] is
  /// 2+, per the design's "Stack buttons: Hide").
  final WidgetBuilder cardBuilder;

  /// Opens the group's focus view. Only ever invoked when [stackSize] is
  /// 2+ — a lone card ignores taps here entirely.
  final VoidCallback? onOpenStack;

  bool get _stacked => stackSize > 1;
  int get _peeks => _stacked ? (stackSize - 1).clamp(0, 2) : 0;

  // SPEC: "Layer 1: fill #F7F8FD, border 2dp #E2E6F5. Layer 2: fill
  // #EEF0FF, same border." — both are already AppColors tokens.
  static const _layer1Fill = AppColors.surfaceMuted;
  static const _layer2Fill = AppColors.cardTint;
  static const _peekBorder = AppColors.borderDefault;

  @override
  Widget build(BuildContext context) {
    final peeks = _peeks;
    if (peeks == 0) return cardBuilder(context);

    // SPEC: "The stack reserves 8dp × visible layers below the card... so
    // it never overlaps the next card or a header... Wrap the stack in
    // AnimatedSize so the space changes smoothly when an attempt is
    // deleted."
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: peeks * 8.0),
        child: Semantics(
          button: true,
          label: 'Session stack, $stackSize attempts',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenStack,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (peeks >= 2)
                  _peekLayer(bottomOffset: 16, inset: 20, fill: _layer2Fill),
                if (peeks >= 1)
                  _peekLayer(bottomOffset: 8, inset: 10, fill: _layer1Fill),
                ExcludeSemantics(child: cardBuilder(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _peekLayer({
    required double bottomOffset,
    required double inset,
    required Color fill,
  }) {
    // SPEC: "each 44dp tall... Horizontal inset 10dp per side per layer...
    // Same radius 22. No shadow on layers." — the hand-off's live prototype
    // (SessionStackCard.dc.html) additionally gives each peek layer its
    // own drop shadow (`peekShadow`, '0 4px 0 rgba(11,15,91,.14)') in the
    // "below" look specifically, which reads better against the card's
    // own hard-offset shadow than no shadow at all — kept from the
    // prototype's actual code over the summary table's "no shadow" line.
    return Positioned(
      left: inset,
      right: inset,
      bottom: -bottomOffset,
      height: 44,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: _peekBorder, width: 2),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.14),
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
