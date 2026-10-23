import 'package:flutter/material.dart';

import '../../../models/calendar_event.dart';
import '../../../models/course.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/event_time.dart';
import '../../../widgets/dashed_border.dart';
import '../calendar_styles.dart';

/// The bottom sheet listing one day's events, opened by tapping a day that
/// has events on the month grid.
///
/// Purely presentational: deleting is confirmed and performed by the
/// Calendar screen via [onDeleteRequested], so this widget stays testable
/// without a Firestore or a dialog route.
class DayEventsSheet extends StatelessWidget {
  const DayEventsSheet({
    super.key,
    required this.day,
    required this.events,
    required this.coursesById,
    required this.onDeleteRequested,
  });

  final DateTime day;

  /// The day's events. Sorted by time here rather than by the caller, so
  /// every entry point gets the handoff's chronological order.
  final List<CalendarEvent> events;

  /// Course lookup for the name shown under an event.
  ///
  /// A `courseId` with no entry here is expected, not exceptional: the
  /// course may have been deleted since, or the lookup may have failed. In
  /// either case the row simply omits the course line.
  final Map<String, Course> coursesById;

  final ValueChanged<CalendarEvent> onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    final sorted = [...events]
      ..sort((a, b) => a.eventTime.compareTo(b.eventTime));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatLongDate(day), style: CalendarText.sheetDate),
                      const SizedBox(height: 2),
                      Text(
                        formatEventCount(sorted.length),
                        style: CalendarText.sheetCount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _CloseChip(onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (sorted.isEmpty) const _SheetEmptyState(),
                    for (final event in sorted) ...[
                      _EventRow(
                        event: event,
                        course: event.courseId == null
                            ? null
                            : coursesById[event.courseId],
                        onDelete: () => onDeleteRequested(event),
                      ),
                      const SizedBox(height: 10),
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

/// The 34px grey circle that dismisses the sheet.
class _CloseChip extends StatelessWidget {
  const _CloseChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.cardTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 15, color: AppColors.navy),
        ),
      ),
    );
  }
}

/// Shown when the sheet is open on a day with nothing on it.
///
/// Unreachable from the month grid, which only opens days that have events
/// — in the handoff too. Kept because the sheet is also left open after a
/// delete, and because it costs nothing to be correct if that ever changes.
class _SheetEmptyState extends StatelessWidget {
  const _SheetEmptyState();

  @override
  Widget build(BuildContext context) {
    return DashedRoundedBorder(
      color: AppColors.textOnDisabled,
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
        child: Column(
          children: [
            Text(
              'No events on this day',
              style: CalendarText.sheetEmptyTitle,
            ),
            const SizedBox(height: 9),
            Text(
              'Add one and it will appear here with its color.',
              textAlign: TextAlign.center,
              style: CalendarText.sheetEmptyBody,
            ),
          ],
        ),
      ),
    );
  }
}

/// One event: a full-height colour bar, the name, its course (when the
/// course still exists), the time plus any reminder, and a tinted delete
/// button.
class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.course,
    required this.onDelete,
  });

  final CalendarEvent event;

  /// Null when the event has no course, or when its course has since been
  /// deleted — the row then shows no course line.
  final Course? course;

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hue = parseHexColor(event.color);
    final reminder = eventReminderSummary(event);

    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardTint, width: 2),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              margin: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: hue,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 13, 13, 15),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            event.eventName,
                            style: CalendarText.eventName,
                          ),
                          if (course != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              course!.courseName,
                              style: CalendarText.eventCourse(hue),
                            ),
                          ],
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  [
                                    formatStoredTimeForDisplay(
                                      event.eventTime,
                                    ),
                                    ?reminder,
                                  ].join(' · '),
                                  style: CalendarText.eventMeta,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _DeleteButton(onTap: onDelete),
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

/// The 34×34 pink-tinted trash button on an event row.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Delete event',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.errorBannerBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.delete_outline,
            size: 16,
            color: AppColors.red,
          ),
        ),
      ),
    );
  }
}
