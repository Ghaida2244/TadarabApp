// Pure date/visual-state logic for the Today's Progress card's weekly
// streak row (lib/screens/home/widgets/today_progress_card.dart) — no
// Firestore, no widgets, so every branch is directly unit-testable. See
// docs/mockups/design-handoff_streak/android-study-app-redesign/project/
// Tadarab - Streak Row.dc.html (variant 1b) for the source this implements.

/// Jan..Dec abbreviations for the header's month/range label. Not using
/// `intl` (not a project dependency) — same spirit as the day-of-week
/// letters already hardcoded in today_progress_card.dart.
const monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Shifts [date] by [days] using the calendar-date constructor rather than
/// `Duration` arithmetic — `DateTime(y, m, d + days)` always lands on the
/// correct calendar day regardless of how many hours that span actually
/// contains, so a DST transition inside the shifted range can never throw
/// the result off by an hour (or, worse, onto the wrong calendar day).
/// Preserves [date]'s time-of-day exactly.
DateTime addDaysCalendar(DateTime date, int days) {
  return DateTime(
    date.year,
    date.month,
    date.day + days,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

/// The Sunday [weeksBack] weeks before [currentWeekStart] (0 = the current
/// week itself) — the streak row's page-to-week mapping. Uses
/// [addDaysCalendar], never `Duration`, for the same DST-safety reason.
DateTime weekStartForWeeksBack({
  required DateTime currentWeekStart,
  required int weeksBack,
}) {
  assert(weeksBack >= 0, 'weeksBack cannot be negative');
  return addDaysCalendar(currentWeekStart, -7 * weeksBack);
}

String _monthDay(DateTime date) =>
    '${monthAbbreviations[date.month - 1]} ${date.day}';

/// The streak panel header's right-side label: for the current week, just
/// the month (or "Mon – Mon" if the week spans two months); for an earlier
/// week, the explicit day range, e.g. "Oct 11 – Oct 17" — always both ends'
/// month, even when it's the same month on both sides.
String streakHeaderLabel({required DateTime weekStart, required bool isCurrent}) {
  final weekEnd = addDaysCalendar(weekStart, 6);
  if (isCurrent) {
    final startMonth = monthAbbreviations[weekStart.month - 1];
    if (weekStart.month == weekEnd.month) return startMonth;
    return '$startMonth – ${monthAbbreviations[weekEnd.month - 1]}';
  }
  return '${_monthDay(weekStart)} – ${_monthDay(weekEnd)}';
}

/// How a day cell is filled/bordered — collapses the mockup's `bg`/`border`
/// rules, which (unlike the label's opacity, see [dayCellLabelOpacity])
/// never distinguish a future/locked empty day from a past/missed empty
/// one: both render identically, only [dayCellLabelOpacity] tells them
/// apart.
enum DayCellFillState {
  /// Any day (past or today) with real activity — solid red, no border.
  active,

  /// Today, no activity yet — a bright dashed outline, transparent fill.
  todayEmpty,

  /// Any other day with no activity — a dim dashed outline, dim fill.
  /// Covers both a missed past day and a locked future day; they look the
  /// same.
  otherEmpty,
}

DayCellFillState dayCellFillState({
  required bool hasActivity,
  required bool isToday,
}) {
  if (hasActivity) return DayCellFillState.active;
  if (isToday) return DayCellFillState.todayEmpty;
  return DayCellFillState.otherEmpty;
}

/// The day label's opacity (against white) — independent of whether the
/// day has activity, per the mockup's own `ink` rule: today is always full
/// opacity; otherwise a future/locked day is dimmer than a past day
/// (active or missed alike).
double dayCellLabelOpacity({required bool isToday, required bool isFuture}) {
  if (isToday) return 1.0;
  return isFuture ? 0.4 : 0.6;
}
