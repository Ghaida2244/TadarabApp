import 'package:flutter/material.dart';

import '../../../models/enums.dart';
import '../../../models/flashcard.dart';
import '../../../services/flashcard_service.dart';
import '../../../theme/app_theme.dart';
import '../logic/flashcard_logic.dart';
import '../widgets/flashcard_card.dart';
import '../widgets/header_circle_button.dart';
import '../widgets/progress_pips.dart';
import '../widgets/save_and_leave_sheet.dart';
import 'flashcard_performance_summary_screen.dart';

/// Screen 3: studying a deck card by card, rating each as known/needs
/// review. Also used to resume an in-progress session and to study a fresh
/// Retake — both just supply different initial values.
class FlashcardFlipDeckScreen extends StatefulWidget {
  const FlashcardFlipDeckScreen({
    super.key,
    required this.uid,
    required this.courseId,
    required this.sessionId,
    required this.initialFlashcards,
    required this.initialIndex,
    required this.initialKnownCount,
    required this.initialNeedsReviewCount,
    this.service,
  });

  final String uid;
  final String courseId;
  final String sessionId;
  final List<Flashcard> initialFlashcards;
  final int initialIndex;
  final int initialKnownCount;
  final int initialNeedsReviewCount;

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final FlashcardService? service;

  @override
  State<FlashcardFlipDeckScreen> createState() =>
      _FlashcardFlipDeckScreenState();
}

class _FlashcardFlipDeckScreenState extends State<FlashcardFlipDeckScreen> {
  late final FlashcardService _service =
      widget.service ??
      FlashcardService(uid: widget.uid, courseId: widget.courseId);

  late List<Flashcard> _flashcards = widget.initialFlashcards;
  late int _currentIndex = widget.initialIndex;
  late int _knownCount = widget.initialKnownCount;
  late int _needsReviewCount = widget.initialNeedsReviewCount;
  bool _flipped = false;

  int get _total => _flashcards.length;
  bool get _isLastCard => _currentIndex == _total - 1;

  void _flip() => setState(() => _flipped = !_flipped);

  Future<void> _rate(ReviewStatus status) async {
    final flashcard = _flashcards[_currentIndex];
    final newKnownCount =
        _knownCount + (status == ReviewStatus.knowIt ? 1 : 0);
    final newNeedsReviewCount =
        _needsReviewCount + (status == ReviewStatus.needsReview ? 1 : 0);
    final isLast = _isLastCard;

    setState(() {
      _flashcards = [
        for (var i = 0; i < _flashcards.length; i++)
          if (i == _currentIndex)
            _flashcards[i].copyWith(reviewStatus: () => status)
          else
            _flashcards[i],
      ];
      _knownCount = newKnownCount;
      _needsReviewCount = newNeedsReviewCount;
      if (!isLast) {
        _currentIndex += 1;
        _flipped = false;
      }
    });

    if (isLast) {
      final completedAt = DateTime.now();
      await _service.completeSession(
        sessionId: widget.sessionId,
        flashcardId: flashcard.flashcardId,
        status: status,
        finalIndex: _currentIndex,
        knownCount: newKnownCount,
        needsReviewCount: newNeedsReviewCount,
        completedAt: completedAt,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FlashcardPerformanceSummaryScreen(
            uid: widget.uid,
            courseId: widget.courseId,
            sessionId: widget.sessionId,
            knownCount: newKnownCount,
            needsReviewCount: newNeedsReviewCount,
            earnedPoints: calculateEarnedPoints(knownCount: newKnownCount),
            service: _service,
          ),
        ),
      );
    } else {
      await _service.markFlashcard(
        sessionId: widget.sessionId,
        flashcardId: flashcard.flashcardId,
        status: status,
        currentFlashcardIndex: _currentIndex,
        knownCount: newKnownCount,
        needsReviewCount: newNeedsReviewCount,
      );
    }
  }

  void _openSaveAndLeave() {
    showSaveAndLeaveSheet(
      context,
      reviewedCount: _knownCount + _needsReviewCount,
      total: _total,
      resumeCardNumber: _currentIndex + 1,
      onSaveAndLeave: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flashcard = _flashcards[_currentIndex];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Flat navy header (no bottom radius) — per the design handoff,
          // distinct from Sessions/Setup's rounded-bottom navy headers.
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
                        onTap: _openSaveAndLeave,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Card ${_currentIndex + 1} of $_total',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Text(
                        'Flashcards',
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
                    total: _total,
                    currentIndex: _currentIndex,
                    statuses: _flashcards.map((f) => f.reviewStatus).toList(),
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
                  onTap: _flip,
                ),
              ),
            ),
          ),
          if (_flipped)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
              child: Row(
                children: [
                  Expanded(
                    child: _VerdictButton(
                      label: 'Need review',
                      icon: Icons.replay,
                      background: Colors.white,
                      ink: const Color(0xFFA8141B),
                      borderColor: AppColors.red,
                      shadowColor: AppColors.red.withValues(alpha: 0.22),
                      onTap: () => _rate(ReviewStatus.needsReview),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: _VerdictButton(
                      label: 'I know it',
                      icon: Icons.check,
                      background: AppColors.success,
                      ink: Colors.white,
                      shadowColor: AppColors.successDark.withValues(alpha: 0.6),
                      onTap: () => _rate(ReviewStatus.knowIt),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A hard-coded-color pressable button matching the design handoff's verdict
/// buttons exactly. Not built on the shared [AppButton] widget: neither a
/// solid-green fill (`I know it`) nor a white/red-outlined fill with red ink
/// (`Need review`) is reachable through AppButton's public API (no
/// background-color or text-color override exists), and this pass
/// intentionally does not edit that shared, possibly-in-use file.
class _VerdictButton extends StatefulWidget {
  const _VerdictButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.ink,
    required this.shadowColor,
    required this.onTap,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color ink;
  final Color shadowColor;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  State<_VerdictButton> createState() => _VerdictButtonState();
}

class _VerdictButtonState extends State<_VerdictButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.background,
          borderRadius: BorderRadius.circular(16),
          border: widget.borderColor != null ? Border.all(color: widget.borderColor!, width: 2) : null,
          boxShadow: [
            BoxShadow(color: widget.shadowColor, offset: Offset(0, _pressed ? 1 : 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 17, color: widget.ink),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w900, color: widget.ink),
            ),
          ],
        ),
      ),
    );
  }
}
