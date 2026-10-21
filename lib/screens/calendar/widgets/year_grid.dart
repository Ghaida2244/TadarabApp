import 'package:flutter/material.dart';

import '../../../models/calendar_event.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/event_time.dart';
import '../calendar_styles.dart';

/// The year view: twelve mini-months in a three-column grid, each a tappable
/// card that opens that month in the detailed view.
///
/// Built to the handoff's two defaults — `yearMarkers = 'fill'` and
/// `todayStyle = 'ring'`:
///  * **fill** — a day that has events is filled with its first event's
///    colour, right on the date. (The alternative, `dots`, would hang tiny
///    dots underneath instead; not used.)
///  * **ring** — today gets a pale red pill with a red ring around it and
///    red text, scaled up slightly, rather than a solid red "Apple" dot.
///
/// Where a day is both today *and* has an event, the event's fill wins for
/// the background and the ring is still drawn around it, per the handoff's
/// `bg: fillHue ? fillHue : (isT ? '#FFE9EA' : 'transparent')` with
/// `ring: isT ? '0 0 0 1.5px RED' : 'none'`.
class YearGrid extends StatelessWidget {
  const YearGrid({
    super.key,
    required this.year,
    required this.eventsByDay,
    required this.today,
    required this.onMonthSelected,
  });

  /// The year being shown.
  final int year;

  /// Every event the screen knows about, keyed by local calendar day.
  final Map<DateTime, List<CalendarEvent>> eventsByDay;

  /// "Today", injected so tests are deterministic.
  final DateTime today;

  /// Fires with a 1-based month number when a mini-month is tapped.
  final ValueChanged<int> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: EdgeInsets.zero,
      crossAxisCount: 3,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      // Tall enough for a label plus six day rows without clipping.
      childAspectRatio: 0.78,
      children: [
        for (var month = 1; month <= 12; month++)
          _MiniMonth(
            key: ValueKey('mini-month-$month'),
            year: year,
            month: month,
            eventsByDay: eventsByDay,
            today: today,
            isCurrentMonth:
                month == today.month && year == today.year,
            onTap: () => onMonthSelected(month),
          ),
      ],
    );
  }
}

/// One month card inside [YearGrid].
class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    super.key,
    required this.year,
    required this.month,
    required this.eventsByDay,
    required this.today,
    required this.isCurrentMonth,
    required this.onTap,
  });

  final int year;
  final int month;
  final Map<DateTime, List<CalendarEvent>> eventsByDay;
  final DateTime today;
  final bool isCurrentMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cells = monthGridCells(DateTime(year, month, 1));
    final padded = [
      ...cells,
      ...List<DateTime?>.filled((7 - cells.length % 7) % 7, null),
    ];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 11, 4, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentMonth ? AppColors.red : AppColors.cardTint,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.06),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                // "Jan", "Feb" — the handoff's `mLabel.slice(0, 3)`.
                kMonthNames[month - 1].substring(0, 3),
                style: CalendarText.miniMonth(
                  isCurrentMonth ? AppColors.red : AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: GridView.count(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 7,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
                children: [
                  for (final day in padded)
                    day == null
                        ? const SizedBox.shrink()
                        : _MiniDay(
                            day: day,
                            isToday: isSameDay(day, today),
                            // `fill` mode paints the first event of the day
                            // by time, matching the handoff's sort.
                            fillColor: _firstEventColor(day),
                          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The colour of the earliest event on [day], or null when it has none.
  Color? _firstEventColor(DateTime day) {
    final events = eventsByDay[day];
    if (events == null || events.isEmpty) return null;
    final sorted = [...events]
      ..sort((a, b) => a.eventTime.compareTo(b.eventTime));
    return parseHexColor(sorted.first.color);
  }
}

/// A single date inside a mini-month.
class _MiniDay extends StatelessWidget {
  const _MiniDay({
    required this.day,
    required this.isToday,
    required this.fillColor,
  });

  final DateTime day;
  final bool isToday;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final filled = fillColor != null;
    final Color ink = filled
        ? Colors.white
        : (isToday ? AppColors.red : AppColors.placeholder);

    return Center(
      child: Transform.scale(
        // The handoff nudges a ringed today up by 15% so the ring reads at
        // this size; a filled cell stays at 1.
        scale: isToday && !filled ? 1.15 : 1,
        child: Container(
          key: ValueKey('mini-day-${day.month}-${day.day}'),
          width: 13,
          height: 13,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? fillColor
                : (isToday ? AppColors.errorBannerBackground : null),
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: AppColors.red, width: 1.5)
                : null,
          ),
          child: Text(
            day.day.toString(),
            style: CalendarText.miniDay(ink),
          ),
        ),
      ),
    );
  }
}
