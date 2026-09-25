import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/question.dart';
import '../../models/quiz_session.dart';
import '../../services/quiz_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import 'quiz_navigation.dart';
import 'quiz_play_screen.dart';
import 'review_mistakes_screen.dart';

/// Correct/wrong counts -> mood message -> points earned -> weak-topic
/// actions, in that fixed order (no percentage shown anywhere, per the
/// design). Two ways to reach this screen: a real completed session
/// ([PerformanceSummaryScreen] — has points, and Review Mistakes/Practice
/// Now actions by mode), or a one-off Practice Now result
/// ([PerformanceSummaryScreen.practiceResult] — no points, no session, no
/// further practice/retake action, just Back to Sessions).
class PerformanceSummaryScreen extends StatefulWidget {
  const PerformanceSummaryScreen({
    super.key,
    required String sessionId,
    required QuizSessionService service,
  }) : sessionId = sessionId,
       service = service,
       practiceCorrect = null,
       practiceTotal = null;

  const PerformanceSummaryScreen.practiceResult({
    super.key,
    required int correct,
    required int total,
  }) : sessionId = null,
       service = null,
       practiceCorrect = correct,
       practiceTotal = total;

  final String? sessionId;
  final QuizSessionService? service;
  final int? practiceCorrect;
  final int? practiceTotal;

  bool get isPracticeResult => practiceCorrect != null;

  @override
  State<PerformanceSummaryScreen> createState() => _PerformanceSummaryScreenState();
}

class _PerformanceSummaryScreenState extends State<PerformanceSummaryScreen> {
  late Future<_SummaryData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_SummaryData> _load() async {
    if (widget.isPracticeResult) {
      return _SummaryData(
        session: null,
        correct: widget.practiceCorrect!,
        total: widget.practiceTotal!,
        mistakes: const [],
      );
    }
    final session = await widget.service!.fetchSession(widget.sessionId!);
    final questions = await widget.service!.fetchQuestions(widget.sessionId!);
    final mistakes = questions.where((q) => q.isCorrect != true).toList();
    return _SummaryData(
      session: session,
      correct: session.correctAnswers,
      total: session.numberOfQuestions,
      mistakes: mistakes,
    );
  }

  Future<void> _practiceNow(_SummaryData data) async {
    // .asUnanswered(): these Question objects still carry the studentAnswer
    // from the original session. Passing them through as-is would make
    // QuizPlayScreen's resume/reveal logic treat every question as already
    // submitted — the first question would show the old pick pre-selected,
    // and every question after it would jump straight to the revealed
    // state with no chance to answer. Practice must start completely fresh.
    final freshQuestions = data.mistakes.map((q) => q.asUnanswered()).toList();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizPlayScreen(
          practiceQuestions: freshQuestions,
          service: widget.service!,
        ),
      ),
    );
  }

  void _reviewMistakes(_SummaryData data) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewMistakesScreen(
          mistakes: data.mistakes,
          totalQuestions: data.total,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<_SummaryData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) {
              return Center(
                child: Text("Couldn't load your results.", style: AppTypography.quizEmptyTitle),
              );
            }
            final data = snapshot.data!;
            final mood = resultMoodFor(correct: data.correct, total: data.total);
            final wrong = data.total - data.correct;

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      Text('Performance Summary', style: AppTypography.quizSummaryTitle, textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(
                        widget.isPracticeResult
                            ? 'PRACTICE ROUND'
                            : '${data.session!.mode == Mode.exam ? 'EXAM' : 'LEARNING'} MODE · ${data.total} QUESTIONS',
                        style: AppTypography.quizHeaderMeta,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 30, 22, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _CountCard(
                                icon: Icons.check,
                                iconBg: AppColors.successBackgroundStrong,
                                iconColor: AppColors.success,
                                count: data.correct,
                                countColor: AppColors.success,
                                label: 'CORRECT',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CountCard(
                                icon: Icons.close,
                                iconBg: AppColors.errorBannerBackground,
                                iconColor: AppColors.red,
                                count: wrong,
                                countColor: AppColors.red,
                                label: 'WRONG',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _MoodBanner(mood: mood),
                        if (!widget.isPracticeResult) ...[
                          const SizedBox(height: 18),
                          _PointsStrip(points: data.session!.earnedPoints),
                        ],
                      ],
                    ),
                  ),
                ),
                // Actions live outside the scrollable area, on their own
                // fixed bottom bar — anchored to the screen's actual
                // bottom regardless of how short the scrollable content
                // above is, rather than following the content flow (which
                // left empty space beneath them whenever there were no
                // mistakes to show, e.g. no Review/Practice button).
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
                  child: Column(children: _buildActions(data)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildActions(_SummaryData data) {
    final actions = <Widget>[];
    if (widget.isPracticeResult) {
      actions.add(
        AppButton(
          label: 'Back to Sessions',
          variant: AppButtonVariant.accent,
          height: 56,
          borderRadius: 16,
          onPressed: () => popToQuizSessions(context),
        ),
      );
      return actions;
    }

    final mode = data.session!.mode;
    if (mode == Mode.exam && data.mistakes.isNotEmpty) {
      actions.add(
        AppButton(
          label: 'Review mistakes',
          height: 56,
          borderRadius: 16,
          onPressed: () => _reviewMistakes(data),
        ),
      );
      actions.add(const SizedBox(height: 11));
    }
    if (mode == Mode.learning && data.mistakes.isNotEmpty) {
      actions.add(
        AppButton(
          label: 'Practice Now',
          height: 56,
          borderRadius: 16,
          onPressed: () => _practiceNow(data),
        ),
      );
      actions.add(const SizedBox(height: 11));
    }
    actions.add(
      AppButton(
        label: 'Back to Sessions',
        variant: AppButtonVariant.accent,
        height: 56,
        borderRadius: 16,
        onPressed: () => popToQuizSessions(context),
      ),
    );
    return actions;
  }
}

class _SummaryData {
  _SummaryData({
    required this.session,
    required this.correct,
    required this.total,
    required this.mistakes,
  });

  final QuizSession? session;
  final int correct;
  final int total;
  final List<Question> mistakes;
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.count,
    required this.countColor,
    required this.label,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final int count;
  final Color countColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardTint, width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: 9),
          Text('$count', style: AppTypography.quizResultCount(countColor)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.quizResultCountLabel),
        ],
      ),
    );
  }
}

class _MoodBanner extends StatelessWidget {
  const _MoodBanner({required this.mood});

  final ResultMood mood;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color ink;
    final IconData icon;
    switch (mood) {
      case ResultMood.great:
        bg = AppColors.successBackgroundStrong;
        ink = AppColors.successDark;
        icon = Icons.emoji_events_outlined;
        break;
      case ResultMood.solid:
        bg = AppColors.cardTint;
        ink = AppColors.navy;
        icon = Icons.star_outline;
        break;
      case ResultMood.keepPractising:
        bg = AppColors.errorBannerBackground;
        ink = AppColors.errorBannerBody;
        icon = Icons.trending_up;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(resultMessageFor(mood), style: AppTypography.quizResultLine(ink)),
          ),
        ],
      ),
    );
  }
}

class _PointsStrip extends StatelessWidget {
  const _PointsStrip({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(color: AppColors.warningBackground, borderRadius: BorderRadius.circular(22)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Points earned', style: AppTypography.quizPointsLabel),
          Text('+$points', style: AppTypography.quizPointsValue),
        ],
      ),
    );
  }
}
