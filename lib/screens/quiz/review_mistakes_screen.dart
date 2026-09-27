import 'package:flutter/material.dart';

import '../../models/question.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import 'widgets/quiz_icon_button.dart';

/// Exam Mode's post-summary accordion of wrong answers: question, the
/// student's (red) pick, and — on expand — the correct answer (green) plus
/// the explanation and source.
class ReviewMistakesScreen extends StatefulWidget {
  const ReviewMistakesScreen({
    super.key,
    required this.mistakes,
    required this.totalQuestions,
  });

  final List<Question> mistakes;

  /// Total questions in the session these mistakes came from — the count
  /// label reads "N wrong out of {totalQuestions}", not out of the
  /// mistakes list itself.
  final int totalQuestions;

  @override
  State<ReviewMistakesScreen> createState() => _ReviewMistakesScreenState();
}

class _ReviewMistakesScreenState extends State<ReviewMistakesScreen> {
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final count = widget.mistakes.length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  QuizIconButton(
                    icon: Icons.arrow_back,
                    semanticLabel: 'Back',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your mistakes', style: AppTypography.quizHeaderTitle.copyWith(fontSize: 22)),
                        Text(
                          count == 1
                              ? '1 wrong out of ${widget.totalQuestions}'
                              : '$count wrong out of ${widget.totalQuestions}',
                          style: AppTypography.quizHeaderMeta,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.mistakes.isEmpty
                  ? Center(
                      child: Text('No mistakes to review.', style: AppTypography.quizEmptyTitle),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                      itemCount: widget.mistakes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final q = widget.mistakes[index];
                        final open = _open.contains(q.questionId);
                        return _MistakeCard(
                          index: index,
                          question: q,
                          open: open,
                          onToggle: () => setState(() {
                            if (open) {
                              _open.remove(q.questionId);
                            } else {
                              _open.add(q.questionId);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({
    required this.index,
    required this.question,
    required this.open,
    required this.onToggle,
  });

  final int index;
  final Question question;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final chose = question.studentAnswer == null
        ? 'You left this one blank'
        : 'You chose: ${question.studentAnswer}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardTint, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.errorBannerBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'QUESTION ${index + 1}',
              style: AppTypography.quizBadge.copyWith(color: AppColors.errorBannerBody),
            ),
          ),
          const SizedBox(height: 11),
          Text(question.questionText, style: AppTypography.quizCardTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(color: AppColors.errorBackground, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(chose, style: AppTypography.quizOption(FontWeight.w900, color: AppColors.errorBannerHeading).copyWith(fontSize: 13)),
                ),
              ],
            ),
          ),
          if (open) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(color: AppColors.successBackground, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Correct: ${question.correctAnswer}',
                      style: AppTypography.quizOption(FontWeight.w900, color: AppColors.successDark).copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EXPLANATION', style: AppTypography.quizPanelLabel()),
                  const SizedBox(height: 5),
                  Text(question.explanation, style: AppTypography.quizPanelBody.copyWith(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: AppColors.navy,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 34,
                        alignment: Alignment.center,
                        color: Colors.white.withValues(alpha: 0.1),
                        child: const Icon(Icons.menu_book_outlined, size: 14, color: Colors.white),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FIND IT IN YOUR MATERIAL',
                                style: AppTypography.quizPanelLabel(
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                question.sourceLocation,
                                style: AppTypography.quizSourceValue.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 11),
          AppButton(
            label: open ? 'Hide details' : 'Show the answer',
            onPressed: onToggle,
            height: 44,
            borderRadius: 14,
            shadowColor: AppColors.navy.withValues(alpha: 0.10),
          ),
        ],
      ),
    );
  }
}
