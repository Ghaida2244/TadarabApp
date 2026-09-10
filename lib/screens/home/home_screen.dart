import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../models/student.dart';
import '../../services/home_data_service.dart';
import '../../theme/app_theme.dart';
import '../placeholder_screen.dart';
import 'widgets/continue_or_start_card.dart';
import 'widgets/course_picker_sheet.dart';
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
    this.now,
    this.onSignOut,
  });

  final String uid;

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final HomeDataService? homeDataService;

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
  int _tabIndex = 0;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.homeBackground,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _HomeTab(uid: widget.uid, dataService: _dataService, now: _now),
          const PlaceholderScreen(label: 'Courses screen'),
          const PlaceholderScreen(label: 'Calendar screen'),
          PlaceholderScreen(
            label: 'Profile screen',
            actions: widget.onSignOut == null
                ? null
                : [
                    ElevatedButton(
                      onPressed: widget.onSignOut,
                      child: const Text('Log out'),
                    ),
                  ],
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.uid,
    required this.dataService,
    required this.now,
  });

  final String uid;
  final HomeDataService dataService;
  final DateTime now;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late final Future<WeeklyProgress> _weeklyProgress = widget.dataService
      .fetchWeeklyProgress(widget.uid, now: widget.now);
  late final Future<InProgressSession?> _inProgress = widget.dataService
      .fetchInProgressSession(widget.uid);
  late final Future<List<UpcomingEventView>> _upcoming = widget.dataService
      .fetchUpcomingEvents(widget.uid, now: widget.now);

  void _openSetupPlaceholder(SessionKind kind) {
    final label = kind == SessionKind.quiz
        ? 'Quiz setup screen'
        : 'Flashcard setup screen';
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PlaceholderScreen(label: label)));
  }

  void _openCoursePicker(SessionKind kind) {
    showCoursePickerSheet(
      context: context,
      dataService: widget.dataService,
      uid: widget.uid,
      kind: kind,
      onCourseSelected: (Course course) {
        Navigator.of(context).pop();
        _openSetupPlaceholder(kind);
      },
    );
  }

  void _resumeSession(InProgressSession session) {
    final label = session.kind == SessionKind.quiz
        ? 'Quiz session screen'
        : 'Flashcard session screen';
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PlaceholderScreen(label: label)));
  }

  void _openCalendarTab() {
    // The bottom-nav Calendar tab isn't reachable from here without lifting
    // tab state up; "See all" is a reasonable no-op-with-navigation stand-in
    // until Calendar (Phase C) exists to actually navigate to.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PlaceholderScreen(label: 'Calendar screen'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          StreamBuilder<Student?>(
            stream: widget.dataService.watchStudent(widget.uid),
            builder: (context, snapshot) =>
                _Greeting(student: snapshot.data, now: widget.now),
          ),
          Expanded(
            child: FutureBuilder(
              future: Future.wait([_weeklyProgress, _inProgress, _upcoming]),
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
                final weeklyProgress = results[0] as WeeklyProgress;
                final inProgress = results[1] as InProgressSession?;
                final upcoming = results[2] as List<UpcomingEventView>;

                return StreamBuilder<Student?>(
                  stream: widget.dataService.watchStudent(widget.uid),
                  builder: (context, studentSnapshot) {
                    final streak = studentSnapshot.data?.currentStreak ?? 0;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        children: [
                          TodayProgressCard(
                            weeklyProgress: weeklyProgress,
                            currentStreak: streak,
                            now: widget.now,
                          ),
                          const SizedBox(height: 16),
                          ContinueOrStartCard(
                            inProgress: inProgress,
                            onResume: inProgress == null
                                ? () {}
                                : () => _resumeSession(inProgress),
                            onNewQuiz: () =>
                                _openCoursePicker(SessionKind.quiz),
                            onFlashcards: () =>
                                _openCoursePicker(SessionKind.flashcard),
                          ),
                          const SizedBox(height: 16),
                          UpcomingSection(
                            events: upcoming,
                            now: widget.now,
                            onSeeAll: _openCalendarTab,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.student, required this.now});

  final Student? student;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final name = student?.name ?? '';
    final initial = name.trim().isEmpty
        ? ''
        : name.trim().substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greetingFor(now),
                style: AppTypography.subtitle.copyWith(fontSize: 13),
              ),
              Text(
                name,
                style: AppTypography.screenTitleCompact.copyWith(fontSize: 26),
              ),
            ],
          ),
          Row(
            children: [
              if (student != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.pointsBadgeDot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${student!.totalPoints}',
                        style: AppTypography.fieldLabel.copyWith(
                          fontSize: 13,
                          color: AppColors.warningText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.cardTint,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: AppTypography.fieldLabel.copyWith(fontSize: 17),
                ),
              ),
            ],
          ),
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
