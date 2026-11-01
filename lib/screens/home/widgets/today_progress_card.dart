import 'package:flutter/material.dart';

import '../../../logic/streak_row_logic.dart';
import '../../../services/home_data_service.dart';
import '../../../services/streak_service.dart' show dateOnly, effectiveStreak;
import '../../../theme/app_theme.dart';
import '../../../widgets/dashed_border.dart';

const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const _weekdayNames = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];

/// The day cell's own fixed-size colored box (see [_DayCell]) — never
/// scales with text, since it holds no text itself.
const _kDayCellHeight = 34.0;

/// Gap between a day cell's colored box and its weekday/date label below.
const _kCellLabelGap = 6.0;

/// The day label's own text style (see [_DayCell], which applies
/// [TextStyle.copyWith] for its actual color — the only part of this that
/// varies per cell, and irrelevant to layout) *before* Flutter merges it
/// onto the ambient `DefaultTextStyle`. Named once here, rather than
/// inline in both places, so [_weekRowHeight]'s measurement and the real
/// label use the exact same style and the exact same merge, rather than
/// two independent copies that could silently drift apart.
///
/// Deliberately leaves `fontFamily`/`height` unset, same as the real
/// label — both are meant to inherit from [AppTheme] (via
/// `DefaultTextStyle`), same as before this fix, so normal-scale
/// appearance is unchanged. [_dayLabelHeight] performs that same merge
/// itself before measuring, rather than hardcoding a guess at what it
/// would resolve to.
const _kDayLabelStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w900,
  letterSpacing: 0.02 * 10,
);

