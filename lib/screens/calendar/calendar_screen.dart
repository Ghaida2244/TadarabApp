import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../services/calendar_service.dart';
import '../../services/home_data_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/event_time.dart';
import '../../widgets/app_error_banner.dart';
import 'add_event_screen.dart';
import 'widgets/day_events_sheet.dart';
import 'widgets/delete_event_dialog.dart';
import 'widgets/month_grid.dart';

/// The Calendar tab: a month grid of the student's events with a dot per
/// event, month navigation, and a day-details sheet for adding context and
/// deleting. Deliberately grid-only — the Upcoming Events list belongs on
/// Home, not here.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.uid,
    this.calendarService,
    this.homeDataService,
    this.now,
    this.onEventsChanged,
  });

  final String uid;

  /// Overridable for tests; defaults to the real Firestore-backed services.
  final CalendarService? calendarService;
  final HomeDataService? homeDataService;

  /// Overridable for tests, so the today marker and the initially shown
  /// month are deterministic.
  final DateTime? now;

  /// Called after an event is added or deleted, so Home's Upcoming section
  /// can re-read rather than showing a stale list when the student switches
  /// back to that tab.
  final VoidCallback? onEventsChanged;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final CalendarService _calendarService =
      widget.calendarService ?? CalendarService();
  late final HomeDataService _homeDataService =
      widget.homeDataService ?? HomeDataService();

  late DateTime _month = firstOfMonth(_now);

  /// Bumped to force the StreamBuilder to resubscribe after a retry.
  int _retryToken = 0;

  DateTime get _now => widget.now ?? DateTime.now();

  void _stepMonth(int delta) {
    setState(() => _month = addMonths(_month, delta));
  }

  Future<void> _openAddEvent() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEventScreen(
          uid: widget.uid,
          calendarService: _calendarService,
          homeDataService: _homeDataService,
          initialDate: _month,
          now: _now,
        ),
      ),
    );
    if (saved == true) widget.onEventsChanged?.call();
  }

  Future<void> _openDay(DateTime day, List<CalendarEvent> events) async {
    if (events.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => DayEventsSheet(
        day: day,
        events: events,
        onDeleteRequested: (event) => _confirmDelete(sheetContext, event),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext sheetContext,
    CalendarEvent event,
  ) async {
    final confirmed = await showDeleteEventDialog(sheetContext);
    if (!confirmed) return;

    try {
      await _calendarService.deleteEvent(widget.uid, event.eventId);
      // Close the sheet so the student sees the updated grid underneath
      // rather than a list still showing the event they just deleted.
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      widget.onEventsChanged?.call();
    } on CalendarFailure catch (failure) {
      if (!sheetContext.mounted) return;
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            failure.message,
            style: AppTypography.button.copyWith(fontSize: 14),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.homeBackground,
      child: Column(
        children: [
          _CalendarHeader(
            month: _month,
            onPreviousMonth: () => _stepMonth(-1),
            onNextMonth: () => _stepMonth(1),
            onAddEvent: _openAddEvent,
          ),
          Expanded(
            child: StreamBuilder<List<CalendarEvent>>(
              key: ValueKey('$_month-$_retryToken'),
              stream: _calendarService.watchEventsForMonth(widget.uid, _month),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _CalendarError(
                    message: snapshot.error is CalendarFailure
                        ? (snapshot.error as CalendarFailure).message
                        : "Couldn't load your calendar. Please try again.",
                    onRetry: () => setState(() => _retryToken++),
                  );
                }

                final events = snapshot.data;
                final grouped = groupEventsByDay(events ?? const []);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    children: [
                      MonthGrid(
                        month: _month,
                        eventsByDay: grouped,
                        today: _now,
                        onDayTap: (day) =>
                            _openDay(day, grouped[day] ?? const []),
                      ),
                      const SizedBox(height: 18),
                      // Only once the month's events have actually loaded —
                      // showing the empty line while the first snapshot is
                      // still in flight would flash "no events" at a student
                      // who has them.
                      if (events != null && events.isEmpty)
                        Text(
                          'No events yet. Tap "Add Event" to schedule your first one.',
                          textAlign: TextAlign.center,
                          style: AppTypography.subtitle.copyWith(fontSize: 15),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.month,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onAddEvent,
  });

  final DateTime month;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onAddEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Calendar',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: onAddEvent,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '+ Add Event',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _MonthArrow(
                  icon: Icons.chevron_left,
                  onTap: onPreviousMonth,
                  semanticLabel: 'Previous month',
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      formatMonthTitle(month),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                _MonthArrow(
                  icon: Icons.chevron_right,
                  onTap: onNextMonth,
                  semanticLabel: 'Next month',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: Colors.white),
        ),
      ),
    );
  }
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppErrorBanner(
              heading: "Couldn't load your calendar",
              body: message,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              behavior: HitTestBehavior.opaque,
              child: Text('Try again', style: AppTypography.link),
            ),
          ],
        ),
      ),
    );
  }
}
