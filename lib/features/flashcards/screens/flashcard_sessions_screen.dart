import 'package:flutter/material.dart';

import '../../../models/flashcard_session.dart';
import '../../../services/flashcard_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/dashed_border.dart';
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

const _kMaterialPillHPadding = 11.0;
const _kMaterialPillVPadding = 6.0;

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
    await _service.retake(sessionId: session.sessionId);
    final flashcards = await _service.fetchFlashcards(session.sessionId);
    if (!mounted) return;
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
        stream: _service.watchSessions(),
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? const <FlashcardSession>[];
          final inProgress = sessions
              .where((s) => !s.isSessionCompleted)
              .toList();
          final completed = sessions
              .where((s) => s.isSessionCompleted)
              .toList();

          return Column(
            children: [
              _Header(
                count: sessions.length,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
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
  });

  final FlashcardSession session;
  final VoidCallback? onResume;
  final VoidCallback? onViewSummary;
  final VoidCallback? onRetake;
  final VoidCallback onDelete;

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
                      _MaterialTitlePill(
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
                        shadowColor: AppColors.navy.withValues(alpha: 0.18),
                        onPressed: onRetake,
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

/// A pill that hugs [text] up to the full width its parent offers; if the
/// text is still too wide even at that full width, it becomes exactly that
/// width and the text scrolls horizontally inside it by drag (a plain
/// `SingleChildScrollView`, not auto-animating) — never wraps to a second
/// line or truncates with an ellipsis.
///
/// The "available width" is read from an invisible, full-width sizing box
/// via a `GlobalKey` + `RenderBox` in a post-frame callback, not a
/// `LayoutBuilder`: this widget sits inside an `IntrinsicHeight` (see
/// `_SessionRow`'s stretch `Row` for the colored side strip), and a
/// `LayoutBuilder` inside an intrinsic-sizing pass throws a storm of
/// `RenderFlex`/`debugCheckForParentData` assertions and hangs
/// `pumpAndSettle` — a failure hit and fixed here before. Reading a
/// `RenderBox` after layout has already finished sidesteps that class of
/// bug entirely: the first frame always renders the plain, intrinsically-
/// safe hugging layout, and only a later frame may switch to the
/// fixed-width scrolling one.
class _MaterialTitlePill extends StatefulWidget {
  const _MaterialTitlePill({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_MaterialTitlePill> createState() => _MaterialTitlePillState();
}

class _MaterialTitlePillState extends State<_MaterialTitlePill> {
  final _measureKey = GlobalKey();

  late final double _textWidth = _measure();
  double? _availableWidth;

  double _measure() {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_checkAvailableWidth);
  }

  void _checkAvailableWidth(Duration _) {
    if (!mounted) return;
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (_availableWidth != box.size.width) {
      setState(() => _availableWidth = box.size.width);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentWidth = _textWidth + _kMaterialPillHPadding * 2;
    final needsScroll =
        _availableWidth != null && contentWidth > _availableWidth!;

    final text = Text(
      widget.text,
      style: widget.style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    );

    final pill = Container(
      width: needsScroll ? _availableWidth : null,
      padding: const EdgeInsets.symmetric(
        horizontal: _kMaterialPillHPadding,
        vertical: _kMaterialPillVPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: needsScroll
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: text)
          : text,
    );

    // The measuring box spans the full width offered by the parent Column
    // (invisible — no decoration of its own) so a later frame can learn
    // the true available width; the visible pill inside it still hugs its
    // own content via Align, which doesn't force its child to fill.
    return SizedBox(
      key: _measureKey,
      width: double.infinity,
      child: Align(alignment: Alignment.centerLeft, child: pill),
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
