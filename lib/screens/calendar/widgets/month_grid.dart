import 'package:flutter/material.dart';

import '../../../models/calendar_event.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/event_time.dart';

/// The white month card: Sunday-first weekday headers, one cell per day,
/// a red today marker, and a dot per event under any day that has events.
///
/// Dots are rendered for every day with events, including today and days
/// already in the past — a past event is still a real thing the student
/// scheduled, so hiding its dot would make the month look wrong.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.eventsByDay,
    required this.today,
    required this.onDayTap,
  });

  /// Any date inside the month being shown; only year/month are used.
  final DateTime month;

  /// Events keyed by local calendar day, as built by `groupEventsByDay`.
  final Map<DateTime, List<CalendarEvent>> eventsByDay;

  /// "Today" for the red marker, injected so tests are deterministic.
  final DateTime today;

  /// Fires with the tapped day. Days with no events still fire — the screen
  /// decides whether an empty day is worth opening a sheet for.
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final cells = monthGridCells(month);
    // Pad the final row so the last week's cells keep the same width as
    // every other row rather than stretching to fill it.
    final padded = [...cells, ...List<DateTime?>.filled((7 - cells.length % 7) % 7, null)];
    final rows = <List<DateTime?>>[
      for (var i = 0; i < padded.length; i += 7) padded.sublist(i, i + 7),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in kWeekdayHeaders)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.placeholder,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Row(
              children: [
                for (final day in row)
                  Expanded(
                    child: day == null
                        ? const SizedBox(height: 58)
                        : _DayCell(
                            day: day,
                            isToday: isSameDay(day, today),
                            events: eventsByDay[day] ?? const [],
                            onTap: () => onDayTap(day),
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.events,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final List<CalendarEvent> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.red.withValues(alpha: 0.28),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    )
                  : null,
              child: Text(
                day.day.toString(),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isToday ? Colors.white : AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cap the dot row so a day with many events can't widen
                  // the cell and break the column alignment.
                  for (final event in events.take(3))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: parseHexColor(event.color),
                          shape: BoxShape.circle,
                        ),
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
