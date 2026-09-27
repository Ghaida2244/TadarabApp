import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/quiz_session.dart';
import '../../services/quiz_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/dashed_border.dart';
import 'quiz_navigation.dart';
import 'quiz_play_screen.dart';
import 'quiz_setup_screen.dart';
import 'performance_summary_screen.dart';
import 'widgets/quiz_icon_button.dart';

/// The Quiz sessions list for one course — empty state, or sessions grouped
/// IN PROGRESS above COMPLETED. Entry point into the whole Quiz feature
/// from Home's course picker. [service] is required (not defaulted) so the
/// caller decides real vs. fake — same pattern as [HomeScreen]/[HomeDataService].
class QuizSessionsScreen extends StatefulWidget {
  const QuizSessionsScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.service,
    this.onBackToCourse,
  });

  final String courseId;
  final String courseName;
  final VoidCallback? onBackToCourse;
  final QuizSessionService service;

  @override
  State<QuizSessionsScreen> createState() => _QuizSessionsScreenState();
}

class _QuizSessionsScreenState extends State<QuizSessionsScreen>
    with RouteAware {
  late Future<List<QuizSession>> _sessionsFuture;
  // For the materials badge on each card (design's navy-bordered, scrollable
  // pill listing which material(s) a session was generated from) — a
  // materialId -> title lookup, fetched once alongside the sessions.
  late Future<Map<String, String>> _materialTitlesFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = widget.service.fetchSessions(widget.courseId);
    _materialTitlesFuture = _loadMaterialTitles();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      quizSessionsRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    quizSessionsRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// RouteAware: fires when a route pushed above this one is popped and
  /// this screen becomes visible again — see quiz_navigation.dart for why
  /// this (not a `.then()` on the original push) is what actually reloads
  /// at the right time.
  @override
  void didPopNext() => _reload();

  Future<Map<String, String>> _loadMaterialTitles() async {
    // Best-effort, not a hard dependency: this only feeds the materials
    // badge on each session card, and _SessionCard already falls back to
    // "Material removed" for any id it can't resolve. It matters because
    // this Future's only consumer (build(), below) is nested inside
    // _sessionsFuture's own FutureBuilder and never gets built at all on
    // _sessionsFuture's error/empty branches — so if fetchMaterials also
    // failed there, that failure would otherwise go completely unhandled
    // (nothing ever attaches to this Future) instead of just showing
    // unlabeled badges.
    try {
      final materials = await widget.service.fetchMaterials(widget.courseId);
      return {for (final m in materials) m.materialId: m.title};
    } catch (_) {
      return const {};
    }
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _sessionsFuture = widget.service.fetchSessions(widget.courseId);
      _materialTitlesFuture = _loadMaterialTitles();
    });
  }

  Future<void> _confirmDelete(QuizSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteSessionDialog(),
    );
    if (confirmed != true) return;
    await widget.service.deleteSession(session.sessionId);
    _reload();
  }

  void _openSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizSetupScreen(
          courseId: widget.courseId,
          courseName: widget.courseName,
          service: widget.service,
        ),
      ),
    );
  }

  void _resume(QuizSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizPlayScreen(
          sessionId: session.sessionId,
          service: widget.service,
        ),
      ),
    );
  }

  void _viewSummary(QuizSession session) {
    // No explicit reload-on-return here: didPopNext (RouteAware, above)
    // covers this uniformly for every way back to this screen, so every
    // navigation method in this class follows the same fire-and-forget
    // push — one reload mechanism, not two racing/duplicating ones.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerformanceSummaryScreen(
          sessionId: session.sessionId,
          service: widget.service,
        ),
      ),
    );
  }

  Future<void> _retake(QuizSession session) async {
    try {
      final result = await widget.service.retakeSession(session.sessionId);
      if (!mounted) return;
      if (result.session.mode == Mode.exam) {
        // Nothing was written to Firestore for this retake yet — see
        // QuizSessionService.retakeSession's Exam branch — so there's
        // nothing to reload here; the previous completed attempt is
        // still exactly what's stored, until this retake's own final
        // Submit. Plays from the in-memory draft, same as a brand-new
        // Exam session.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuizPlayScreen.examDraft(
              session: result.session,
              questions: result.questions,
              service: widget.service,
            ),
          ),
        );
        return;
      }
      _reload();
      _resume(result.session);
    } on NoQuestionsGeneratedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.note ?? "Couldn't generate a retake from this material.",
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retake failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  QuizIconButton(
                    icon: Icons.arrow_back,
                    semanticLabel: 'Back to course',
                    onTap:
                        widget.onBackToCourse ??
                        () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'Quiz sessions',
                      style: AppTypography.quizHeaderTitle,
                    ),
                  ),
                  FutureBuilder<List<QuizSession>>(
                    future: _sessionsFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length;
                      return Text(
                        count == null
                            ? ''
                            : (count == 1 ? '1 session' : '$count sessions'),
                        style: AppTypography.quizHeaderMeta,
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<QuizSession>>(
                future: _sessionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(onRetry: _reload);
                  }
                  final sessions = snapshot.data ?? const [];
                  if (sessions.isEmpty) {
                    return const _EmptyState();
                  }
                  final entries = groupQuizSessions(sessions);
                  return FutureBuilder<Map<String, String>>(
                    future: _materialTitlesFuture,
                    builder: (context, materialsSnapshot) {
                      final materialTitles = materialsSnapshot.data ?? const {};
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final card = _SessionCard(
                            session: entry.session,
                            service: widget.service,
                            materialTitles: materialTitles,
                            onAct: entry.session.isSessionCompleted
                                ? () => _viewSummary(entry.session)
                                : () => _resume(entry.session),
                            onRetake: entry.session.isSessionCompleted
                                ? () => _retake(entry.session)
                                : null,
                            onDelete: () => _confirmDelete(entry.session),
                          );
                          if (!entry.showHeader) return card;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 14,
                                  bottom: 2,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      entry.headerLabel,
                                      style: AppTypography.quizEyebrow,
                                    ),
                                    const SizedBox(width: 9),
                                    const Expanded(
                                      child: Divider(
                                        color: AppColors.cardTint,
                                        height: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              card,
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
              color: Colors.white,
              child: AppButton(
                label: 'Start new quiz',
                variant: AppButtonVariant.accent,
                height: 56,
                borderRadius: 18,
                shadowColor: AppColors.navy.withValues(alpha: 0.10),
                onPressed: _openSetup,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: DashedRoundedBorder(
          borderRadius: 26,
          color: AppColors.borderLight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.cardTint,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.navy,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No sessions yet',
                  style: AppTypography.quizEmptyTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: Text(
                    'Generate a quiz from a lecture and it lands here — half-finished or done, you can always come back to it.',
                    style: AppTypography.quizEmptyBody,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load your quiz sessions.",
              style: AppTypography.quizEmptyTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Try again',
              onPressed: onRetry,
              height: 48,
              shadowColor: AppColors.navy.withValues(alpha: 0.10),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.service,
    required this.materialTitles,
    required this.onAct,
    required this.onRetake,
    required this.onDelete,
  });

  final QuizSession session;
  final QuizSessionService service;

  /// materialId -> title, for the materials badge. A session's own
  /// materialIds that aren't in this map (deleted since) are simply
  /// skipped — see [_materialsLabel].
  final Map<String, String> materialTitles;

  final VoidCallback onAct;
  final VoidCallback? onRetake;
  final VoidCallback onDelete;

  /// The comma-joined titles of this session's materials, straight from
  /// the design file's own logic (`matsLabel` in Tadarab Phase 2 -
  /// Quiz.dc.html): every materialId that still resolves to a title,
  /// joined with ", " — or "Material removed" if none do.
  String _materialsLabel() {
    final titles = session.materialIds
        .map((id) => materialTitles[id])
        .whereType<String>()
        .toList();
    return titles.isEmpty ? 'Material removed' : titles.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final complete = session.isSessionCompleted;
    final hue = complete ? AppColors.success : AppColors.red;
    final detail = complete
        ? '${session.numberOfQuestions} questions · ${session.correctAnswers} correct'
        : null; // in-progress detail is built below, via FutureBuilder
    final actLabel = complete
        ? 'View performance summary'
        : 'Resume at question ${session.currentQuestionIndex + 1}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardTint, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x140B0F5B), offset: Offset(0, 3)),
        ],
      ),
      // IntrinsicHeight: the left colored strip needs to stretch to match
      // the content's height, but CrossAxisAlignment.stretch alone needs a
      // bounded height to stretch against — this Row sits in a scrolling
      // list with no such bound, which throws "BoxConstraints forces an
      // infinite height" without it.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 7,
              decoration: BoxDecoration(
                color: hue,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(22),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 19),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MaterialsBadge(label: _materialsLabel()),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardTint,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      session.mode == Mode.learning
                                          ? 'LEARNING'
                                          : 'EXAM',
                                      style: AppTypography.quizBadge,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: hue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    complete ? 'Completed' : 'In progress',
                                    style: AppTypography.quizStatus.copyWith(
                                      color: hue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              if (detail != null)
                                Text(detail, style: AppTypography.quizCardTitle)
                              else
                                FutureBuilder<int>(
                                  future: service.countAnsweredQuestions(
                                    session.sessionId,
                                  ),
                                  builder: (context, snapshot) {
                                    final answered = snapshot.data;
                                    return Text(
                                      answered == null
                                          ? '… of ${session.numberOfQuestions} answered'
                                          : '$answered of ${session.numberOfQuestions} answered',
                                      style: AppTypography.quizCardTitle,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.errorBannerBackground,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: AppColors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: actLabel,
                      onPressed: onAct,
                      height: 46,
                      borderRadius: 14,
                      shadowColor: AppColors.navy.withValues(alpha: 0.10),
                    ),
                    if (onRetake != null) ...[
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'Retake quiz',
                        variant: AppButtonVariant.outlinedBrand,
                        onPressed: onRetake,
                        height: 46,
                        borderRadius: 14,
                        shadowColor: AppColors.navy.withValues(alpha: 0.10),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A session card's materials badge: a horizontally-scrollable pill listing
/// which material(s) the session was generated from, with a right-edge
/// fade hinting there's more to scroll when the label overflows. Built
/// directly from Tadarab Phase 2 - Quiz.dc.html's own markup — a light tint
/// pill (`#EEF0FF`) with navy text, not a solid navy fill; the "navy" in
/// its name refers to the (mostly hidden) wrapper and the text color.
class _MaterialsBadge extends StatelessWidget {
  const _MaterialsBadge({required this.label});

  final String label;

  static const _leftPad = 9.0;
  static const _rightPad = 22.0;

  // Vertical padding sized so the pill's *real, honestly-reported* height
  // is exactly 32px (14px measured text height + _vPad on each side) —
  // this is a genuinely bigger pill, not a hidden margin around a smaller
  // one. Two other approaches were tried and don't work: an invisible
  // SizedOverflowBox-based hit-slop can't work at all — Flutter's hit-
  // testing requires a render object's own reported size to contain the
  // touch point before it looks at children, so overflow *painting* never
  // extends *hit-testing*; wrapping the small pill in a taller SizedBox +
  // Center hits the same wall one level up — Center still hit-tests
  // against the *child's own* size, so the extra margin it reserves is
  // real layout space but not actually touch-responsive. Both confirmed
  // by failing tester.dragFrom() tests, not just reasoned through. 32px
  // was settled on with the user after confirming an invisible fix isn't
  // possible and that matching the nearby EXAM/LEARNING badge's own
  // height (measured: 22px) wouldn't meet the reliability floor either.
  static const _vPad = 9.0;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.quizBadge.copyWith(
      color: AppColors.navy,
      fontSize: 10,
    );

    // Flexible/Stack sizing alone never gives this box a *tighter* width
    // than the label needs — a Stack sizes to its largest non-positioned
    // child, and SingleChildScrollView happily reports wanting the full
    // incoming (loose) max, so the viewport ended up exactly as wide as
    // its own content and nothing ever overflowed it to actually scroll.
    // Capping this subtree's width at the label's own natural width (via
    // ConstrainedBox, not LayoutBuilder — LayoutBuilder can't sit under
    // the card's IntrinsicHeight, which needs to query this subtree's
    // intrinsic height) makes Flutter's normal constraint *intersection*
    // do the rest: nested inside Flexible (which already caps at the
    // available width), the box ends up at min(natural, available) —
    // hugging short content, and genuinely overflowing (so it can scroll)
    // when the label is longer than the available space.
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final naturalWidth = painter.width + _leftPad + _rightPad;

    return Row(
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: naturalWidth),
            child: Container(
              // The design's outer wrapper is navy, but its inner
              // scrollable area is an opaque tint that fully covers it —
              // the navy is essentially never visible. Filling the whole
              // pill with the tint directly matches what actually renders.
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: AppColors.cardTint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                      _leftPad,
                      _vPad,
                      _rightPad,
                      _vPad,
                    ),
                    child: Text(label, maxLines: 1, style: style),
                  ),
                  IgnorePointer(
                    child: Container(
                      width: 22,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppColors.cardTint.withValues(alpha: 0),
                            AppColors.cardTint.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeleteSessionDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.errorBannerBackground,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
            const SizedBox(height: 13),
            Text(
              'Delete this session?',
              style: AppTypography.quizDialogTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "You will lose your progress. This can't be undone.",
              style: AppTypography.quizDialogBody,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Delete session',
              variant: AppButtonVariant.accent,
              height: 52,
              shadowColor: AppColors.navy.withValues(alpha: 0.10),
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Keep it',
              variant: AppButtonVariant.outlinedNeutral,
              height: 46,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
