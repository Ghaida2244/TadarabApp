import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/question.dart';
import '../../models/quiz_session.dart';
import '../../services/quiz_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import 'performance_summary_screen.dart';
import 'widgets/quiz_icon_button.dart';

/// One question at a time, in either mode. Three ways to reach this
/// screen: a real Learning-mode session ([sessionId] — persisted from the
/// moment it's created, resumable, incremental Firestore writes as she
/// goes), an Exam-mode draft ([examDraftSession]/[examDraftQuestions] —
/// held entirely in memory, nothing written to Firestore until the final
/// Submit; see [QuizSessionService.submitExamSession]), or a Practice Now
/// round ([practiceQuestions] — ephemeral, Learning-mode UI only, never
/// saved, never tracked, not even at the end).
class QuizPlayScreen extends StatefulWidget {
  const QuizPlayScreen({
    super.key,
    this.sessionId,
    this.practiceQuestions,
    required this.service,
  }) : examDraftSession = null,
       examDraftQuestions = null,
       assert(
         (sessionId == null) != (practiceQuestions == null),
         'Exactly one of sessionId or practiceQuestions must be given',
       );

  /// An Exam session that hasn't been written to Firestore yet — see the
  /// class doc comment. [session] carries a real, reserved (but unwritten)
  /// session id; [questions] likewise carry real, reserved question ids —
  /// both are what [QuizSessionService.submitExamSession] will finally
  /// write, once, at the end.
  const QuizPlayScreen.examDraft({
    super.key,
    required QuizSession session,
    required List<Question> questions,
    required this.service,
  }) : sessionId = null,
       practiceQuestions = null,
       examDraftSession = session,
       examDraftQuestions = questions;

  final String? sessionId;
  final List<Question>? practiceQuestions;
  final QuizSession? examDraftSession;
  final List<Question>? examDraftQuestions;
  final QuizSessionService service;

  bool get isPractice => practiceQuestions != null;
  bool get isExamDraft => examDraftSession != null;

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  late Future<_PlayData> _dataFuture;
  int _index = 0;
  bool _revealed = false;
  final Map<int, String> _localAnswers = {};
  // Exam-draft only: "Report this question" has nothing persisted to
  // update yet, so it's held here and merged into the final question list
  // in _finish, right alongside _localAnswers.
  final Set<String> _locallyReportedQuestionIds = {};
  Mode _mode = Mode.learning;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_PlayData> _load() async {
    if (widget.isPractice) {
      // Practice always starts completely fresh — no seeding _localAnswers
      // from studentAnswer here. The caller (PerformanceSummaryScreen) is
      // responsible for handing this screen Questions with studentAnswer
      // already cleared (see Question.asUnanswered()); this branch never
      // treats a practice question as pre-answered, on purpose.
      final questions = widget.practiceQuestions!;
      _mode = Mode.learning;
      _index = 0;
      _revealed = false;
      return _PlayData(session: null, questions: questions);
    }

    if (widget.isExamDraft) {
      // Nothing to fetch — the draft handed to this screen *is* the only
      // copy of this session until _finish's single write. See
      // QuizSessionService.submitExamSession.
      _mode = Mode.exam;
      _index = 0;
      _revealed = false;
      return _PlayData(
        session: widget.examDraftSession,
        questions: widget.examDraftQuestions!,
      );
    }

    final session = await widget.service.fetchSession(widget.sessionId!);
    final questions = await widget.service.fetchQuestions(widget.sessionId!);
    _mode = session.mode;
    _index = session.currentQuestionIndex.clamp(0, questions.isEmpty ? 0 : questions.length - 1);
    for (var i = 0; i < questions.length; i++) {
      if (questions[i].studentAnswer != null) {
        _localAnswers[i] = questions[i].studentAnswer!;
      }
    }
    _revealed = isRevealedState(
      mode: _mode,
      current: questions.isEmpty ? null : questions[_index],
    );
    return _PlayData(session: session, questions: questions);
  }

