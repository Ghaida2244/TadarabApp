import 'package:flutter/material.dart';

import '../../logic/session_stacking.dart';
import '../../models/enums.dart';
import '../../models/quiz_session.dart';
import '../../models/session.dart';
import '../../services/quiz_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/generation_loading_overlay.dart';
import '../../widgets/scrollable_title_pill.dart';
import '../../widgets/session_stack_card.dart';
import '../../widgets/session_stack_focus_view.dart';
import 'quiz_navigation.dart';
import 'quiz_play_screen.dart';
import 'quiz_setup_screen.dart';
import 'performance_summary_screen.dart';
import 'widgets/quiz_icon_button.dart';

/// materialId -> title lookup for [session]'s own materials, comma-joined
/// — or "Material removed" if none resolve. Shared by [_SessionCard] and
/// the focus view's header subtitle, so both read the exact same label.
String materialsLabelFor(
  QuizSession session,
  Map<String, String> materialTitles,
) {
  final titles = session.materialIds
      .map((id) => materialTitles[id])
      .whereType<String>()
      .toList();
  return titles.isEmpty ? 'Material removed' : titles.join(', ');
}

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

  // Per-session, not one screen-wide flag — mirrors Flashcards'
  // FlashcardSessionsScreen, so retaking one session doesn't freeze every
  // other row's button while generation is in flight.
  final Set<String> _retakingSessionIds = {};

  // The session currently being retaken, kept only for the full-screen
  // loading overlay's fixed line (its settings) — set the moment a retake
  // starts, cleared once it finishes or fails.
  QuizSession? _retakingSource;

  // Which stack's focus view is open, if any — identified by section +
  // rootSessionId (see _keyFor) rather than holding the SessionStack
  // object itself, since a fresh one is rebuilt from the latest data on
  // every build(); re-resolving by this key lets the focus view track
  // deletes/retakes to the same group across reloads, and lets build()
  // detect when the group has shrunk to a single attempt (see
  // _confirmDelete) and close it automatically.
  String? _openStackKey;

  String _keyFor(SessionStack<QuizSession> group) =>
      '${group.isCompleted}:${group.top.rootSessionId}';

  void _openStack(SessionStack<QuizSession> group) {
    setState(() => _openStackKey = _keyFor(group));
  }

  void _closeStack() {
    if (_openStackKey == null) return;
    setState(() => _openStackKey = null);
  }

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

  /// [closeFocusIfGroupShrinks]: when this delete happens from inside an
  /// open focus view, re-checks that group after the delete and closes the
  /// view (back to a plain card) if it's down to a single attempt — see
  /// CLAUDE.md's Retake Stacks point 4.
  Future<void> _confirmDelete(
    QuizSession session, {
    bool closeFocusIfGroupShrinks = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteSessionDialog(),
    );
    if (confirmed != true) return;
    await widget.service.deleteSession(session.sessionId);

    if (!closeFocusIfGroupShrinks || _openStackKey == null) {
      _reload();
      return;
    }
    final fresh = await widget.service.fetchSessions(widget.courseId);
    if (!mounted) return;
    final stillStack = groupQuizSessions(
      fresh,
    ).any((e) => _keyFor(e.group) == _openStackKey && e.group.isStack);
    setState(() {
      _sessionsFuture = Future.value(fresh);
      _materialTitlesFuture = _loadMaterialTitles();
      if (!stillStack) _openStackKey = null;
    });
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
    // Already retaking this session (double tap) — ignore, don't re-enter.
    if (_retakingSessionIds.contains(session.sessionId)) return;
    setState(() {
      _retakingSessionIds.add(session.sessionId);
      _retakingSource = session;
    });

    try {
      final result = await widget.service.retakeSession(session.sessionId);
      if (!mounted) return;
      setState(() {
        _retakingSessionIds.remove(session.sessionId);
        _retakingSource = null;
      });

      final message = result.note ??
          (result.gotFewerThanRequested
              ? 'Generated ${result.session.numberOfQuestions} of '
                  '${result.requestedCount} requested.'
              : null);
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }

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
      setState(() {
        _retakingSessionIds.remove(session.sessionId);
        _retakingSource = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.note ?? "Couldn't generate a retake from this material.",
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _retakingSessionIds.remove(session.sessionId);
        _retakingSource = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retake failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _openStackKey == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeStack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              _buildBody(),
              _buildFocusViewIfOpen(context),
              if (_retakingSource != null)
                GenerationLoadingOverlay(
                  config: kQuizRetakeLoadingConfig,
                  fixedLine: buildGenerationFixedLine(
                    count: _retakingSource!.numberOfQuestions,
                    noun: 'questions',
                    difficulties: _retakingSource!.difficultyLevels.toSet(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resolves the currently-open stack (if any) from the latest loaded
  /// sessions and renders its [SessionStackFocusView]. A plain
  /// [SizedBox.shrink] when nothing's open, or when the key no longer
  /// matches a real stack (e.g. deleted down to one attempt elsewhere —
  /// see _confirmDelete, which already clears [_openStackKey] itself in
  /// that case; this is just the render-time mirror of the same check).
  Widget _buildFocusViewIfOpen(BuildContext context) {
    if (_openStackKey == null) return const SizedBox.shrink();
    return FutureBuilder<List<QuizSession>>(
      future: _sessionsFuture,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <QuizSession>[];
        if (sessions.isEmpty) return const SizedBox.shrink();
        final entries = groupQuizSessions(sessions);
        SessionStack<QuizSession>? openGroup;
        for (final entry in entries) {
          if (_keyFor(entry.group) == _openStackKey && entry.group.isStack) {
            openGroup = entry.group;
            break;
          }
        }
        if (openGroup == null) return const SizedBox.shrink();
        final group = openGroup;
        return FutureBuilder<Map<String, String>>(
          future: _materialTitlesFuture,
          builder: (context, materialsSnapshot) {
            final materialTitles = materialsSnapshot.data ?? const {};
            return SessionStackFocusView(
              title:
                  '${group.sessions.length} attempts · '
                  '${group.isCompleted ? 'Completed' : 'In progress'}',
              subtitle: materialsLabelFor(group.top, materialTitles),
              itemCount: group.sessions.length,
              itemBuilder: (context, index) {
                final session = group.sessions[index];
                return _SessionCard(
                  session: session,
                  sessionsInList: sessions,
                  service: widget.service,
                  materialTitles: materialTitles,
                  onAct: session.isSessionCompleted
                      ? () => _viewSummary(session)
                      : () => _resume(session),
                  onRetake: session.isSessionCompleted
                      ? () => _retake(session)
                      : null,
                  onDelete: () => _confirmDelete(
                    session,
                    closeFocusIfGroupShrinks: true,
                  ),
                  isRetaking: _retakingSessionIds.contains(session.sessionId),
                );
              },
              onClose: _closeStack,
              reducedMotion: MediaQuery.of(context).disableAnimations,
            );
          },
        );
      },
    );
  }

  Widget _buildBody() {
    return Column(
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
                          final group = entry.group;
                          final top = group.top;
                          final topCard = _SessionCard(
                            session: top,
                            sessionsInList: sessions,
                            service: widget.service,
                            materialTitles: materialTitles,
                            onAct: top.isSessionCompleted
                                ? () => _viewSummary(top)
                                : () => _resume(top),
                            onRetake: top.isSessionCompleted
                                ? () => _retake(top)
                                : null,
                            onDelete: () => _confirmDelete(top),
                            isRetaking: _retakingSessionIds.contains(
                              top.sessionId,
                            ),
                            // A collapsed stack's top card shows no action
                            // buttons and no delete of its own — tapping
                            // it opens the focus view instead, where every
                            // attempt gets its own full card. A lone
                            // session (group.isStack == false) renders
                            // exactly as it always has.
                            isStackTop: group.isStack,
                          );
                          final card = group.isStack
                              ? SessionStackCard(
                                  stackSize: group.sessions.length,
                                  cardBuilder: (_) => topCard,
                                  onOpenStack: () => _openStack(group),
                                )
                              : topCard;
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
    required this.sessionsInList,
    required this.service,
    required this.materialTitles,
    required this.onAct,
    required this.onRetake,
    required this.onDelete,
    this.isRetaking = false,
    this.isStackTop = false,
  });

  final QuizSession session;

  /// Every session currently loaded for this course — used to decide
  /// whether [session] (when it's an original) actually has a retake, per
  /// [sessionCardRetakeLabel].
  final List<QuizSession> sessionsInList;

  final QuizSessionService service;

  /// materialId -> title, for the materials badge. A session's own
  /// materialIds that aren't in this map (deleted since) are simply
  /// skipped — see [materialsLabelFor].
  final Map<String, String> materialTitles;

  final VoidCallback onAct;
  final VoidCallback? onRetake;
  final VoidCallback onDelete;

  /// True while a Worker call for this session's Retake is in flight —
  /// disables the button and shows a spinner, prevents double taps.
  final bool isRetaking;

  /// True when this card is rendered as a collapsed stack's top card
  /// (inside a [SessionStackCard]) rather than standalone or inside the
  /// focus view — per the Retake Stacks design's "Stack buttons: Hide"
  /// and "a collapsed stack has no delete button" decisions, it then shows
  /// neither its action buttons nor its delete button; tapping it opens
  /// the stack instead (handled by the [SessionStackCard] wrapper, not
  /// here).
  final bool isStackTop;

  @override
  Widget build(BuildContext context) {
    final complete = session.isSessionCompleted;
    final hue = complete ? AppColors.success : AppColors.red;
    // "Correct count: Hide" (approved Retake Stacks configuration) — a
    // completed card's result line drops the "· N correct" half that was
    // here before; the in-progress line (via the FutureBuilder below) is
    // untouched, since that switch only ever affected the done branch.
    final detail = complete ? '${session.numberOfQuestions} questions' : null;
    final label = sessionCardRetakeLabel(session, sessionsInList);

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
                    ScrollableTitlePill(
                      text: materialsLabelFor(session, materialTitles),
                      style: AppTypography.helper.copyWith(
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // SPEC: label pill "sits before the mode
                              // tag"; wrap (not a plain Row) so a long
                              // label + mode + status still fits on
                              // narrow widths instead of overflowing.
                              Wrap(
                                spacing: 7,
                                runSpacing: 4,
                                crossAxisAlignment:
                                    WrapCrossAlignment.center,
                                children: [
                                  // "Original"/"Retake N" — shown only
                                  // once this session actually has a
                                  // retake relationship; the logic lives
                                  // in sessionCardRetakeLabel, unchanged
                                  // by this redesign.
                                  if (label != null) _RetakeLabelPill(label),
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
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                        style: AppTypography.quizStatus
                                            .copyWith(color: hue),
                                      ),
                                    ],
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
                        // SPEC: "A collapsed stack has no delete button" —
                        // delete lives on each attempt inside the focus
                        // view instead; a lone card keeps its delete as
                        // today.
                        if (!isStackTop)
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
                    // SPEC: "Stack buttons: Hide" — the collapsed stack's
                    // top card shows neither action button; tapping the
                    // card (handled by SessionStackCard) opens the focus
                    // view, where every attempt has its own full buttons.
                    if (!isStackTop) ...[
                      const SizedBox(height: 12),
                      if (complete)
                        // "Completed buttons: Side by side" (approved
                        // configuration) — a shorter pair of buttons in a
                        // row, per the hand-off's exact compact-button
                        // metrics (40dp height, 12dp radius, 13sp labels,
                        // 1.35:1 flex ratio) and shortened labels.
                        Row(
                          children: [
                            Expanded(
                              flex: 135,
                              child: AppButton(
                                label: 'View summary',
                                onPressed: onAct,
                                height: 40,
                                borderRadius: 12,
                                fontSize: 13,
                                shadowColor: AppColors.navy.withValues(
                                  alpha: 0.10,
                                ),
                              ),
                            ),
                            if (onRetake != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 100,
                                child: AppButton(
                                  label: 'Retake',
                                  variant: AppButtonVariant.outlinedBrand,
                                  onPressed: isRetaking ? null : onRetake,
                                  height: 40,
                                  borderRadius: 12,
                                  fontSize: 13,
                                  shadowColor: AppColors.navy.withValues(
                                    alpha: 0.10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      else
                        // Same compact metrics as the completed row's
                        // buttons (SessionStackCard.dc.html: btnH/btnR/
                        // btnFs depend only on compactButtons, not on
                        // a.done) — confirmed to apply here too.
                        AppButton(
                          label:
                              'Resume at question ${session.currentQuestionIndex + 1}',
                          onPressed: onAct,
                          height: 40,
                          borderRadius: 12,
                          fontSize: 13,
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

/// The "ORIGINAL" / "RETAKE N" pill — SPEC: 'uppercase, 10sp / w900,
/// tracking .04em, navy #0B0F5B fill, white text, pill radius 999, padding
/// 4 × 9. Sits before the mode tag.' The label TEXT itself still comes
/// from [sessionCardRetakeLabel], unchanged by this redesign — only the
/// rendering (a filled pill inline with the mode badge, instead of plain
/// grey text on its own line) is new.
class _RetakeLabelPill extends StatelessWidget {
  const _RetakeLabelPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.quizBadge.copyWith(color: Colors.white),
      ),
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
