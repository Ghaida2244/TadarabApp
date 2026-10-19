import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The dimmed, full-screen "focus view" listing every attempt in one
/// session-stack group, latest first, each as a full card with its own
/// actions — opened by tapping a collapsed [SessionStackCard]. Feature-
/// agnostic: Quiz and Flashcards both use this, supplying [itemBuilder]
/// for each attempt's own full card.
///
/// Implemented as a plain overlay widget (a conditional child in the
/// screen's own [Stack], same pattern this app already uses for e.g. the
/// retake [GenerationLoadingOverlay]) rather than a route or
/// [OverlayEntry] — behaviourally identical (a full-screen dimmed layer
/// above the list, closable via the backdrop/close button/system back)
/// and simpler for the caller to drive from local state. The caller is
/// responsible for intercepting system back (e.g. via `PopScope`) to call
/// [onClose] instead of leaving the screen while this is open.
///
/// Exact values from docs/mockups/redesign-handoff_stacks_quiz_flashcard/
/// .../Tadarab - Retake Stacks.dc.html's hand-off spec (EXPANDED / MOTION
/// rows).
class SessionStackFocusView extends StatefulWidget {
  const SessionStackFocusView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.itemCount,
    required this.itemBuilder,
    required this.onClose,
    this.reducedMotion = false,
  });

  /// e.g. "3 attempts · Completed".
  final String title;

  /// The group's materials, shown under [title] (ellipsised).
  final String subtitle;

  final int itemCount;

  /// Builds attempt [index]'s full card (its own actions + delete) —
  /// already latest-first, same order as the collapsed stack's peeks.
  final IndexedWidgetBuilder itemBuilder;

  final VoidCallback onClose;

  /// Mirrors `MediaQuery.disableAnimations` — the caller reads that once
  /// and passes it through, so this widget stays test-friendly (no
  /// `MediaQuery` lookup of its own to fake in a widget test).
  final bool reducedMotion;

  @override
  State<SessionStackFocusView> createState() => _SessionStackFocusViewState();
}

class _SessionStackFocusViewState extends State<SessionStackFocusView>
    with TickerProviderStateMixin {
  // SPEC: "Each card goes from translateY 18 -> 0 and opacity 0 -> 1 over
  // 260ms (Curves.easeOutCubic), staggered 30ms, up to 4 cards. Reduced
  // motion: opacity only, 150ms, no stagger."
  static const _staggerMs = 30;
  static const _itemDurationMs = 260;
  static const _maxStaggeredItems = 4;
  static const _reducedDurationMs = 150;

  // A separate, short controller just for the closing fade — see
  // _requestClose. Not reversing [_entranceController] itself: that one's
  // duration already varies with the (possibly staggered) item count, and
  // SPEC calls for a flat "the reverse over 200ms" on collapse regardless.
  late final AnimationController _entranceController;
  late final AnimationController _closeController;
  bool _scrimVisible = false;

  int get _entranceDurationMs {
    if (widget.reducedMotion) return _reducedDurationMs;
    final staggeredItems = widget.itemCount.clamp(0, _maxStaggeredItems);
    final staggerSteps = staggeredItems == 0 ? 0 : staggeredItems - 1;
    return _itemDurationMs + staggerSteps * _staggerMs;
  }

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _entranceDurationMs),
    )..forward();
    _closeController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.reducedMotion ? _reducedDurationMs : 200,
      ),
    );
    // Fades the scrim in over the same window the design calls for (240ms
    // full motion / 150ms reduced) — kept on a separate flag rather than
    // tied to _entranceController, whose own duration stretches with the
    // item count when staggering, so the scrim doesn't visually lag behind
    // on a stack with many attempts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _scrimVisible = true);
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _closeController.dispose();
    super.dispose();
  }

  Future<void> _requestClose() async {
    setState(() => _scrimVisible = false);
    await _closeController.forward(from: 0);
    if (!mounted) return;
    widget.onClose();
  }

  Animation<double> _itemAnimation(int index) {
    if (widget.reducedMotion) return _entranceController;
    final totalMs = _entranceController.duration!.inMilliseconds;
    final delayMs = index.clamp(0, _maxStaggeredItems - 1) * _staggerMs;
    final startFraction = (delayMs / totalMs).clamp(0.0, 1.0);
    final endFraction = ((delayMs + _itemDurationMs) / totalMs).clamp(
      0.0,
      1.0,
    );
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(
        startFraction,
        endFraction < startFraction ? startFraction : endFraction,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _closeController,
        builder: (context, child) {
          return Opacity(opacity: 1 - _closeController.value, child: child);
        },
        // One tap target spanning the whole overlay — matches the
        // prototype's own structure, where the single scrim element wraps
        // the header and list and closes on any tap that isn't claimed by
        // a more specific descendant first (the close button, or a card's
        // own buttons/delete — each a separate, deeper GestureDetector
        // that wins the gesture arena for its own hit). A plain tap on the
        // header or on a card's background (not one of its buttons) is
        // deliberately NOT caught by anything more specific, so it falls
        // through to this and closes the view, same as tapping open space.
        child: GestureDetector(
          onTap: _requestClose,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              AnimatedOpacity(
                opacity: _scrimVisible ? 1 : 0,
                duration: Duration(
                  milliseconds: widget.reducedMotion ? 150 : 240,
                ),
                curve: Curves.easeOut,
                // rgba(11,15,91,.55)
                child: Container(color: AppColors.navy.withValues(alpha: 0.55)),
              ),
              Column(
                children: [
                  _FocusHeader(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    onClose: _requestClose,
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                      itemCount: widget.itemCount,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final animation = _itemAnimation(index);
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            final content = Opacity(
                              opacity: animation.value,
                              child: child,
                            );
                            if (widget.reducedMotion) return content;
                            return Transform.translate(
                              offset: Offset(0, 18 * (1 - animation.value)),
                              child: content,
                            );
                          },
                          child: widget.itemBuilder(context, index),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusHeader extends StatelessWidget {
  const _FocusHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xBFFFFFFF), // white @ 75% alpha
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
