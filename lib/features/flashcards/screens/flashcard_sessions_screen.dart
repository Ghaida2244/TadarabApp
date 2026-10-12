import 'package:flutter/material.dart';

import '../../../models/flashcard_session.dart';
import '../../../services/flashcard_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/dashed_border.dart';
import '../../../widgets/scrollable_title_pill.dart';
import '../logic/flashcard_logic.dart';
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
    setState(() => _retakingSessionIds.add(session.sessionId));

    try {
      final outcome = await _service.retake(
        sessionId: session.sessionId,
        materialIds: session.materialIds,
        difficulties: session.difficultyLevels,
        count: session.numberOfFlashcards,
        customPrompt: session.customPrompt,
      );
      final flashcards = await _service.fetchFlashcards(session.sessionId);
      if (!mounted) return;
      setState(() => _retakingSessionIds.remove(session.sessionId));

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
            sessionId: session.sessionId,
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
      setState(() => _retakingSessionIds.remove(session.sessionId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _retakingSessionIds.remove(session.sessionId));
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<FlashcardSession>>(
        stream: _sessionsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('FlashcardSessionsScreen: watchSessions() error: ${snapshot.error}');
          }
          final sessions = snapshot.data ?? const <FlashcardSession>[];
          final inProgress = sortInProgressSessions(
            sessions.where((s) => !s.isSessionCompleted).toList(),
          );
          final completed = sortCompletedSessions(
            sessions.where((s) => s.isSessionCompleted).toList(),
          );

          return Column(
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
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                        children: [
                          if (inProgress.isNotEmpty) ...[
                            const _SectionLabel('IN PROGRESS'),
                            for (final session in inProgress)
                              _SessionRow(
                                session: session,
                                onResume: () => _resume(session),
                                onDelete: () => _delete(session),
                              ),
                          ],
                          if (completed.isNotEmpty) ...[
                            const _SectionLabel('COMPLETED'),
                            for (final session in completed)
                              _SessionRow(
                                session: session,
                                onViewSummary: () => _viewSummary(session),
                                onRetake: () => _retake(session),
                                onDelete: () => _delete(session),
                                isRetaking: _retakingSessionIds.contains(
                                  session.sessionId,
                                ),
                              ),
                          ],
                        ],
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
          );
        },
      ),
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
    this.onResume,
    this.onViewSummary,
    this.onRetake,
    required this.onDelete,
    this.isRetaking = false,
  });

  final FlashcardSession session;
  final VoidCallback? onResume;
  final VoidCallback? onViewSummary;
  final VoidCallback? onRetake;
  final VoidCallback onDelete;

  /// True while a Worker call for this session's Retake is in flight (up to
  /// 120s) — disables the button and shows a spinner, prevents double taps.
  final bool isRetaking;

  @override
  Widget build(BuildContext context) {
    final hue = session.isSessionCompleted ? AppColors.success : AppColors.red;
    final statusLabel = session.isSessionCompleted
        ? 'Completed'
        : 'In progress';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                      const SizedBox(height: 8),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                              const SizedBox(height: 7),
                              Text(
                                session.isSessionCompleted
                                    ? '${session.numberOfFlashcards} cards · ${session.knownCount} known'
                                    : '${session.knownCount + session.needsReviewCount} of ${session.numberOfFlashcards} reviewed',
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
                        _DeleteChip(onTap: onDelete),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: session.isSessionCompleted
                          ? 'View performance summary'
                          : 'Resume at card ${session.currentFlashcardIndex + 1}',
                      height: 46,
                      borderRadius: 14,
                      shadowColor: AppColors.navyShadow.withValues(alpha: 0.6),
                      onPressed: session.isSessionCompleted
                          ? onViewSummary
                          : onResume,
                    ),
                    if (session.isSessionCompleted) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'Retake flashcards',
                        variant: AppButtonVariant.outlinedBrand,
                        height: 46,
                        borderRadius: 14,
                        shadowColor: isRetaking
                            ? null
                            : AppColors.navy.withValues(alpha: 0.18),
                        loading: isRetaking,
                        onPressed: isRetaking ? null : onRetake,
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
