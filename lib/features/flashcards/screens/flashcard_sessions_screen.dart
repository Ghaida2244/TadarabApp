import 'package:flutter/material.dart';

import '../../../logic/session_stacking.dart';
import '../../../models/flashcard_session.dart';
import '../../../models/session.dart';
import '../../../services/flashcard_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/dashed_border.dart';
import '../../../widgets/generation_loading_overlay.dart';
import '../../../widgets/retake_label_pill.dart';
import '../../../widgets/scrollable_title_pill.dart';
import '../../../widgets/session_stack_card.dart';
import '../../../widgets/session_stack_focus_view.dart';
import '../widgets/delete_session_dialog.dart';
import '../widgets/header_circle_button.dart';
import 'flashcard_flip_deck_screen.dart';
import 'flashcard_performance_summary_screen.dart';
import 'flashcard_setup_screen.dart';

/// Colors from `Tadarab Phase 2b - Flashcards.dc.html`'s sessions screen,
/// not in `AppColors` (Flashcards-only, avoids touching the shared frozen
/// theme file).
const _kSectionDividerColor = Color(0xFFE6E9F7);
const _kEmptyStateDashColor = Color(0xFFC9CEE8);

/// Extra horizontal inset added around the card's button area (Resume, or
/// the Results/Retake row) on top of the card's own 15dp content padding —
/// placing the buttons at 15 + _kButtonSideInset dp from the card's left/
/// right edges, narrower than the card's full content width. Mirrors
/// quiz_sessions_screen.dart's identical constant — keep both in sync.
const _kButtonSideInset = 9.0;

/// Height of the button area's AppButton(s) — Resume, or Results/Retake —
/// taller than AppButton's usual compact height used elsewhere. Mirrors
/// quiz_sessions_screen.dart's identical constant — keep both in sync.
const _kButtonHeight = 46.0;

/// Screen 1: every flashcard session for one course, split into "IN
/// PROGRESS" and "COMPLETED" sections.
class FlashcardSessionsScreen extends StatefulWidget {
  const FlashcardSessionsScreen({
    super.key,
    required this.uid,
    required this.courseId,
    required this.email,
    this.service,
  });

  final String uid;
  final String courseId;
  final String email;

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final FlashcardService? service;

  @override
  State<FlashcardSessionsScreen> createState() =>
      _FlashcardSessionsScreenState();
}

class _FlashcardSessionsScreenState extends State<FlashcardSessionsScreen> {
  late final FlashcardService _service =
      widget.service ??
      FlashcardService(uid: widget.uid, courseId: widget.courseId);

  // Cached, not called fresh inline in the StreamBuilder below: a Stream
  // has no overridden `==`, so if `stream:` called _service.watchSessions()
  // directly in build(), ANY setState on this screen (not just _retry) would
  // hand StreamBuilder a new Stream instance every time, which it treats as
  // a genuinely different stream — unsubscribing, resubscribing, and
  // resetting to its "no data yet" state in between. That's harmless for a
  // deliberate retry, but a real bug for anything else: it was previously
  // flashing the whole screen back to empty/loading on every retake-loading
  // toggle. Only _retry() reassigns this, the same way CoursesListScreen's
  // _reload() reassigns its cached Future instead of creating a new one
  // inline on every build.
  late Stream<List<FlashcardSession>> _sessionsStream =
      _service.watchSessions();

  void _retry() => setState(() => _sessionsStream = _service.watchSessions());

  // Per-session, not one screen-wide flag — mirrors CourseDetailScreen's
  // per-row in-flight-delete pattern, so retaking one session doesn't
  // freeze every other row's button while the Worker call (up to 120s) is
  // in flight.
  final Set<String> _retakingSessionIds = {};

  // The session currently being retaken, kept only for the full-screen
  // loading overlay's fixed line (its settings) — set the moment a retake
  // starts, cleared once it finishes or fails.
  FlashcardSession? _retakingSource;

