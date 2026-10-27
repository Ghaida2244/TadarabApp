import 'package:flutter/material.dart';

import '../../../services/home_data_service.dart';
import '../../../services/streak_service.dart' show dateOnly;
import '../../../theme/app_theme.dart';
import '../../../utils/event_time.dart'
    show formatLongDate, formatStoredTimeForDisplay;
import '../../../widgets/session_stack_card.dart';

const _monthAbbreviations = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

/// The "Upcoming" list on Home: every not-yet-started event in the next
/// [kUpcomingWindowDays] days, one entry per calendar day — a plain card
/// for a day with a single event, or an inline-expandable [SessionStackCard]
/// stack for a day with two or more (see [_UpcomingDayEntry]).
class UpcomingSection extends StatelessWidget {
  const UpcomingSection({
    super.key,
    required this.events,
    required this.now,
    required this.onSeeAll,
  });

  final List<UpcomingEventView> events;
  final DateTime now;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final days = groupUpcomingByDay(events);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming',
              style: AppTypography.fieldLabel.copyWith(fontSize: 17),
            ),
            GestureDetector(
              onTap: onSeeAll,
              child: Text('See all', style: AppTypography.link),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (days.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'No events in the next 7 days',
              textAlign: TextAlign.center,
              style: AppTypography.subtitle,
            ),
          )
        else
          for (final group in days) ...[
            _UpcomingDayEntry(
              key: ValueKey(group.day),
              group: group,
              now: now,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// One day's entry in the Upcoming list.
///
/// A day with a single event renders that event's plain card, exactly as
/// before stacking existed — not tappable. A day with two or more collapses
/// into a [SessionStackCard] fronted by the nearest not-yet-started event;
/// tapping that front card expands the day's remaining events inline below
/// it (same card size/style, not individually tappable) instead of opening
/// a separate focus-view screen, and tapping again collapses it.
///
/// A [StatefulWidget] — rather than deriving `expanded` from the data —
/// specifically so [UpcomingSection] can give it `key: ValueKey(day)`: the
/// live-removal timer in `_HomeTabState` re-prunes and rebuilds this list
/// often (every time an event's start passes), and keying by day is what
/// lets Flutter preserve *this* day's expand/collapse state across that
/// rebuild instead of resetting it, while still correctly starting fresh
/// state for a day that wasn't there before (never happens here — days
/// only ever lose events, never gain them, while Home stays open) and
/// discarding state for a day that's fully gone.
class _UpcomingDayEntry extends StatefulWidget {
  const _UpcomingDayEntry({super.key, required this.group, required this.now});

  final UpcomingDayGroup group;
  final DateTime now;

  @override
  State<_UpcomingDayEntry> createState() => _UpcomingDayEntryState();
}

class _UpcomingDayEntryState extends State<_UpcomingDayEntry> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  /// "Today, 3 events, tap to expand" (or "tap to collapse" once expanded)
  /// — read by the front card's [Semantics] below.
  String get _frontCardLabel {
    final isToday = dateOnly(widget.group.day) == dateOnly(widget.now);
    final dayLabel = isToday ? 'Today' : formatLongDate(widget.group.day);
    final count = widget.group.events.length;
    final countLabel = count == 1 ? '1 event' : '$count events';
    final action = _expanded ? 'tap to collapse' : 'tap to expand';
    return '$dayLabel, $countLabel, $action';
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.group.events;

    // A day that has dropped to one event (or never had more) is always a
    // plain, non-tappable card — regardless of any previously-toggled
    // expand state, which simply stops applying once there's nothing left
    // to expand into.
    if (events.length <= 1) {
      return _UpcomingEventCard(view: events.first, now: widget.now);
    }

    final front = events.first;
    final rest = events.skip(1).toList();

    // The stack/expand toggle is a structural change (a SessionStackCard
    // with peek layers vs. a plain Column of full-size cards) that Flutter
    // can't cross-fade on its own — AnimatedSize smooths the height jump
    // between the two, same 240ms/easeOut as SessionStackCard's own
    // internal peek-reservation animation.
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: _expanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _frontCard(front),
                for (final view in rest) ...[
                  const SizedBox(height: 10),
                  // Not individually tappable, same as a plain day's card.
                  _UpcomingEventCard(view: view, now: widget.now),
                ],
              ],
            )
          : Semantics(
              button: true,
              expanded: false,
              label: _frontCardLabel,
              child: ExcludeSemantics(
                child: SessionStackCard(
                  stackSize: events.length,
                  cardBuilder: (context) =>
                      _UpcomingEventCard(view: front, now: widget.now),
                  onOpenStack: _toggle,
                ),
              ),
            ),
    );
  }

  /// The front card, wrapped in its own custom [Semantics] — overriding
  /// [SessionStackCard]'s own built-in "Session stack, N attempts" label
  /// (meant for the Sessions screens' retake stacks, not this feature)
  /// without needing to touch that shared widget. Used for the expanded
  /// front card; the collapsed one gets the same treatment directly around
  /// [SessionStackCard] above, since [SessionStackCard] already supplies its
  /// own tap handling (`onOpenStack`) and doesn't need a second
  /// [GestureDetector] layered on top.
  Widget _frontCard(UpcomingEventView front) {
    return Semantics(
      button: true,
      expanded: _expanded,
      label: _frontCardLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: ExcludeSemantics(
          child: _UpcomingEventCard(view: front, now: widget.now),
        ),
      ),
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard({required this.view, required this.now});

  final UpcomingEventView view;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final event = view.event;
    final color = parseHexColor(event.color);
    final eventDate = dateOnly(event.eventDate);
    final today = dateOnly(now);
    final daysUntil = eventDate.difference(today).inDays;
    final isToday = daysUntil == 0;

    final subtitleParts = [
      if (view.courseName != null) view.courseName!,
      // Same display format as the Calendar day sheet, Add Event and
      // Study Reminder — an unparsable stored value falls back to the raw
      // string, same as there.
      formatStoredTimeForDisplay(event.eventTime),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  eventDate.day.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1,
                  ),
                ),
                Text(
                  _monthAbbreviations[eventDate.month - 1],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventName,
                  style: AppTypography.fieldLabel.copyWith(fontSize: 16),
                ),
                Text(
                  subtitleParts.join(' · '),
                  style: AppTypography.subtitle.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            )
          else
            Text(
              '${daysUntil}d',
              style: AppTypography.fieldLabel.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
