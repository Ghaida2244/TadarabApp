import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../services/courses_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import 'add_course_screen.dart';
import 'course_detail_screen.dart';
import 'widgets/course_icon.dart';

/// The Courses tab's entry screen: empty state or the course list, with the
/// `+` header button to add a course. No delete control here — deleting a
/// course only happens from inside Course Detail
/// (courses_material_upload_spec.md §1/§3).
class CoursesListScreen extends StatefulWidget {
  const CoursesListScreen({
    super.key,
    required this.uid,
    this.coursesService,
    this.active = true,
  });

  final String uid;

  /// Overridable for tests; defaults to the real Firebase-backed service.
  final CoursesService? coursesService;

  /// Whether this is the currently-selected bottom-nav tab. When embedded
  /// in Home's persistent IndexedStack, this screen's State survives tab
  /// switches, so a course created elsewhere (e.g. Home's onboarding
  /// "Create my first course" button) wouldn't otherwise show up here
  /// until something else happened to trigger a reload. Defaults to true
  /// for standalone use (e.g. pushed directly, or in tests).
  final bool active;

  @override
  State<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen> {
  late final _service = widget.coursesService ?? CoursesService();
  late Future<List<CourseListItem>> _courses = _service
      .fetchCoursesWithMaterialCounts(widget.uid);

  @override
  void didUpdateWidget(covariant CoursesListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _reload();
  }

  void _reload() {
    setState(() {
      _courses = _service.fetchCoursesWithMaterialCounts(widget.uid);
    });
  }

  Future<void> _openAddCourse() async {
    final items = await _courses;
    if (!mounted) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddCourseScreen(
          uid: widget.uid,
          coursesService: _service,
          existingCourses: [for (final item in items) item.course],
        ),
      ),
    );
    if (created == true) _reload();
  }

  Future<void> _openCourseDetail(Course course) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CourseDetailScreen(
          uid: widget.uid,
          course: course,
          coursesService: _service,
        ),
      ),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.homeBackground,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<CourseListItem>>(
          future: _courses,
          builder: (context, snapshot) {
            final items = snapshot.data;
            final loading = snapshot.connectionState != ConnectionState.done;
            final hasError = snapshot.hasError;

            return Column(
              children: [
                _Header(
                  courseCount: loading || hasError ? null : items!.length,
                  onAdd: _openAddCourse,
                ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : hasError
                      ? _ErrorState(onRetry: _reload)
                      : items!.isEmpty
                      ? _EmptyState(onAdd: _openAddCourse)
                      : _CourseList(items: items, onTap: _openCourseDetail),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.courseCount, required this.onAdd});

  final int? courseCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Courses',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.02 * 26,
                  color: Colors.white,
                ),
              ),
              if (courseCount != null)
                Text(
                  '$courseCount course${courseCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
            ],
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.all(Radius.circular(14)),
                boxShadow: [
                  BoxShadow(color: AppColors.redShadow, offset: Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.add, size: 24, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardTint,
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 52,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No courses yet',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'A course holds your material, quizzes and flashcards '
            'sessions for one subject.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Add your first course',
            onPressed: onAdd,
            variant: AppButtonVariant.accent,
            borderRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load your courses.",
              style: AppTypography.subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Retry',
              onPressed: onRetry,
              variant: AppButtonVariant.outlinedBrand,
              height: AppDimens.secondaryButtonHeight,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseList extends StatelessWidget {
  const _CourseList({required this.items, required this.onTap});

  final List<CourseListItem> items;
  final ValueChanged<Course> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _CourseRow(item: item, onTap: () => onTap(item.course));
      },
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.item, required this.onTap});

  final CourseListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140B0F5B),
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CourseIcon(
              color: parseHexColor(item.course.color),
              courseName: item.course.courseName,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.course.courseName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.materialCount} material${item.materialCount == 1 ? '' : 's'}',
                    style: AppTypography.subtitle.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textOnDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
