import 'package:flutter/material.dart';

import '../../../models/calendar_event.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/event_time.dart';
import '../calendar_styles.dart';

/// How many event dots a day cell shows before collapsing the rest into a
/// "+N" label, per the handoff's `list.slice(0, 2)`.
const int kMaxDayDots = 2;

/// The white month card: Sunday-first weekday headers, one cell per day, an
/// outlined today marker, and up to [kMaxDayDots] colour dots per day plus a
/// "+N" overflow label.
///
/// The grid stretches to fill whatever height it is given rather than
/// scrolling — the handoff sizes its rows with `grid-auto-rows: minmax(0,
/// 1fr)` inside a `flex: 1` card, so a 6-row month compresses instead of
/// pushing the nav off-screen.
///
/// Dots render for every day with events, including today and days already
/// in the past — a past event is still a real thing the student scheduled,
/// so hiding its dot would make the month look wrong.
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

  /// "Today" for the outlined marker, injected so tests are deterministic.
  final DateTime today;

  /// Fires with the tapped day. Only days that actually hold events are
  /// tappable — the handoff gives an empty cell `cursor: default` and wires
  /// no handler to it.
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final cells = monthGridCells(month);
    // Pad the final row so the last week's cells keep the same width as
    // every other row rather than stretching to fill it.
    final padded = [
      ...cells,
      ...List<DateTime?>.filled((7 - cells.length % 7) % 7, null),
    ];
    final rows = <List<DateTime?>>[
      for (var i = 0; i < padded.length; i += 7) padded.sublist(i, i + 7),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          // The handoff's `0 0 0 2px #EEF0FF` ring, drawn as a spread-only
          // shadow so it sits outside the card like the CSS does, plus the
          // hard `0 3px 0` drop beneath it.
          const BoxShadow(
            color: AppColors.cardTint,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
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
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Center(
                      child: Text(label, style: CalendarText.weekday),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Expanded(
              child: Row(
                children: [
                  for (final day in row)
                    Expanded(
                      child: day == null
                          ? const SizedBox.shrink()
                          : _DayCell(
                              day: day,
                              isToday: isSameDay(day, today),
                              events: eventsByDay[day] ?? const [],
                              onTap: () => onDayTap(day),
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One day button: the number, then its dot row.
///
/// Today is drawn as an **outline** — a pale red fill with a 2px red border
/// and red text — not a solid red tile. The handoff and the original SRS
/// figure agree on this.
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
    final hasEvents = events.isNotEmpty;
    final overflow = events.length - kMaxDayDots;

    return Padding(
      padding: const EdgeInsets.all(3),
      child: GestureDetector(
        onTap: hasEvents ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: isToday ? AppColors.errorBannerBackground : null,
            borderRadius: BorderRadius.circular(14),
            border: isToday
                ? Border.all(color: AppColors.red, width: 2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // The grid compresses to fit the screen, so a short month row
              // can leave less height than the 18px number plus its dot row
              // wants. Shrinking the number is the right give: it stays at
              // its design size whenever there is room, and never overflows
              // when there isn't.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    day.day.toString(),
                    textAlign: TextAlign.center,
                    style: CalendarText.dayNumber(
                      isToday ? AppColors.red : AppColors.navy,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final event in events.take(kMaxDayDots))
                      Padding(
                        key: ValueKey('day-dot-${event.eventId}'),
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
                    if (overflow > 0)
                      Text('+$overflow', style: CalendarText.dayOverflow),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