/// How much vertical room the weekday/date label under each day cell
/// needs, at [context]'s ambient (ultimately [textScaler]-scaled) style.
/// Measured with a real [TextPainter] against the *exact* style
/// [_DayCell]'s [Text] actually renders with — replicating [Text]'s own
/// `DefaultTextStyle.of(context).style.merge(style)` — rather than a
/// hand-picked fixed pixel budget. A fixed budget can't account for
/// whatever [AppTheme]/`DefaultTextStyle` contributes (such as a
/// Material-3 line-height multiplier): the original version of this
/// function undercounted by a sub-pixel amount once scaled — small enough
/// to round away at a scale factor of 1.0, but not on a real device's
/// larger "larger text" accessibility setting, which is exactly this
/// card's original bug. `maxLines: 1` matches the real label's own
/// `maxLines` (see [_DayCell]) — both exist so a long label on the
/// narrowest supported screens clips instead of wrapping, which would
/// double its real height past whatever this function returns.
double _dayLabelHeight(BuildContext context, TextScaler textScaler) {
  final mergedStyle = DefaultTextStyle.of(context).style.merge(
    _kDayLabelStyle,
  );
  final painter = TextPainter(
    text: TextSpan(text: 'W 31', style: mergedStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  return painter.height;
}

/// The pager's single row of 7 cells + their labels, so every page — real
/// data, or the loading placeholder — occupies exactly the same space and
/// the card never resizes while swiping *within* one build. Scales with
/// [textScaler] (clamped by [_kMaxTextScaleFactor], see [TodayProgressCard.
/// build]) so the label never overflows its share of the row at a larger
/// accessibility text size, while staying at the exact same height as
/// before this fix at a scale factor of 1.0.
double _weekRowHeight(BuildContext context, TextScaler textScaler) =>
    _kDayCellHeight + _kCellLabelGap + _dayLabelHeight(context, textScaler);

/// Caps how much this card's own text can grow under a large accessibility
/// text size. Without a cap, several of this card's labels sit in either a
/// fixed-size box (the day cells — see [_weekRowHeight]) or a `Row` with no
/// `Expanded`/`Flexible` to absorb extra width (the streak header), so an
/// unbounded system text scale (up to 2.0) would overflow them. 1.3 keeps
/// real growth for low-vision users — this card's own text styles are all
/// small (10-34px) — while staying inside the margin the surrounding
/// layout already has to spare.
const _kMaxTextScaleFactor = 1.3;

/// The streak panel's own vertical padding — same value above the header
/// ("N-day streak" line) and below the day labels, so the row doesn't sit
/// closer to one edge than the other.
const _kPanelPadding = 14.0;

/// Gap between two adjacent cells *inside* one week (see _WeekRow) — also
/// used, via _kPagePadding below, as the target gap *across* a week
/// boundary (the peeking cell and its neighbor), so the whole strip reads
/// as one continuously-spaced row regardless of where a page boundary
/// happens to fall.
const _kCellGap = 8.0;

/// Each page's own horizontal inset — half of [_kCellGap] on each side, so
/// two adjacent pages' insets sum to exactly [_kCellGap] at the boundary
/// between them (see _buildWeekPage). Matches the "half the cell gap on
/// each side" approach directly.
const _kPagePadding = _kCellGap / 2;

/// How far the pager's *viewport* escapes the panel's own [_kPanelPadding]
/// on each side, so an adjacent week's cells can peek through at the edges
/// (see _TodayProgressCardState.build). This is [_kPanelPadding] minus
/// [_kPagePadding] rather than [_kPanelPadding] itself: each page already
/// re-adds [_kPagePadding] of its own (see _buildWeekPage), and the two
/// need to net out to exactly [_kPanelPadding] so the *active* page's cells
/// still land flush under the header above it. A side effect of also
/// satisfying the cross-boundary-gap requirement: the visible peek sliver
/// is [_kPeekInset] minus the neighbor's own [_kPagePadding], i.e.
/// narrower than it would be with zero inter-page gap.
const _kPeekInset = _kPanelPadding - _kPagePadding;

/// The dark "Today's progress" card: today's question/flashcard split at
/// top, then a weekly (Sun-Sat) row of activity cells below that the
/// student can swipe horizontally to see earlier weeks. [currentStreak] is
/// [Student.currentStreak] (real, week-independent) as last written on a
/// session commit — [lastStudyDate] lets this re-derive whether it's still
/// actually alive as of [now] (see [effectiveStreak]) rather than trusting
/// a value that can go stale for days after a streak quietly breaks.
///
/// [weeklyProgress] is always the *current* week's data, fetched eagerly by
/// the caller (Home's existing `_reload()` path) — this card never
/// re-fetches it itself, so finishing a session and reloading Home updates
/// the current week exactly as before. Earlier weeks are fetched lazily,
/// one at a time as their page is first built, via [fetchWeek] — the same
/// `HomeDataService.fetchWeeklyProgress` query, just for a different week's
/// Sunday — and cached by week start for the life of this widget.
class TodayProgressCard extends StatefulWidget {
  const TodayProgressCard({
    super.key,
    required this.weeklyProgress,
    required this.currentStreak,
    required this.lastStudyDate,
    required this.now,
    required this.fetchWeek,
  });

  final WeeklyProgress weeklyProgress;
  final int currentStreak;
  final DateTime? lastStudyDate;
  final DateTime now;

  /// Fetches a single week's data for the Sunday [weekStart] — the caller
  /// binds this to `HomeDataService.fetchWeeklyProgress(uid, now:
  /// weekStart)`; no new query shape, no new index.
  final Future<WeeklyProgress> Function(DateTime weekStart) fetchWeek;

  @override
  State<TodayProgressCard> createState() => _TodayProgressCardState();
}

class _TodayProgressCardState extends State<TodayProgressCard> {
  PageController? _pageController;
  final Map<DateTime, WeeklyProgress> _cache = {};
  final Set<DateTime> _fetchingWeeks = {};

  DateTime get _currentWeekStart => startOfWeek(widget.now);

  @override
  void initState() {
    super.initState();
    _cache[_currentWeekStart] = widget.weeklyProgress;
  }

  @override
  void didUpdateWidget(covariant TodayProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent's existing _reload() path hands this a fresh
    // WeeklyProgress for the current week on every reload (e.g. after
    // finishing a session) — just refresh the cache entry for it; no
    // re-fetch of our own.
    _cache[_currentWeekStart] = widget.weeklyProgress;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _ensureFetching(DateTime weekStart) {
    if (_fetchingWeeks.contains(weekStart)) return;
    _fetchingWeeks.add(weekStart);
    widget
        .fetchWeek(weekStart)
        .then((result) {
          if (!mounted) return;
          setState(() {
            _cache[weekStart] = result;
            _fetchingWeeks.remove(weekStart);
          });
        })
        .catchError((Object _) {
          // Error-safe fallback: treat a failed earlier-week fetch as an
          // empty week rather than surfacing an error or retrying forever.
          if (!mounted) return;
          setState(() {
            _cache[weekStart] = WeeklyProgress.empty(weekStart);
            _fetchingWeeks.remove(weekStart);
          });
        });
  }

  void _backToCurrentWeek() {
    final controller = _pageController;
    if (controller == null) return;
    if (MediaQuery.of(context).disableAnimations) {
      controller.jumpToPage(0);
    } else {
      controller.animateToPage(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(widget.now);
    final todayCount = widget.weeklyProgress.dayForDate(today);
    final displayedStreak = effectiveStreak(
      storedStreak: widget.currentStreak,
      lastStudyDate: widget.lastStudyDate,
      now: widget.now,
    );

    // Clamp this card's own effective text scale (see _kMaxTextScaleFactor)
    // — applied via a MediaQuery override rather than per-Text, so every
    // label inside this card (including ones the pager's inner LayoutBuilder
    // builds lazily) is covered without threading a TextScaler through each
    // one individually. A Builder gets a BuildContext under the override so
    // _weekRowHeight below reads the *clamped* scaler, not the ambient one.
    final clampedTextScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: _kMaxTextScaleFactor);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: clampedTextScaler),
      child: Builder(
        builder: (context) => _buildCard(
          context,
          todayCount: todayCount,
          displayedStreak: displayedStreak,
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required DailyStudyCount todayCount,
    required int displayedStreak,
  }) {
    final weekRowHeight = _weekRowHeight(
      context,
      MediaQuery.textScalerOf(context),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(color: AppColors.navyShadow, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Today's progress",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TodayStat(value: todayCount.questionCount, label: 'questions'),
              Container(
                width: 2,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              _TodayStat(value: todayCount.flashcardCount, label: 'flashcards'),
            ],
          ),
          const SizedBox(height: 16),
          // The panel itself carries no blanket padding any more (unlike
          // before) — the header gets its own top/side padding below, and
          // the pager is a direct, unpadded child so it can span the
          // panel's full width (see the LayoutBuilder below) and let an
          // adjacent week's cells peek through at the edges, clipped at
          // the panel's own rounded corners rather than an inner inset.
          Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            // Everything below is inside one LayoutBuilder — deliberately
            // including the header, not just the pager — so _pageController
            // is already assigned by the time _StreakHeader is constructed,
            // on every build including the very first one. Splitting the
            // header out of the LayoutBuilder would mean its *first* build
            // always sees a null controller (since the Column's children
            // are all constructed before any of them actually run their own
            // build), and nothing would ever force a second build to fix
            // that up — the header would be permanently stuck showing the
            // current week's label regardless of swiping.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fullWidth = constraints.maxWidth;
                // The active page's own width needs to be fullWidth minus
                // the same 14px inset on each side the header above it
                // uses, so its cells land flush under it; whatever's left
                // over either side is exactly the peek of the neighboring
                // week.
                final viewportFraction = fullWidth > _kPeekInset * 2
                    ? ((fullWidth - _kPeekInset * 2) / fullWidth).clamp(
                        0.5,
                        1.0,
                      )
                    : 1.0;
                _pageController ??= PageController(
                  viewportFraction: viewportFraction,
                );
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _kPanelPadding,
                        _kPanelPadding,
                        _kPanelPadding,
                        0,
                      ),
                      child: _StreakHeader(
                        streakLabel: '$displayedStreak-day streak',
                        weekStart: _currentWeekStart,
                        onBackToCurrent: _backToCurrentWeek,
                        pageController: _pageController,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: weekRowHeight,
                      child: PageView.builder(
                        controller: _pageController,
                        // weeksBack increases with the index; reverse:true
                        // makes swiping right (per the design's own
                        // description) increase the index — i.e. go back a
                        // week. Page 0 (the start, unreachable to swipe
                        // past) is always the current week, so "future
                        // weeks aren't reachable" and "no limit on how far
                        // back" both fall out of plain Scrollable bounds —
                        // no page-count constant needed.
                        reverse: true,
                        itemBuilder: (context, weeksBack) =>
                            _buildWeekPage(weeksBack),
                      ),
                    ),
                    // Mirrors the header's own top _kPanelPadding above, so
                    // the day labels get the same breathing room below them
                    // that the streak line gets above it. Fixed/unconditional
                    // — never varies between the current and an earlier
                    // week, so it can't introduce the height jumpiness the
                    // header's own invisible-vs-visible button is already
                    // careful to avoid.
                    const SizedBox(height: _kPanelPadding),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildWeekPage(int weeksBack) {
    final weekStart = weekStartForWeeksBack(
      currentWeekStart: _currentWeekStart,
      weeksBack: weeksBack,
    );
    final cached = _cache[weekStart];
    Widget row;
    if (cached == null) {
      _ensureFetching(weekStart);
      row = _WeekRow.placeholder(weekStart: weekStart);
    } else {
      row = _WeekRow(weekStart: weekStart, now: widget.now, progress: cached);
    }
    // _kPagePadding on every page, loading or not, so the gap between this
    // page's own cells and whichever page is peeking in next to it is
    // exactly _kCellGap too — see _kPeekInset's own doc comment for the
    // full derivation.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
      child: row,
    );
  }
}

/// The streak panel's header row: the real streak count on the left,
/// either the current week's month (or month range) or an earlier week's
/// explicit day range on the right, and — only for an earlier week — a
/// circular "back to this week" button after it.
///
/// The button is always mounted (never removed from the tree) so the
/// header's height can never differ between the two states; when hidden
/// it's made fully inert — excluded from the semantics tree, ignoring
/// pointer events, and never focusable (it's a plain GestureDetector, not
/// a focusable Material widget, so there's no focus node to suppress in
/// the first place).
class _StreakHeader extends StatelessWidget {
  const _StreakHeader({
    required this.streakLabel,
    required this.weekStart,
    required this.onBackToCurrent,
    required this.pageController,
  });

  final String streakLabel;

  /// The *current* week's Sunday — only used to compute the month/range
  /// label when nothing's been swiped yet; once a page is actually built,
  /// [_HeaderRange] below reads the real page offset from [pageController]
  /// instead.
  final DateTime weekStart;
  final VoidCallback onBackToCurrent;
  final PageController? pageController;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          streakLabel,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        _HeaderRange(
          currentWeekStart: weekStart,
          pageController: pageController,
          onBackToCurrent: onBackToCurrent,
        ),
      ],
    );
  }
}

/// Rebuilds just the range label + back button whenever the pager's page
/// changes, via [pageController]'s own `ListenableBuilder` — keeps the
/// header in sync with whichever week is actually on screen (including
/// mid-drag) without the whole card needing to rebuild per scroll frame.
class _HeaderRange extends StatelessWidget {
  const _HeaderRange({
    required this.currentWeekStart,
    required this.pageController,
    required this.onBackToCurrent,
  });

  final DateTime currentWeekStart;
  final PageController? pageController;
  final VoidCallback onBackToCurrent;

  @override
  Widget build(BuildContext context) {
    final controller = pageController;
    if (controller == null) {
      // First frame, before the pager has measured itself and created a
      // controller — render the current week's own label so there's no
      // one-frame flash of nothing.
      return _rangeRow(weeksBack: 0);
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final weeksBack = (controller.hasClients && controller.page != null
                ? controller.page!
                : 0.0)
            .round();
        return _rangeRow(weeksBack: weeksBack);
      },
    );
  }

  Widget _rangeRow({required int weeksBack}) {
    final isCurrent = weeksBack == 0;
    final weekStart = weekStartForWeeksBack(
      currentWeekStart: currentWeekStart,
      weeksBack: weeksBack,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          streakHeaderLabel(weekStart: weekStart, isCurrent: isCurrent),
          style: AppTypography.helper.copyWith(
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(width: 4),
        ExcludeSemantics(
          excluding: isCurrent,
          child: IgnorePointer(
            ignoring: isCurrent,
            child: Opacity(
              opacity: isCurrent ? 0 : 1,
              child: _BackToCurrentWeekButton(onTap: onBackToCurrent),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackToCurrentWeekButton extends StatelessWidget {
  const _BackToCurrentWeekButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back to this week',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.keyboard_double_arrow_right,
            size: 13,
            color: AppColors.navy,
          ),
        ),
      ),
    );
  }
}

class _TodayStat extends StatelessWidget {
  const _TodayStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.helper.copyWith(
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

/// One week's row of 7 day cells. [progress] is null for a week that
/// hasn't finished loading yet — [placeholder] builds that state directly,
/// since it needs no activity data at all (every cell just renders dim,
/// with its correct date label — only [DayCellFillState.otherEmpty]
/// applies, since a week still loading is always an earlier, fully-past
/// week, never the current one).
class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.weekStart,
    required DateTime this.now,
    required WeeklyProgress this.progress,
  });

  const _WeekRow.placeholder({required this.weekStart})
    : now = null,
      progress = null;

  final DateTime weekStart;
  final DateTime? now;
  final WeeklyProgress? progress;

  @override
  Widget build(BuildContext context) {
    final today = now == null ? null : dateOnly(now!);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: _kCellGap),
          Expanded(child: _buildCell(i, today)),
        ],
      ],
    );
  }

  Widget _buildCell(int i, DateTime? today) {
    final date = addDaysCalendar(weekStart, i);
    final isToday = today != null && date == today;
    final isFuture = today != null && date.isAfter(today);
    final hasActivity = progress != null && progress!.days[i].combined > 0;

    final fillState = progress == null
        ? DayCellFillState.otherEmpty
        : dayCellFillState(hasActivity: hasActivity, isToday: isToday);
    final labelOpacity = progress == null
        ? 0.4
        : dayCellLabelOpacity(isToday: isToday, isFuture: isFuture);

    return _DayCell(
      letter: _dayLabels[i],
      dayOfMonth: date.day,
      fillState: fillState,
      labelOpacity: labelOpacity,
      semanticsLabel:
          '${_weekdayNames[date.weekday % 7]}, '
          '${monthAbbreviations[date.month - 1]} ${date.day}, '
          '${progress == null
              ? 'loading'
              : hasActivity
              ? 'studied'
              : 'no activity'}',
    );
  }
}

