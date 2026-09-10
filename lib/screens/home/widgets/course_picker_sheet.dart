import 'package:flutter/material.dart';

import '../../../models/course.dart';
import '../../../services/home_data_service.dart';
import '../../../theme/app_theme.dart';

/// The "Choose a course" bottom sheet opened from New quiz / Flashcards.
/// Reads the student's real courses straight from Firestore via
/// [HomeDataService.fetchCourses] — no hardcoded list — so the moment the
/// Courses feature exists and courses get added, this sheet shows them
/// automatically with no changes here. Until then, [fetchCourses] always
/// returns an empty list, which is treated as a normal, expected state
/// (not an error) with an explanatory message.
Future<void> showCoursePickerSheet({
  required BuildContext context,
  required HomeDataService dataService,
  required String uid,
  required SessionKind kind,
  required ValueChanged<Course> onCourseSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _CoursePickerSheet(
      dataService: dataService,
      uid: uid,
      kind: kind,
      onCourseSelected: onCourseSelected,
    ),
  );
}

class _CoursePickerSheet extends StatefulWidget {
  const _CoursePickerSheet({
    required this.dataService,
    required this.uid,
    required this.kind,
    required this.onCourseSelected,
  });

  final HomeDataService dataService;
  final String uid;
  final SessionKind kind;
  final ValueChanged<Course> onCourseSelected;

  @override
  State<_CoursePickerSheet> createState() => _CoursePickerSheetState();
}

class _CoursePickerSheetState extends State<_CoursePickerSheet> {
  late final Future<List<Course>> _courses = widget.dataService.fetchCourses(
    widget.uid,
  );

  @override
  Widget build(BuildContext context) {
    final kindLabel = widget.kind == SessionKind.quiz ? 'Quiz' : 'Flashcards';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Choose a course',
              style: AppTypography.screenTitleCompact.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 3),
            Text(
              '$kindLabel · pick the subject to study',
              style: AppTypography.subtitle,
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<Course>>(
              future: _courses,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final courses = snapshot.data ?? const <Course>[];
                if (courses.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No courses yet. Once courses are added, they\'ll show up here.',
                      textAlign: TextAlign.center,
                      style: AppTypography.subtitle,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final course in courses) ...[
                      _CourseRow(
                        course: course,
                        onTap: () => widget.onCourseSelected(course),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = course.courseName.trim().isEmpty
        ? '?'
        : course.courseName.trim().substring(0, 1).toUpperCase();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardTint, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: parseHexColor(course.color),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                course.courseName,
                style: AppTypography.fieldLabel.copyWith(fontSize: 16),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textOnDisabled),
          ],
        ),
      ),
    );
  }
}