  Future<void> _pick(_PlayData data, String answer) async {
    if (_revealed) return;
    setState(() => _localAnswers[_index] = answer);
    // Practice never persists anything; an Exam draft doesn't persist
    // anything either, until the single write in _finish.
    if (!widget.isPractice && !widget.isExamDraft) {
      await widget.service.submitAnswer(
        sessionId: widget.sessionId!,
        questionId: data.questions[_index].questionId,
        answer: answer,
      );
    }
  }

  Future<void> _advance(_PlayData data) async {
    final isLast = _index >= data.questions.length - 1;

    if (_mode == Mode.learning && !_revealed) {
      setState(() => _revealed = true);
      return;
    }

    if (isLast) {
      await _finish(data);
      return;
    }

    final nextIndex = _index + 1;
    setState(() {
      _index = nextIndex;
      _revealed = isRevealedState(mode: _mode, current: data.questions[nextIndex]);
    });
    if (!widget.isPractice && !widget.isExamDraft) {
      await widget.service.setCurrentQuestionIndex(
        sessionId: widget.sessionId!,
        index: nextIndex,
      );
    }
  }

  Future<void> _previous(_PlayData data) async {
    if (_index == 0) return;
    final prevIndex = _index - 1;
    setState(() => _index = prevIndex);
    if (!widget.isPractice && !widget.isExamDraft) {
      await widget.service.setCurrentQuestionIndex(
        sessionId: widget.sessionId!,
        index: prevIndex,
      );
    }
  }

  Future<void> _finish(_PlayData data) async {
    setState(() => _finishing = true);
    if (widget.isPractice) {
      var correct = 0;
      for (var i = 0; i < data.questions.length; i++) {
        if (_localAnswers[i] == data.questions[i].correctAnswer) correct++;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PerformanceSummaryScreen.practiceResult(
            correct: correct,
            total: data.questions.length,
          ),
        ),
      );
      return;
    }