  // Which stack's focus view is open, if any — identified by section +
  // rootSessionId (see _keyFor), not the SessionStack object itself, since
  // a fresh one is rebuilt from the live stream's latest snapshot on every
  // build(). Unlike Quiz (a one-shot fetch, re-checked explicitly after a
  // delete), this screen's sessions come from watchSessions()'s live
  // stream, so a delete that shrinks a group to one attempt is picked up
  // automatically on the next snapshot — build() just needs to notice the
  // key no longer resolves to a real stack and clear it; see
  // _buildFocusViewIfOpen.
  String? _openStackKey;

  String _keyFor(SessionStack<FlashcardSession> group) =>
      '${group.isCompleted}:${group.top.rootSessionId}';

  void _openStack(SessionStack<FlashcardSession> group) {
    setState(() => _openStackKey = _keyFor(group));
  }

  void _closeStack() {
    if (_openStackKey == null) return;
    setState(() => _openStackKey = null);
  }

  void _openSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardSetupScreen(
          uid: widget.uid,
          courseId: widget.courseId,
          email: widget.email,
          service: _service,
        ),
      ),
    );
  }

  Future<void> _resume(FlashcardSession session) async {
    final flashcards = await _service.fetchFlashcards(session.sessionId);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardFlipDeckScreen(
          uid: widget.uid,
          courseId: widget.courseId,
          sessionId: session.sessionId,
          initialFlashcards: flashcards,
          initialIndex: session.currentFlashcardIndex,
          initialKnownCount: session.knownCount,
          initialNeedsReviewCount: session.needsReviewCount,
          service: _service,
        ),
      ),
    );
  }

  void _viewSummary(FlashcardSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardPerformanceSummaryScreen(
          uid: widget.uid,
          courseId: widget.courseId,
          sessionId: session.sessionId,
          knownCount: session.knownCount,
          needsReviewCount: session.needsReviewCount,
          earnedPoints: session.earnedPoints,
          service: _service,
        ),
      ),
    );
  }

  Future<void> _retake(FlashcardSession session) async {
    // Already retaking this session (double tap) — ignore, don't re-enter.
    if (_retakingSessionIds.contains(session.sessionId)) return;
    setState(() {
      _retakingSessionIds.add(session.sessionId);
      _retakingSource = session;
    });

    try {
      // Retake now creates a brand-new session rather than overwriting
      // this one — outcome.newSessionId is the one to actually open.
      final outcome = await _service.retake(
        sessionId: session.sessionId,
        materialIds: session.materialIds,
        difficulties: session.difficultyLevels,
        count: session.numberOfFlashcards,
        customPrompt: session.customPrompt,
      );
      final flashcards = await _service.fetchFlashcards(outcome.newSessionId);
      if (!mounted) return;
      setState(() {
        _retakingSessionIds.remove(session.sessionId);
        _retakingSource = null;
      });

      final shortfall = outcome.actualCount < outcome.requestedCount;
      final message = outcome.note ??
          (shortfall
              ? 'Generated ${outcome.actualCount} of '
                  '${outcome.requestedCount} requested.'
              : null);
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FlashcardFlipDeckScreen(
            uid: widget.uid,
            courseId: widget.courseId,
            sessionId: outcome.newSessionId,
            initialFlashcards: flashcards,
            initialIndex: 0,
            initialKnownCount: 0,
            initialNeedsReviewCount: 0,
            service: _service,
          ),
        ),
      );
    } on FlashcardFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _retakingSessionIds.remove(session.sessionId);
        _retakingSource = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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

  void _delete(FlashcardSession session) {
    showDeleteSessionDialog(
      context,
      isCompleted: session.isSessionCompleted,
      knownCount: session.knownCount,
      needsReviewCount: session.needsReviewCount,
      onDelete: () => _service.deleteSession(sessionId: session.sessionId),
    );
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
        backgroundColor: AppColors.background,
        body: StreamBuilder<List<FlashcardSession>>(
          stream: _sessionsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('FlashcardSessionsScreen: watchSessions() error: ${snapshot.error}');
            }
            final sessions = snapshot.data ?? const <FlashcardSession>[];
            final allGroups = groupSessionsIntoStacks<FlashcardSession>(
              sessions: sessions,
              isCompleted: (s) => s.isSessionCompleted,
              rootSessionId: (s) => s.rootSessionId,
              retakeNumber: (s) => s.retakeNumber,
              createdAt: (s) => s.createdAt,
              completedAt: (s) => s.completedAt,
            );
            final inProgress = allGroups.where((g) => !g.isCompleted).toList();
            final completed = allGroups.where((g) => g.isCompleted).toList();
            final listItems = _listItems(inProgress, completed);

            SessionStack<FlashcardSession>? openGroup;
            if (_openStackKey != null) {
              for (final g in allGroups) {
                if (_keyFor(g) == _openStackKey && g.isStack) {
                  openGroup = g;
                  break;
                }
              }
              if (openGroup == null) {
                // The live stream already reflects a delete that shrank
                // this group to one attempt (or removed it) — close
                // reactively. Deferred: build() can't call setState
                // synchronously.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _openStackKey != null) {
                    setState(() => _openStackKey = null);
                  }
                });
              }
            }

            return Stack(
              children: [
                Column(
                  children: [
                    _Header(
                      count: sessions.length,
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: snapshot.hasError
                          ? _ErrorState(onRetry: _retry)
                          : snapshot.connectionState == ConnectionState.waiting
                          ? const Center(child: CircularProgressIndicator())
                          : sessions.isEmpty
                          ? const _EmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                              itemCount: listItems.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) =>
                                  listItems[index],
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
                      child: AppButton(
                        label: 'Start new flashcards',
                        variant: AppButtonVariant.accent,
                        height: 56,
                        borderRadius: 18,
                        shadowColor: AppColors.redShadow.withValues(alpha: 0.6),
                        onPressed: _openSetup,
                      ),
                    ),
                  ],
                ),
                if (openGroup != null)
                  SessionStackFocusView(
                    title:
                        '${openGroup.sessions.length} attempts · '
                        '${openGroup.isCompleted ? 'Completed' : 'In progress'}',
                    subtitle: openGroup.top.materialTitles.join(', '),
                    itemCount: openGroup.sessions.length,
                    itemBuilder: (context, index) =>
                        _buildRow(openGroup!, isInFocusView: true, itemIndex: index),
                    onClose: _closeStack,
                    reducedMotion: MediaQuery.of(context).disableAnimations,
                  ),
                if (_retakingSource != null)
                  GenerationLoadingOverlay(
                    config: kFlashcardRetakeLoadingConfig,
                    fixedLine: buildGenerationFixedLine(
                      count: _retakingSource!.numberOfFlashcards,
                      noun: 'flashcards',
                      difficulties: _retakingSource!.difficultyLevels.toSet(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Flattens the IN PROGRESS/COMPLETED groups into one list of top-level
  /// `ListView.separated` items, each section's first item carrying its
  /// own [_SectionLabel] above the card (mirrors
  /// quiz_sessions_screen.dart's identical header+card pairing) — so every
  /// item, header-bearing or not, gets the exact same 12dp separator gap
  /// from `ListView.separated`, instead of each row supplying its own
  /// bottom margin. A per-row margin doesn't just add the wrong amount of
  /// spacing — when that row is the top card of a [SessionStackCard], the
  /// margin becomes part of the widget [SessionStackCard] measures to
  /// place its peek layers, throwing off their reserved space and offset
  /// (confirmed: the peek ended up sticking out ~20dp instead of the
  /// spec's 8dp, with the row's own margin consumed by that overshoot
  /// instead of ever being a real gap before the next card).
  List<Widget> _listItems(
    List<SessionStack<FlashcardSession>> inProgress,
    List<SessionStack<FlashcardSession>> completed,
  ) {
    Widget withHeader(String label, Widget card) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_SectionLabel(label), card],
    );

    return [
      for (var i = 0; i < inProgress.length; i++)
        if (i == 0)
          withHeader(
            'IN PROGRESS',
            _buildRow(inProgress[i], isInFocusView: false),
          )
        else
          _buildRow(inProgress[i], isInFocusView: false),
      for (var i = 0; i < completed.length; i++)
        if (i == 0)
          withHeader(
            'COMPLETED',
            _buildRow(completed[i], isInFocusView: false),
          )
        else
          _buildRow(completed[i], isInFocusView: false),
    ];
  }

  /// Builds one row — a plain card (lone session), a collapsed
  /// [SessionStackCard] (2+ sessions sharing a root in this section), or
  /// — when [isInFocusView] is true — [itemIndex]'s full card inside the
  /// open focus view (always full actions + delete, latest first, same
  /// order as the collapsed stack's own peeks).
  Widget _buildRow(
    SessionStack<FlashcardSession> group, {
    required bool isInFocusView,
    int itemIndex = 0,
  }) {
    final session = isInFocusView ? group.sessions[itemIndex] : group.top;
    final row = _SessionRow(
      session: session,
      sessionsInList: group.sessions,
      onResume: session.isSessionCompleted ? null : () => _resume(session),
      onViewSummary: session.isSessionCompleted
          ? () => _viewSummary(session)
          : null,
      onRetake: session.isSessionCompleted ? () => _retake(session) : null,
      onDelete: () => _delete(session),
      isRetaking: _retakingSessionIds.contains(session.sessionId),
      // A collapsed stack's top card shows no action buttons and no
      // delete of its own — tapping it opens the focus view instead,
      // where every attempt gets its own full card. A lone session or a
      // focus-view item renders exactly as a single card always has.
      isStackTop: !isInFocusView && group.isStack,
    );
    if (isInFocusView || !group.isStack) return row;
    return SessionStackCard(
      stackSize: group.sessions.length,
      cardBuilder: (_) => row,
      onOpenStack: () => _openStack(group),
    );
  }
}

/// Two-part header row, baseline-aligned: bold "Flashcards" on the left, a
/// separate dimmer live count on the right — per the design handoff, not a
/// single merged title.
class _Header extends StatelessWidget {
  const _Header({required this.count, required this.onBack});

  final int count;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: const BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HeaderCircleButton(icon: Icons.arrow_back_ios_new, onTap: onBack),
            const SizedBox(width: 13),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Flashcards',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    count == 1 ? '1 session' : '$count sessions',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xA6FFFFFF), // white @ 65% alpha
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.07 * 11,
              color: AppColors.placeholder,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Container(height: 2, color: _kSectionDividerColor)),
        ],
      ),
    );
  }
}

