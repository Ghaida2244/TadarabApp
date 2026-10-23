import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/event_time.dart';
import '../calendar_styles.dart';

/// The navy header at the top of the Calendar tab.
///
/// Two rows. The top row ("Calendar", the month/year-view toggle and the
/// red Add Event pill) is always visible. The second row switches with the
/// view: month arrows plus the month name in month view, year arrows plus
/// the year in year view — and, in month view only, the "Back to today"
/// pill whenever the student has navigated away from the current month.
class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    super.key,
    required this.month,
    required this.isYearView,
    required this.showBackToToday,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleView,
    required this.onBackToToday,
    required this.onAddEvent,
  });

  /// The month currently being viewed; its year labels the year view.
  final DateTime month;

  /// Whether the year view is showing.
  final bool isYearView;

  /// Whether the viewed month differs from the month containing "today".
  final bool showBackToToday;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToggleView;
  final VoidCallback onBackToToday;
  final VoidCallback onAddEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 18),
            Row(
              children: [
                // Flexible so the title yields to the two fixed-width
                // actions rather than overflowing the row at phone widths;
                // the handoff's CSS shrinks it the same way.
                Expanded(
                  child: Text(
                    'Calendar',
                    overflow: TextOverflow.ellipsis,
                    style: CalendarText.headerTitle,
                  ),
                ),
                const SizedBox(width: 12),
                _ViewToggleButton(
                  isYearView: isYearView,
                  onTap: onToggleView,
                ),
                const SizedBox(width: 9),
                _AddEventButton(onTap: onAddEvent),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _HeaderArrow(
                  icon: Icons.chevron_left,
                  semanticLabel:
                      isYearView ? 'Previous year' : 'Previous month',
                  onTap: onPrevious,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      isYearView
                          ? '${month.year}'
                          : formatMonthTitle(month),
                      style: CalendarText.headerMonth,
                    ),
                  ),
                ),
                _HeaderArrow(
                  icon: Icons.chevron_right,
                  semanticLabel: isYearView ? 'Next year' : 'Next month',
                  onTap: onNext,
                ),
              ],
            ),
            // Month view only: the handoff nests this inside its monthMode
            // branch, so the year view never offers it.
            if (!isYearView && showBackToToday) ...[
              const SizedBox(height: 16),
              _BackToTodayPill(onTap: onBackToToday),
            ],
          ],
        ),
      ),
    );
  }
}

/// Switches between the month grid and the year overview. Turns solid red
/// while the year view is active, and its glyph flips between a grid of
/// squares (go to year) and a calendar page (come back to the month).
class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({required this.isYearView, required this.onTap});

  final bool isYearView;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isYearView ? 'Show month view' : 'Show year view',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isYearView
                ? AppColors.red
                : Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isYearView ? Icons.calendar_today_outlined : Icons.grid_view,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// The red "+ Add Event" pill, with the design's hard red drop shadow.
class _AddEventButton extends StatelessWidget {
  const _AddEventButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.redShadow.withValues(alpha: 0.6),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 15, color: Colors.white),
            const SizedBox(width: 7),
            Text('Add Event', style: CalendarText.headerAction),
          ],
        ),
      ),
    );
  }
}

/// A 36px translucent circle holding a chevron.
class _HeaderArrow extends StatelessWidget {
  const _HeaderArrow({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
      ),
    );
  }
}

/// "Back to today" — a bordered pill centred under the month row, shown
/// only while the viewed month isn't the current one.
class _BackToTodayPill extends StatelessWidget {
  const _BackToTodayPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule,
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(width: 7),
            Text('Back to today', style: CalendarText.backToToday),
          ],
        ),
      ),
    );
  }
}