    if (widget.isExamDraft) {
      // The one and only Firestore write for this whole exam — merge the
      // local answers (and any locally-flagged reports) into the draft
      // questions, then hand the complete, already-final picture to
      // submitExamSession. See its doc comment for why this is the only
      // place an Exam session's id ever touches Firestore.
      final answered = [
        for (var i = 0; i < data.questions.length; i++)
          data.questions[i].copyWith(
            studentAnswer: _localAnswers[i],
            isReported: _locallyReportedQuestionIds.contains(
              data.questions[i].questionId,
            ),
          ),
      ];
      final completed = await widget.service.submitExamSession(
        draftSession: data.session!,
        answeredQuestions: answered,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PerformanceSummaryScreen(
            sessionId: completed.sessionId,
            service: widget.service,
          ),
        ),
      );
      return;
    }

    // Guard against completing an already-completed session a second time.
    // Shouldn't normally be reachable now that QuizSessionsScreen reloads
    // correctly on return (see quiz_navigation.dart), but this makes it
    // impossible regardless of how this screen was reached — e.g. a stale
    // "in progress" row from before that fix, or any future path that
    // resumes a session without re-checking its state first. Re-completing
    // would double-count points (completeSession's totalPoints increment
    // isn't idempotent) without changing the result shown.
    if (data.session != null && data.session!.isSessionCompleted) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PerformanceSummaryScreen(
            sessionId: widget.sessionId!,
            service: widget.service,
          ),
        ),
      );
      return;
    }

    await widget.service.completeSession(widget.sessionId!);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PerformanceSummaryScreen(
          sessionId: widget.sessionId!,
          service: widget.service,
        ),
      ),
    );
  }

  Future<void> _report(_PlayData data) async {
    if (widget.isPractice) return;
    if (widget.isExamDraft) {
      // Nothing persisted to update yet — held locally and merged into
      // the final question list in _finish, alongside _localAnswers.
      _locallyReportedQuestionIds.add(data.questions[_index].questionId);
    } else {
      await widget.service.reportQuestion(
        sessionId: widget.sessionId!,
        questionId: data.questions[_index].questionId,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks — we will take a look at this question.')),
    );
  }

  Future<void> _askExit() async {
    if (widget.isPractice) {
      Navigator.of(context).maybePop();
      return;
    }
    final answered = _localAnswers.length;
    final leave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SaveAndLeaveSheet(
        answered: answered,
        onLeave: () => Navigator.of(context).pop(true),
        onKeepGoing: () => Navigator.of(context).pop(false),
      ),
    );
    if (leave == true && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<_PlayData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SafeArea(child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.questions.isEmpty) {
            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Text("Couldn't load this quiz.", style: AppTypography.quizEmptyTitle),
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final questions = data.questions;
          final total = questions.length;
          final isLast = _index >= total - 1;
          final current = questions[_index];
          final picked = _localAnswers[_index];
          final hasPick = picked != null;
          // The X shows for Learning mode and for Practice (always
          // Learning-styled) — only a real Exam-mode session has none.
          // _askExit itself branches practice's "exit immediately, no
          // prompt" from a real session's save-and-leave sheet.
          final canExit = widget.isPractice || _mode == Mode.learning;
          final locked = !widget.isPractice && _mode == Mode.exam;

          return SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                  decoration: const BoxDecoration(color: AppColors.navy),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (canExit)
                            QuizIconButton(
                              icon: Icons.close,
                              size: 34,
                              semanticLabel: 'Leave quiz',
                              onTap: _askExit,
                            ),
                          if (locked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_outline, size: 13, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text('LOCKED', style: AppTypography.quizBadge.copyWith(color: Colors.white)),
                                ],
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Question ${_index + 1} of $total',
                              style: AppTypography.quizOption(FontWeight.w900, color: Colors.white).copyWith(fontSize: 15),
                            ),
                          ),
                          Text(
                            widget.isPractice ? 'Practice' : (_mode == Mode.learning ? 'Learning' : 'Exam'),
                            style: AppTypography.quizHeaderMeta,
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: List.generate(total, (i) {
                          final Color color;
                          if (i == _index) {
                            color = AppColors.red;
                          } else if (_localAnswers.containsKey(i)) {
                            color = Colors.white.withValues(alpha: 0.75);
                          } else {
                            color = Colors.white.withValues(alpha: 0.22);
                          }
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
                              height: 6,
                              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(current.questionText, style: AppTypography.quizQuestion),
                            ),
                            if (!widget.isPractice)
                              IconButton(
                                onPressed: () => _report(data),
                                icon: const Icon(Icons.flag_outlined, size: 20, color: AppColors.placeholder),
                                tooltip: 'Report this question',
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ...current.options.map((option) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _OptionTile(
                              option: option,
                              index: current.options.indexOf(option),
                              selected: picked == option,
                              revealed: _revealed,
                              isCorrectOption: option == current.correctAnswer,
                              onTap: () => _pick(data, option),
                            ),
                          );
                        }),
                        if (_revealed) ...[
                          const SizedBox(height: 16),
                          _ExplanationPanel(question: current),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
                  child: Column(
                    children: [
                      AppButton(
                        label: nextButtonLabel(mode: _mode, revealed: _revealed, isLastQuestion: isLast),
                        height: 54,
                        borderRadius: 16,
                        variant: AppButtonVariant.accent,
                        // While loading, AppButton already shows its own
                        // grey disabledShadow — leave shadowColor unset so
                        // this override doesn't stomp it.
                        shadowColor: _finishing ? null : AppColors.navy.withValues(alpha: 0.10),
                        disabledBackgroundColor: AppColors.disabledRedFill,
                        disabledRemovesShadow: true,
                        loading: _finishing,
                        onPressed: hasPick && !_finishing ? () => _advance(data) : null,
                      ),
                      if (locked) ...[
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Previous',
                          variant: AppButtonVariant.outlinedBrand,
                          height: 50,
                          borderRadius: 16,
                          shadowColor: AppColors.navy.withValues(alpha: 0.10),
                          onPressed: _index == 0 ? null : () => _previous(data),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlayData {
  _PlayData({required this.session, required this.questions});

  final QuizSession? session;
  final List<Question> questions;
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.index,
    required this.selected,
    required this.revealed,
    required this.isCorrectOption,
    required this.onTap,
  });

  final String option;
  final int index;
  final bool selected;
  final bool revealed;
  final bool isCorrectOption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white;
    Color border = AppColors.borderDefault;
    Color textColor = AppColors.navy;
    Color keyBg = AppColors.cardTint;
    Color keyInk = AppColors.disabledMuted;
    FontWeight weight = FontWeight.w800;
    String? mark;
    Color markColor = AppColors.navy;

    if (revealed) {
      if (isCorrectOption) {
        bg = AppColors.successBackground;
        border = AppColors.success;
        textColor = AppColors.successDark;
        keyBg = AppColors.success;
        keyInk = Colors.white;
        weight = FontWeight.w900;
        mark = 'CORRECT';
        markColor = AppColors.successDark;
      } else if (selected) {
        bg = AppColors.errorBackground;
        border = AppColors.red;
        textColor = AppColors.errorBannerHeading;
        keyBg = AppColors.red;
        keyInk = Colors.white;
        weight = FontWeight.w900;
        mark = 'YOURS';
        markColor = AppColors.errorBannerBody;
      } else {
        textColor = AppColors.placeholder;
      }
    } else if (selected) {
      bg = AppColors.navy;
      border = AppColors.navy;
      textColor = Colors.white;
      keyBg = Colors.white;
      keyInk = AppColors.navy;
      weight = FontWeight.w900;
    }

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: keyBg, shape: BoxShape.circle),
              child: Text(
                String.fromCharCode(65 + index),
                style: AppTypography.quizOptionKey.copyWith(color: keyInk),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(option, style: AppTypography.quizOption(weight, color: textColor)),
            ),
            if (mark != null) Text(mark, style: AppTypography.quizBadge.copyWith(color: markColor)),
          ],
        ),
      ),
    );
  }
}