/// Mirrors CoursesListScreen's `_ErrorState` (courses_list_screen.dart):
/// a short message plus a Retry button, never silently falling back to the
/// empty state when the stream actually errored (e.g. a Firestore
/// `failed-precondition` from a missing composite index).
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load your sessions.",
              style: AppTypography.subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Retry',
              onPressed: onRetry,
              variant: AppButtonVariant.outlinedBrand,
              height: 46,
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
        padding: const EdgeInsets.all(22),
        child: DashedRoundedBorder(
          color: _kEmptyStateDashColor,
          borderRadius: 26,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cardTint,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.style_outlined,
                    size: 34,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'No sessions yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: 235,
                  child: Text(
                    'Turn a lecture into a deck and it lands here — half-reviewed '
                    'or finished, you can always come back to it.',
                    textAlign: TextAlign.center,
                    style: AppTypography.subtitle.copyWith(height: 1.55),
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

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.sessionsInList,
    this.onResume,
    this.onViewSummary,
    this.onRetake,
    required this.onDelete,
    this.isRetaking = false,
    this.isStackTop = false,
  });

  final FlashcardSession session;

  /// Every session currently loaded for this course — used to decide
  /// whether [session] (when it's an original) actually has a retake, per
  /// [sessionCardRetakeLabel].
  final List<FlashcardSession> sessionsInList;

  final VoidCallback? onResume;
  final VoidCallback? onViewSummary;
  final VoidCallback? onRetake;
  final VoidCallback onDelete;

  /// True while a Worker call for this session's Retake is in flight (up to
  /// 120s) — disables the button and shows a spinner, prevents double taps.
  final bool isRetaking;

  /// True when this card is rendered as a collapsed stack's top card
  /// (inside a [SessionStackCard]) rather than standalone or inside the
  /// focus view — per the Retake Stacks design's "Stack buttons: Hide"
  /// and "a collapsed stack has no delete button" decisions, it then shows
  /// neither its action buttons nor its delete button; tapping it opens
  /// the stack instead (handled by the [SessionStackCard] wrapper, not
  /// here). Mirrors Quiz's `_SessionCard.isStackTop`
  /// (quiz_sessions_screen.dart).
  final bool isStackTop;

  @override
  Widget build(BuildContext context) {
    final hue = session.isSessionCompleted ? AppColors.success : AppColors.red;
    final statusLabel = session.isSessionCompleted
        ? 'Completed'
        : 'In progress';
    // "Correct count: Hide" (approved Retake Stacks configuration) — a
    // completed card's result line drops the "· N known" half that was
    // here before; the in-progress line is untouched, since that switch
    // only ever affected the done branch.
    final detail = session.isSessionCompleted
        ? '${session.numberOfFlashcards} cards'
        : '${session.knownCount + session.needsReviewCount} of ${session.numberOfFlashcards} reviewed';
    final label = sessionCardRetakeLabel(session, sessionsInList);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardTint, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
                    if (session.materialTitles.isNotEmpty) ...[
                      // On its own full-width line so it can hug short
                      // content or grow up to the whole card width, without
                      // the delete chip eating into that budget.
                      ScrollableTitlePill(
                        text: session.materialTitles.join(', '),
                        style: AppTypography.helper.copyWith(
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // SPEC: label pill "sits before the mode
                              // tag" — Flashcards has no mode tag, so it
                              // just sits before the status dot+text.
                              // Wrap (not a plain Row) so a long label +
                              // status still fits on narrow widths.
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
                                  if (label != null) RetakeLabelPill(label),
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
                                        statusLabel,
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: hue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                detail,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                  color: AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // SPEC: "A collapsed stack has no delete button" —
                        // delete lives on each attempt inside the focus
                        // view instead; a lone card keeps its delete as
                        // today.
                        if (!isStackTop) _DeleteChip(onTap: onDelete),
                      ],
                    ),
                    // SPEC: "Stack buttons: Hide" — the collapsed stack's
                    // top card shows neither action button; tapping the
                    // card (handled by SessionStackCard) opens the focus
                    // view, where every attempt has its own full buttons.
                    if (!isStackTop) ...[
                      const SizedBox(height: 12),
                      // Narrower than the content above: extra
                      // _kButtonSideInset on each side on top of the
                      // card's own 15dp content padding.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _kButtonSideInset,
                        ),
                        child: session.isSessionCompleted
                            // "Completed buttons: Side by side" (approved
                            // configuration) — a taller, narrower, equal-
                            // width pair of buttons in a row — same as
                            // Quiz's completed row.
                            ? Row(
                                children: [
                                  Expanded(
                                    child: AppButton(
                                      label: 'Results',
                                      height: _kButtonHeight,
                                      borderRadius: 12,
                                      fontSize: 13,
                                      shadowColor: AppColors.navyShadow
                                          .withValues(alpha: 0.6),
                                      onPressed: onViewSummary,
                                    ),
                                  ),
                                  if (onRetake != null) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: AppButton(
                                        label: 'Retake',
                                        variant:
                                            AppButtonVariant.outlinedBrand,
                                        height: _kButtonHeight,
                                        borderRadius: 12,
                                        fontSize: 13,
                                        shadowColor: AppColors.navy
                                            .withValues(alpha: 0.18),
                                        onPressed: isRetaking
                                            ? null
                                            : onRetake,
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            // Same metrics as the completed row's buttons
                            // (confirmed to apply to the in-progress
                            // button too, matching Quiz's own Resume
                            // button).
                            : AppButton(
                                label:
                                    'Resume at card ${session.currentFlashcardIndex + 1}',
                                height: _kButtonHeight,
                                borderRadius: 12,
                                fontSize: 13,
                                shadowColor: AppColors.navyShadow.withValues(
                                  alpha: 0.6,
                                ),
                                onPressed: onResume,
                              ),
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

class _DeleteChip extends StatelessWidget {
  const _DeleteChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.errorBannerBackground,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.delete_outline, size: 16, color: AppColors.red),
      ),
    );
  }
}
