import 'package:flutter/material.dart';

import '../../../models/flashcard.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../widgets/flashcard_card.dart';
import '../widgets/header_circle_button.dart';
import '../widgets/progress_pips.dart';

/// Screen 4: read-only browsing of a session's "Needs Review" flashcards,
/// in their existing stored order. Zero writes anywhere — see CLAUDE.md.
///
/// Per the design handoff, this reuses the exact same pip-strip progress
/// component as the Flip Deck (not a continuous bar) — the practice/review
/// pass in `Tadarab Phase 2b - Flashcards.dc.html` renders through the same
/// `onDeck` screen state, just with navigation buttons instead of verdict
/// buttons.
class FlashcardReviewPassScreen extends StatefulWidget {
  const FlashcardReviewPassScreen({super.key, required this.flashcards});

  /// Already filtered to reviewStatus == needsReview, in stored order.
  final List<Flashcard> flashcards;

  @override
  State<FlashcardReviewPassScreen> createState() =>
      _FlashcardReviewPassScreenState();
}

class _FlashcardReviewPassScreenState
    extends State<FlashcardReviewPassScreen> {
  int _index = 0;
  bool _flipped = false;

  bool get _isLast => _index == widget.flashcards.length - 1;

  void _goPrevious() {
    if (_index == 0) return;
    setState(() {
      _index -= 1;
      _flipped = false;
    });
  }

  void _goNext() {
    if (_isLast) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index += 1;
      _flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.flashcards.length;
    final flashcard = widget.flashcards[_index];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            color: AppColors.navy,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      HeaderCircleButton(
                        icon: Icons.close,
                        size: 34,
                        iconSize: 15,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Card ${_index + 1} of $total',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Text(
                        'Review',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0x99FFFFFF), // white @ 60% alpha
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  ProgressPips(
                    total: total,
                    currentIndex: _index,
                    statuses: widget.flashcards.map((f) => f.reviewStatus).toList(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: FlashcardCard(
                  frontText: flashcard.frontText,
                  backText: flashcard.backText,
                  sourceLocation: flashcard.sourceLocation,
                  flipped: _flipped,
                  onTap: () => setState(() => _flipped = !_flipped),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
            child: Column(
              children: [
                AppButton(
                  label: _isLast ? 'Done reviewing →' : 'Next →',
                  variant: AppButtonVariant.accent,
                  height: 54,
                  shadowColor: AppColors.redShadow.withValues(alpha: 0.6),
                  onPressed: _goNext,
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Previous',
                  variant: AppButtonVariant.outlinedNeutral,
                  height: 50,
                  onPressed: _index == 0 ? null : _goPrevious,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
