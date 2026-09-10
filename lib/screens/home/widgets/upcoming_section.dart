import 'package:flutter/material.dart';

import '../../../services/home_data_service.dart';
import '../../../services/streak_service.dart' show dateOnly;
import '../../../theme/app_theme.dart';

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

/// The "Upcoming" list on Home: real events from Firestore, soonest first.
/// Empty (Calendar isn't built yet, so this is always empty right now) is a
/// normal, expected state with an explanatory message, not an error.
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
        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'No upcoming events yet. Once you add events, they\'ll show up here.',
              textAlign: TextAlign.center,
              style: AppTypography.subtitle,
            ),
          )
        else
          for (final view in events) ...[
            _UpcomingEventCard(view: view, now: now),
            const SizedBox(height: 10),
          ],
      ],
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
      event.eventTime,
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
