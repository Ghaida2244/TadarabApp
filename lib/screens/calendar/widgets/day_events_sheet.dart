import 'package:flutter/material.dart';

import '../../../models/calendar_event.dart';
import '../../../models/course.dart';
import '../../../services/streak_service.dart' show dateOnly;
import '../../../theme/app_theme.dart';
import '../../../utils/event_time.dart';
import '../../../widgets/dashed_border.dart';
import '../calendar_styles.dart';

/// Opacity applied to an already-finished event's colour bar and text (not
/// its delete button, which stays fully opaque and usable) — light enough
/// to read as "done" but still clearly legible.
const _kFinishedOpacity = 0.5;

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
    this.now,
  });

  final DateTime day;

  /// The day's events. Grouped/sorted here rather than by the caller, so
  /// every entry point gets the same rule — see [build]'s own doc comment
  /// on the grouping itself.
  final List<CalendarEvent> events;

  /// Course lookup for the name shown under an event.
  ///
  /// A `courseId` with no entry here is expected, not exceptional: the
  /// course may have been deleted since, or the lookup may have failed. In
  /// either case the row simply omits the course line.
  final Map<String, Course> coursesById;

  final ValueChanged<CalendarEvent> onDeleteRequested;

  /// Defaults to [DateTime.now] so a test can inject a fixed clock —
  /// matches the Calendar screen's own `widget.now ?? DateTime.now()`
  /// pattern. Computed once, when the sheet is built: the grouping below
  /// is a point-in-time snapshot, not a live timer.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final effectiveNow = now ?? DateTime.now();
    final isToday = dateOnly(day) == dateOnly(effectiveNow);
    final isPast = dateOnly(day).isBefore(dateOnly(effectiveNow));

    List<CalendarEvent> byStart(Iterable<CalendarEvent> list) =>
        [...list]..sort(
          (a, b) => eventDateTime(a).compareTo(eventDateTime(b)),
        );

    // "Finished" means the event's full start (eventDate + eventTime) is
    // at or before `now` — eventDateTime already treats an unparsable
    // stored time as midnight. Today splits into two chronological
    // groups with not-yet-started first; a past day is entirely
    // "finished" (still plain chronological order); a future day has
    // nothing finished yet.
    final List<CalendarEvent> notStarted;
    final List<CalendarEvent> finished;
    if (isToday) {
      notStarted = byStart(
        events.where((e) => eventDateTime(e).isAfter(effectiveNow)),
      );
      finished = byStart(
        events.where((e) => !eventDateTime(e).isAfter(effectiveNow)),
      );
    } else if (isPast) {
      notStarted = const [];
      finished = byStart(events);
    } else {
      notStarted = byStart(events);
      finished = const [];
    }
    final total = notStarted.length + finished.length;
    // Only today's split ever shows a divider — a past day's "finished"
    // group is simply everything, and a future day's is simply nothing,
    // so this same emptiness check naturally suppresses it there too.
    final showDivider = notStarted.isNotEmpty && finished.isNotEmpty;

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
                        formatEventCount(total),
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
                    if (total == 0) const _SheetEmptyState(),
                    for (final event in notStarted) ...[
                      _EventRow(
                        event: event,
                        course: event.courseId == null
                            ? null
                            : coursesById[event.courseId],
                        onDelete: () => onDeleteRequested(event),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (showDivider) ...[
                      const _FinishedDivider(),
                      const SizedBox(height: 10),
                    ],
                    for (final event in finished) ...[
                      _EventRow(
                        event: event,
                        course: event.courseId == null
                            ? null
                            : coursesById[event.courseId],
                        onDelete: () => onDeleteRequested(event),
                        dimmed: true,
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

/// The thin grey rule + "Finished" label separating today's not-yet-
/// started events from its already-started ones.
class _FinishedDivider extends StatelessWidget {
  const _FinishedDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.cardTint)),
        const SizedBox(width: 8),
        Text('Finished', style: CalendarText.sheetSectionLabel),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppColors.cardTint)),
      ],
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
    this.dimmed = false,
  });

  final CalendarEvent event;

  /// Null when the event has no course, or when its course has since been
  /// deleted — the row then shows no course line.
  final Course? course;

  final VoidCallback onDelete;

  /// True for an already-finished event (today's past-start group, or any
  /// event on a past day) — dims the colour bar and text, per
  /// [_kFinishedOpacity]. The delete button is never dimmed; it's built
  /// outside the [Opacity] below so it stays fully usable.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final hue = parseHexColor(event.color);
    final reminder = eventReminderSummary(event);
    final opacity = dimmed ? _kFinishedOpacity : 1.0;

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
            Opacity(
              opacity: opacity,
              child: Container(
                width: 6,
                margin: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: hue,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 13, 13, 15),
                child: Row(
                  children: [
                    Expanded(
                      child: Opacity(
                        opacity: opacity,
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
