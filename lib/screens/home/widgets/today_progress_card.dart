import 'package:flutter/material.dart';

import '../../../services/home_data_service.dart';
import '../../../services/streak_service.dart' show dateOnly;
import '../../../theme/app_theme.dart';

const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

/// The dark "Today's progress" card: today's question/flashcard split at
/// top, then a 7-day (Sun-Sat) row of combined counts below. [currentStreak]
/// is the real, week-independent streak (Student.currentStreak) — the row
/// itself only ever shows the current calendar week, per the design.
class TodayProgressCard extends StatelessWidget {
  const TodayProgressCard({
    super.key,
    required this.weeklyProgress,
    required this.currentStreak,
    required this.now,
  });

  final WeeklyProgress weeklyProgress;
  final int currentStreak;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(now);
    final todayCount = weeklyProgress.dayForDate(today);

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
            style: AppTypography.helper.copyWith(
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$currentStreak-day streak',
                      style: AppTypography.fieldLabel.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'questions + cards per day',
                      style: AppTypography.helper.copyWith(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _DayCell(
                          label: _dayLabels[i],
                          day: weeklyProgress.days[i],
                          isToday: weeklyProgress.days[i].date == today,
                          isFuture: weeklyProgress.days[i].date.isAfter(today),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
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

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.day,
    required this.isToday,
    required this.isFuture,
  });

  final String label;
  final DailyStudyCount day;
  final bool isToday;
  final bool isFuture;

  bool get _hasData => day.combined > 0;

  @override
  Widget build(BuildContext context) {
    final bool filled = isToday || _hasData;

    return Column(
      children: [
        Container(
          height: 34,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday
                ? Colors.white
                : _hasData
                ? AppColors.red
                : Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: filled
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: isFuture ? 0.3 : 0.5),
                    width: 2,
                  ),
          ),
          child: filled
              ? Text(
                  '${day.combined}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isToday ? AppColors.navy : Colors.white,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.04 * 10,
            color: Colors.white.withValues(
              alpha: isToday ? 1 : (isFuture ? 0.4 : 0.6),
            ),
          ),
        ),
      ],
    );
  }
}