class _ExplanationPanel extends StatelessWidget {
  const _ExplanationPanel({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardTint, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            color: AppColors.surfaceMuted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EXPLANATION', style: AppTypography.quizPanelLabel()),
                const SizedBox(height: 6),
                Text(question.explanation, style: AppTypography.quizPanelBody),
              ],
            ),
          ),
          Container(
            color: AppColors.navy,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_outlined, size: 17, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FIND IT IN YOUR MATERIAL', style: AppTypography.quizPanelLabel(color: Colors.white.withValues(alpha: 0.55))),
                      const SizedBox(height: 2),
                      Text(question.sourceLocation, style: AppTypography.quizSourceValue),
                    ],
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

class _SaveAndLeaveSheet extends StatelessWidget {
  const _SaveAndLeaveSheet({
    required this.answered,
    required this.onLeave,
    required this.onKeepGoing,
  });

  final int answered;
  final VoidCallback onLeave;
  final VoidCallback onKeepGoing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 13),
          Text('Leave this session?', style: AppTypography.quizDialogTitle),
          const SizedBox(height: 8),
          Text(
            'You have answered $answered so far. We will keep this session so you can pick it up where you left off.',
            style: AppTypography.quizEmptyBody,
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Save and leave',
            onPressed: onLeave,
            height: 52,
            shadowColor: AppColors.navy.withValues(alpha: 0.10),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Keep going',
            variant: AppButtonVariant.outlinedNeutral,
            height: 48,
            onPressed: onKeepGoing,
          ),
        ],
      ),
    );
  }
}
