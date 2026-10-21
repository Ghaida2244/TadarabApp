import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../models/course.dart';
import '../../services/calendar_service.dart';
import '../../services/courses_service.dart';
import '../../services/home_data_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/event_time.dart';
import '../../widgets/app_error_banner.dart';
import 'add_event_screen.dart';
import 'calendar_styles.dart';
import 'widgets/calendar_header.dart';
import 'widgets/day_events_sheet.dart';
import 'widgets/delete_event_dialog.dart';
import 'widgets/month_grid.dart';
import 'widgets/year_grid.dart';

/// The Calendar tab: a month grid of the student's events with a colour dot
/// per event, a year overview, month navigation, and a day-details sheet for
/// deleting.
///
/// Deliberately grid-only — the Upcoming Events list belongs on Home.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.uid,
    this.calendarService,
    this.coursesService,
    this.homeDataService,
    this.now,
    this.onEventsChanged,
  });

  final String uid;

  /// Overridable for tests; defaults to the real Firestore-backed services.
  final CalendarService? calendarService;

  /// Source for the student's courses, used for the course name on an event
  /// row and for the Add Event dropdown. [CoursesService] rather than
  /// [HomeDataService] because it wraps its failures in a `CoursesFailure`
  /// with a readable message instead of throwing raw.
  final CoursesService? coursesService;

  /// Retained because the navigation shell passes it in. No longer used:
  /// courses now come from [coursesService], which is the Courses feature's
  /// own source of truth. Removing the parameter would mean editing
  /// `home_screen.dart`, a shared file frozen after Phase B.
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
  late final CoursesService _coursesService =
      widget.coursesService ?? CoursesService();

  late DateTime _month = firstOfMonth(_now);
  bool _yearView = false;

  /// Bumped to force the StreamBuilder to resubscribe after a retry.
  int _retryToken = 0;

  /// The student's courses, for the course name under an event and for the
  /// Add Event dropdown. Empty when the fetch failed — see [_loadCourses].
  List<Course> _courses = const [];

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  /// Course names are enrichment, not the screen's subject: a failure here
  /// leaves [_courses] empty so rows simply omit the course line, rather
  /// than blocking events that loaded perfectly well. The events themselves
  /// keep the full error-and-retry treatment below.
  Future<void> _loadCourses() async {
    try {
      final courses = await _coursesService.fetchCourses(widget.uid);
      if (!mounted) return;
      setState(() => _courses = courses);
    } on CoursesFailure {
      // Intentionally silent — see above.
    }
  }

  /// Courses keyed by ID. An event pointing at a course that has since been
  /// deleted simply won't be found here.
  Map<String, Course> get _coursesById => {
    for (final course in _courses) course.courseId: course,
  };

  void _step(int delta) {
    setState(() {
      _month = _yearView
          ? DateTime(_month.year + delta, _month.month, 1)
          : addMonths(_month, delta);
    });
  }

  void _toggleView() => setState(() => _yearView = !_yearView);

  void _backToToday() {
    setState(() {
      _month = firstOfMonth(_now);
      _yearView = false;
    });
  }

  void _openMonthFromYear(int month) {
    setState(() {
      _month = DateTime(_month.year, month, 1);
      _yearView = false;
    });
  }

  Future<void> _openAddEvent() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEventScreen(
          uid: widget.uid,
          calendarService: _calendarService,
          courses: _courses,
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
      barrierColor: AppColors.navy.withValues(alpha: 0.5),
      isScrollControlled: true,
      // The handoff caps the sheet at 62% of the screen.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.62,
      ),
      builder: (sheetContext) => DayEventsSheet(
        day: day,
        events: events,
        coursesById: _coursesById,
        onDeleteRequested: (event) => _confirmDelete(sheetContext, event),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext sheetContext,
    CalendarEvent event,
  ) async {
    final confirmed = await showDeleteEventDialog(sheetContext, event: event);
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
            style: CalendarText.save.copyWith(fontSize: 14),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          CalendarHeader(
            month: _month,
            isYearView: _yearView,
            showBackToToday: !isSameMonth(_month, _now),
            onPrevious: () => _step(-1),
            onNext: () => _step(1),
            onToggleView: _toggleView,
            onBackToToday: _backToToday,
            onAddEvent: _openAddEvent,
          ),
          Expanded(
            child: StreamBuilder<List<CalendarEvent>>(
              key: ValueKey(
                _yearView
                    ? 'year-${_month.year}-$_retryToken'
                    : 'month-$_month-$_retryToken',
              ),
              stream: _yearView
                  ? _calendarService.watchEventsForYear(
                      widget.uid,
                      _month.year,
                    )
                  : _calendarService.watchEventsForMonth(widget.uid, _month),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _CalendarError(
                    message: snapshot.error is CalendarFailure
                        ? (snapshot.error as CalendarFailure).message
                        : "Couldn't load your calendar. Please try again.",
                    onRetry: () => setState(() => _retryToken++),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final events = snapshot.data ?? const <CalendarEvent>[];
                final grouped = groupEventsByDay(events);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: _yearView
                      ? YearGrid(
                          year: _month.year,
                          eventsByDay: grouped,
                          today: _now,
                          onMonthSelected: _openMonthFromYear,
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: MonthGrid(
                                month: _month,
                                eventsByDay: grouped,
                                today: _now,
                                onDayTap: (day) =>
                                    _openDay(day, grouped[day] ?? const []),
                              ),
                            ),
                            // Not in the handoff, whose empty-month branch
                            // renders nothing — kept so a blank month doesn't
                            // read as a failed load.
                            if (events.isEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                'No events yet. Tap "Add Event" to schedule '
                                'your first one.',
                                textAlign: TextAlign.center,
                                style: CalendarText.monthEmpty,
                              ),
                            ],
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