/// One day's cell — fill/border per [fillState] (see [DayCellFillState]),
/// label per [labelOpacity] (see [dayCellLabelOpacity]). No count, no
/// number: per the redesign, a cell only ever says whether that day had
/// any activity at all.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.letter,
    required this.dayOfMonth,
    required this.fillState,
    required this.labelOpacity,
    required this.semanticsLabel,
  });

  final String letter;
  final int dayOfMonth;
  final DayCellFillState fillState;
  final double labelOpacity;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final active = fillState == DayCellFillState.active;
    final todayEmpty = fillState == DayCellFillState.todayEmpty;

    Widget cell = Container(
      height: 34,
      width: double.infinity,
      decoration: BoxDecoration(
        color: active
            ? AppColors.red
            : (todayEmpty
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    if (!active) {
      cell = DashedRoundedBorder(
        color: Colors.white.withValues(alpha: todayEmpty ? 1 : 0.3),
        borderRadius: 12,
        child: cell,
      );
    }

    return Semantics(
      // container:true: without it, 7 adjacent leaf Semantics nodes with
      // nothing but a label get silently merged by the framework into one
      // node carrying all 7 labels joined by newlines — confirmed by
      // dumping the actual semantics tree while writing this; container
      // forces each cell to keep its own, separately-findable node.
      container: true,
      label: semanticsLabel,
      child: Column(
        children: [
          cell,
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Text(
              '$letter $dayOfMonth',
              // On the narrowest supported screens, a clamped-but-still-
              // larger accessibility text size can bring this label right
              // to the edge of the cell's own width (seven cells share one
              // row). Pinning it to one line — clipping rather than
              // wrapping — keeps _weekRowHeight's single-line budget valid
              // in that edge case instead of silently doubling the text's
              // real height and overflowing the row.
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: _kDayLabelStyle.copyWith(
                color: Colors.white.withValues(alpha: labelOpacity),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
