import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/flashcards/flashcard_navigation.dart';
import '../../features/flashcards/screens/flashcard_flip_deck_screen.dart';
import '../../features/flashcards/screens/flashcard_sessions_screen.dart';
import '../../models/course.dart';
import '../../models/student.dart';
import '../../models/study_material.dart';
import '../../services/calendar_service.dart';
import '../../services/courses_service.dart';
import '../../services/flashcard_service.dart';
import '../../services/home_data_service.dart';
import '../../services/quiz_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/event_time.dart' show eventDateTime;
import '../../utils/rank.dart';
import '../profile/widgets/rank_icon.dart';
import '../calendar/calendar_screen.dart';
import '../courses/add_course_screen.dart';
import '../courses/course_detail_screen.dart';
import '../courses/courses_list_screen.dart';
import '../profile/profile_screen.dart';
import '../quiz/quiz_navigation.dart';
import '../quiz/quiz_play_screen.dart';
import '../quiz/quiz_sessions_screen.dart';
import 'widgets/continue_or_start_card.dart';
import 'widgets/course_picker_sheet.dart';
import 'widgets/new_student_onboarding_card.dart';
import 'widgets/today_progress_card.dart';
import 'widgets/upcoming_section.dart';

/// The Home tab shell: greeting, Today's Progress, Continue/Start,
/// Upcoming — plus the bottom nav bar that switches to the (not-yet-built)
/// Courses/Calendar/Profile tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.uid,
    this.homeDataService,
    this.calendarService,
    this.coursesService,
    this.flashcardServiceBuilder,
    this.now,
    this.onSignOut,
  });

  final String uid;

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final HomeDataService? homeDataService;

  /// Overridable for tests; passed straight to the Calendar tab.
  final CalendarService? calendarService;

  /// Overridable for tests; defaults to the real Firebase-backed service.
  /// Used both by the onboarding "Create my first course" button and by
  /// the embedded Courses tab, so a single override covers both.
  final CoursesService? coursesService;

  /// Overridable for tests; defaults to the real Firebase-backed
  /// FlashcardService. A builder (not a single instance) because, unlike
  /// [coursesService], the course it's scoped to isn't known until the
  /// student picks one from the course picker or has an in-progress
  /// session to resume.
  final FlashcardService Function({required String uid, required String courseId})?
  flashcardServiceBuilder;

  /// Overridable for tests, so "today"/greeting/streak-row highlighting is deterministic.
  final DateTime? now;

  /// Shown as a "Log out" button on the Profile placeholder — there's
  /// nowhere else for it to live until a real Profile screen exists.
  final VoidCallback? onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _dataService = widget.homeDataService ?? HomeDataService();
  late final _coursesService = widget.coursesService ?? CoursesService();
  late final _flashcardServiceBuilder =
      widget.flashcardServiceBuilder ??
      ({required String uid, required String courseId}) =>
          FlashcardService(uid: uid, courseId: courseId);
  int _tabIndex = 0;

  /// Bumped whenever the Calendar adds or deletes an event, so the Home tab
  /// re-reads its Upcoming section instead of showing a stale list when the
  /// student switches back to it.
  int _homeRefreshToken = 0;

  /// Tabs the student has actually opened. [IndexedStack] builds every child
  /// eagerly, which would subscribe the Calendar to Firestore the moment
  /// Home mounted — so unvisited tabs render as an empty placeholder until
  /// they're first selected.
  final Set<int> _visitedTabs = {0};

  DateTime get _now => widget.now ?? DateTime.now();

  void _selectTab(int index) {
    setState(() {
      _tabIndex = index;
      _visitedTabs.add(index);
    });
  }

  /// [child] once its tab has been opened, an empty box before that.
  Widget _lazyTab(int index, Widget Function() child) =>
      _visitedTabs.contains(index) ? child() : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _HomeTab(
            uid: widget.uid,
            dataService: _dataService,
            coursesService: _coursesService,
            flashcardServiceBuilder: _flashcardServiceBuilder,
            now: _now,
            active: _tabIndex == 0,
            refreshToken: _homeRefreshToken,
            onCourseCreated: () => _selectTab(1),
            onOpenCalendarTab: () => _selectTab(2),
          ),
          CoursesListScreen(
            uid: widget.uid,
            coursesService: _coursesService,
            active: _tabIndex == 1,
          ),
          _lazyTab(
            2,
            () => CalendarScreen(
              uid: widget.uid,
              calendarService: widget.calendarService,
              homeDataService: _dataService,
              now: _now,
              onEventsChanged: () => setState(() => _homeRefreshToken++),
            ),
          ),
          _lazyTab(
            3,
            () => ProfileScreen(
              uid: widget.uid,
              homeDataService: _dataService,
              onSignOut: widget.onSignOut,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tabIndex,
        onTap: _selectTab,
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.uid,
    required this.dataService,
    required this.coursesService,
    required this.flashcardServiceBuilder,
    required this.now,
    required this.active,
    required this.refreshToken,
    required this.onCourseCreated,
    required this.onOpenCalendarTab,
  });

  final String uid;
  final HomeDataService dataService;
  final CoursesService coursesService;
  final FlashcardService Function({required String uid, required String courseId})
  flashcardServiceBuilder;
  final DateTime now;

  /// Whether this is the currently-selected bottom-nav tab. Home lives in a
  /// persistent IndexedStack alongside Courses, so this State survives tab
  /// switches — without reloading on becoming active again, a course
  /// created from the Courses tab would never lift Home out of its
  /// zero-courses onboarding state within the same session.
  final bool active;

  /// Changes whenever something outside this tab (today, only the Calendar)
  /// has altered data Home shows, prompting a re-read. Distinct from
  /// [active]: an event added on the Calendar tab must refresh Home even
  /// though Home is not the active tab at that moment.
  final int refreshToken;

  /// Switches HomeScreen's bottom-nav tab to Courses — called once a course
  /// is successfully created from Home's onboarding card, so the student
  /// lands on the Courses tab (with the new course visible) instead of
  /// staying on Home.
  final VoidCallback onCourseCreated;

  /// Switches HomeScreen's bottom-nav tab to Calendar — see
  /// [_HomeTabState._openCalendarTab].
  final VoidCallback onOpenCalendarTab;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  // Not `late final`: HomeScreen keeps every bottom-nav tab alive via
  // IndexedStack, so this State is never disposed/recreated when the
  // student navigates to a pushed screen (Quiz, Add Course, ...) and back
  // — a `late final` Future computed once at first access would go stale
  // forever (e.g. completing a quiz and returning would never show the
  // updated points/streak/Continue-card). The same applies to events
  // added or deleted on the Calendar tab. _reload() re-fetches everything
  // and is called whenever a pushed screen is popped back to Home, this
  // tab becomes active again, or [refreshToken] changes.
  late Future<List<Course>> _courses;
  late Future<WeeklyProgress> _weeklyProgress;
  late Future<InProgressSession?> _inProgress;
  late Future<List<UpcomingEventView>> _upcoming;

  /// Once [_upcoming] resolves, holds a locally re-pruned version of its
  /// list — set only when [_onUpcomingTimerFired] removes an event whose
  /// start has just passed, without a second Firestore round trip. Reset
  /// to null on every [_loadAll] (a fresh fetch supersedes it). Null means
  /// "show whatever [_upcoming] resolved to, unmodified".
  List<UpcomingEventView>? _liveUpcoming;

  /// Fires the moment the soonest not-yet-started event in the current
  /// Upcoming list is no longer upcoming, so it can disappear on its own
  /// without the student needing to leave and return to the tab. Re-armed
  /// after every fetch and after every time it fires; cancelled in
  /// [dispose] and while this tab isn't [_HomeTab.active] (no point
  /// ticking toward a UI update nothing is showing).
  Timer? _upcomingTimer;

  /// The "now" [_scheduleUpcomingTimer] measures the next [Timer]'s
  /// [Duration] from. Reset to [_HomeTab.now] on every [_loadAll], then
  /// advanced to each firing's own moment in [_onUpcomingTimerFired] —
  /// never left at the original, increasingly-stale [_HomeTab.now], or
  /// every re-arm after the first would compute a [Duration] too long by
  /// however much (fake or real) time had already passed since that
  /// original snapshot, drifting later with every event removed.
  late DateTime _upcomingClock;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant _HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Two independent triggers: becoming the active tab again (a course
    // may have been created on the Courses tab), and the shell bumping
    // [refreshToken] (an event was added or deleted on the Calendar tab,
    // which can happen while Home is inactive).
    final becameActive = widget.active && !oldWidget.active;
    final becameInactive = !widget.active && oldWidget.active;
    final dataChangedElsewhere = widget.refreshToken != oldWidget.refreshToken;
    if (becameActive || dataChangedElsewhere) _reload();
    // _reload() already re-arms the timer via _loadAll()/_scheduleUpcomingTimer
    // for the becameActive case; this only needs to additionally cancel it
    // when the tab stops being the one on screen.
    if (becameInactive) _upcomingTimer?.cancel();
  }

  @override
  void dispose() {
    _upcomingTimer?.cancel();
    super.dispose();
  }

  void _loadAll() {
    _courses = widget.dataService.fetchCourses(widget.uid);
    _weeklyProgress = widget.dataService.fetchWeeklyProgress(
      widget.uid,
      now: widget.now,
    );
    _inProgress = widget.dataService.fetchInProgressSession(widget.uid);
    _liveUpcoming = null;
    _upcomingClock = widget.now;
    final upcoming = widget.dataService.fetchUpcomingEvents(
      widget.uid,
      now: widget.now,
    );
    _upcoming = upcoming;
    upcoming.then(_scheduleUpcomingTimer);
  }

  void _reload() => setState(_loadAll);

  /// Arms [_upcomingTimer] for [events]' own soonest start, so the card
  /// disappears on its own the moment that passes. A no-op with nothing
  /// armed when [events] is empty, this tab isn't active, or the widget
  /// has already been disposed — the two latter checks matter because this
  /// runs from a Future callback, which can land after either.
  void _scheduleUpcomingTimer(List<UpcomingEventView> events) {
    _upcomingTimer?.cancel();
    if (!mounted || !widget.active || events.isEmpty) return;
    // events is already sorted soonest-first — see notYetStartedUpcoming.
    final soonestStart = eventDateTime(events.first.event);
    final duration = soonestStart.difference(_upcomingClock);
    _upcomingTimer = Timer(
      duration.isNegative ? Duration.zero : duration,
      () => _onUpcomingTimerFired(events, soonestStart),
    );
  }

  /// Re-prunes [previousEvents] as of [firedAt] (the exact moment the
  /// timer was armed for) rather than re-fetching — the student's course
  /// names are already attached to every surviving event, so there is
  /// nothing a network call would add here. Advances [_upcomingClock] to
  /// match before re-arming for whatever's next.
  void _onUpcomingTimerFired(
    List<UpcomingEventView> previousEvents,
    DateTime firedAt,
  ) {
    if (!mounted) return;
    _upcomingClock = firedAt;
    final pruned = notYetStartedUpcomingViews(previousEvents, now: firedAt);
    setState(() => _liveUpcoming = pruned);
    _scheduleUpcomingTimer(pruned);
  }

  /// Fetches one earlier week's data for [TodayProgressCard]'s streak row
  /// pager — the exact same query `_loadAll` already uses for the current
  /// week, just for a different week's Sunday. Lazy, per-week, and cached
  /// by the card itself; this method does no caching of its own.
  Future<WeeklyProgress> _fetchWeek(DateTime weekStart) =>
      widget.dataService.fetchWeeklyProgress(widget.uid, now: weekStart);

  Future<void> _openAddCourse() async {
    // Only reachable from the zero-courses onboarding card, so the
    // student's current course list is already known to be empty here —
    // no need to refetch it just to pass it along.
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddCourseScreen(
          uid: widget.uid,
          coursesService: widget.coursesService,
          existingCourses: const [],
        ),
      ),
    );
    if (created == true) {
      _reload();
      widget.onCourseCreated();
    }
  }

  void _openFlashcardSessions(Course course, String? email) {
    // Guards against the rare case where the student doc hasn't loaded yet
    // when this is tapped (FlashcardSessionsScreen needs a real email) —
    // same defensive-no-op spirit as _resumeSession's inProgress == null arm.
    if (email == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => FlashcardSessionsScreen(
              uid: widget.uid,
              courseId: course.courseId,
              email: email,
              service: widget.flashcardServiceBuilder(
                uid: widget.uid,
                courseId: course.courseId,
              ),
            ),
            settings: const RouteSettings(name: flashcardSessionsRouteName),
          ),
        )
        .then((_) => _reload());
  }

  void _openQuizSessions(Course course) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => QuizSessionsScreen(
              courseId: course.courseId,
              courseName: course.courseName,
              service: QuizSessionService(),
            ),
            settings: const RouteSettings(name: quizSessionsRouteName),
          ),
        )
        .then((_) => _reload());
  }

  void _openCoursePicker(SessionKind kind, {String? email}) {
    showCoursePickerSheet(
      context: context,
      dataService: widget.dataService,
      uid: widget.uid,
      kind: kind,
      onCourseSelected: (Course course) {
        Navigator.of(context).pop();
        _onCoursePicked(kind, course, email: email);
      },
    );
  }

  /// The course picker can't tell in advance whether a course has any
  /// material — Course Detail locks Quiz/Flashcards until at least one
  /// exists (see `_StudyTools`'s `unlocked` there), so opening the
  /// sessions screen directly for an empty course would let the student
  /// reach a screen Course Detail itself would never let them into. Uses
  /// [CoursesService.fetchMaterials] — the exact same source of truth
  /// Course Detail reads from — fetched fresh at the moment of picking
  /// rather than any cached count, so the two places can never disagree.
  Future<void> _onCoursePicked(
    SessionKind kind,
    Course course, {
    String? email,
  }) async {
    List<StudyMaterial> materials;
    try {
      materials = await widget.coursesService.fetchMaterials(
        widget.uid,
        course.courseId,
      );
    } on CoursesFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
    if (!mounted) return;

    if (materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kind == SessionKind.quiz
                ? 'Upload a material first to start a quiz.'
                : 'Upload a material first to start flashcards.',
          ),
        ),
      );
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(
                uid: widget.uid,
                course: course,
                coursesService: widget.coursesService,
              ),
            ),
          )
          .then((_) => _reload());
      return;
    }

    if (kind == SessionKind.quiz) {
      _openQuizSessions(course);
    } else {
      _openFlashcardSessions(course, email);
    }
  }

  void _resumeSession(InProgressSession session) {
    if (session.kind == SessionKind.quiz) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => QuizPlayScreen(
                sessionId: session.sessionId,
                service: QuizSessionService(),
              ),
            ),
          )
          .then((_) => _reload());
      return;
    }
    _resumeFlashcardSession(session);
  }

  // Unlike QuizPlayScreen (which loads its own session by id),
  // FlashcardFlipDeckScreen takes already-fetched data — it's also used to
  // start a fresh Retake with in-memory values, so it can't fetch for
  // itself. Mirrors FlashcardSessionsScreen._resume's same two-step fetch.
  Future<void> _resumeFlashcardSession(InProgressSession info) async {
    final service = widget.flashcardServiceBuilder(
      uid: widget.uid,
      courseId: info.courseId,
    );
    final sessions = await service.watchSessions().first;
    final session = sessions.firstWhere((s) => s.sessionId == info.sessionId);
    final flashcards = await service.fetchFlashcards(info.sessionId);
    if (!mounted) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => FlashcardFlipDeckScreen(
              uid: widget.uid,
              courseId: info.courseId,
              sessionId: info.sessionId,
              initialFlashcards: flashcards,
              initialIndex: session.currentFlashcardIndex,
              initialKnownCount: session.knownCount,
              initialNeedsReviewCount: session.needsReviewCount,
              service: service,
            ),
          ),
        )
        .then((_) => _reload());
  }

  void _openCalendarTab() {
    // Switches the bottom nav to the real Calendar tab (tab state lives in
    // the shell above), rather than pushing a second Calendar over Home.
    widget.onOpenCalendarTab();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder(
        future: Future.wait([
          _courses,
          _weeklyProgress,
          _inProgress,
          _upcoming,
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load your progress. Pull down to try again.',
                  style: AppTypography.subtitle,
                ),
              ),
            );
          }
          final results = snapshot.data!;
          final courses = results[0] as List<Course>;
          final weeklyProgress = results[1] as WeeklyProgress;
          final inProgress = results[2] as InProgressSession?;
          // Prefer the locally re-pruned list (set once the clock has
          // passed an event's start since this Future resolved) over the
          // Future's own resolved value, which never changes on its own.
          final upcoming =
              _liveUpcoming ?? (results[3] as List<UpcomingEventView>);

          return StreamBuilder<Student?>(
            stream: widget.dataService.watchStudent(widget.uid),
            builder: (context, studentSnapshot) {
              final student = studentSnapshot.data;
              // Frame 1 vs Frames 2/2b: a student with zero courses gets the
              // onboarding-only layout — no Today's Progress, no streak, no
              // Upcoming, and no points badge in the greeting. All of that
              // only makes sense once there's at least one course.
              final hasCourses = courses.isNotEmpty;

              return Column(
                children: [
                  _Greeting(
                    student: student,
                    now: widget.now,
                    showPointsBadge: hasCourses,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: hasCourses
                          ? Column(
                              children: [
                                TodayProgressCard(
                                  weeklyProgress: weeklyProgress,
                                  currentStreak: student?.currentStreak ?? 0,
                                  lastStudyDate: student?.lastStudyDate,
                                  now: widget.now,
                                  fetchWeek: _fetchWeek,
                                ),
                                const SizedBox(height: 16),
                                ContinueOrStartCard(
                                  inProgress: inProgress,
                                  onResume: inProgress == null
                                      ? () {}
                                      : () => _resumeSession(inProgress),
                                  onNewQuiz: () =>
                                      _openCoursePicker(SessionKind.quiz),
                                  onNewFlashcards: () => _openCoursePicker(
                                    SessionKind.flashcard,
                                    email: student?.email,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                UpcomingSection(
                                  events: upcoming,
                                  now: widget.now,
                                  onSeeAll: _openCalendarTab,
                                ),
                              ],
                            )
                          : NewStudentOnboardingCard(
                              onCreateFirstCourse: _openAddCourse,
                            ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

String _greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// [color] as-is, unless it's too light to read as small bold text over a
/// near-white background (WCAG contrast under ~4.5:1 against white) — in
/// which case a darkened version is returned instead.
/// [Color.computeLuminance] already implements the WCAG relative-luminance
/// formula, so this needs no hand-rolled colour math. Catches the lighter
/// rank colours (e.g. tier 1's grey `0xFF9AA0C4` and tier 7's amber
/// `0xFFF5A524`) without touching the darker ones, which already read fine
/// as-is.
Color _readableOnLight(Color color) {
  final contrastAgainstWhite = 1.05 / (color.computeLuminance() + 0.05);
  if (contrastAgainstWhite >= 4.5) return color;
  return Color.lerp(color, Colors.black, 0.4) ?? color;
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.student,
    required this.now,
    required this.showPointsBadge,
  });

  final Student? student;
  final DateTime now;
  final bool showPointsBadge;

  @override
  Widget build(BuildContext context) {
    final name = student?.name ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Expanded so a long name ellipsizes instead of pushing the
          // points pill off-screen or overflowing the Row.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greetingFor(now),
                  style: AppTypography.subtitle.copyWith(fontSize: 13),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.02 * 26,
                    height: 1.1,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
          if (showPointsBadge && student != null) ...[
            const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final totalPoints = student!.totalPoints;
                // Derived from totalPoints, not the stored currentRank —
                // matches every other rank display in the app.
                final rank = rankForPoints(totalPoints);
                final textColor = _readableOnLight(rank.color);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    // Same tint style the Ranks screen uses for the
                    // current rank (rank.color at 12% alpha).
                    color: rank.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RankIcon(tier: rank.tier, color: rank.color, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        '${rank.shortName} · $totalPoints',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.home_filled, label: 'Home'),
    (icon: Icons.menu_book, label: 'Courses'),
    (icon: Icons.calendar_today, label: 'Calendar'),
    (icon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: AppColors.navyShadow, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: i == currentIndex
                          ? Colors.white.withValues(alpha: 0.16)
                          : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _items[i].icon,
                          size: 21,
                          color: Colors.white.withValues(
                            alpha: i == currentIndex ? 1 : 0.55,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _items[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(
                              alpha: i == currentIndex ? 1 : 0.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
