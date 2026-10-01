import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/screens/courses/course_detail_screen.dart';
import 'package:tadarab_app/services/courses_service.dart';

import '../../helpers/fake_courses_service.dart';

void main() {
  final course = Course(
    courseId: 'c1',
    courseName: 'IS230',
    color: '#16A34A',
    email: 'e',
  );

  Future<void> pump(WidgetTester tester, FakeCoursesService service) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CourseDetailScreen(
          uid: 'uid-1',
          course: course,
          coursesService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('locked (no materials)', () {
    testWidgets(
      'Study Tools show the unlock message and are not tappable',
      (tester) async {
        await pump(tester, FakeCoursesService());

        expect(
          find.text('Upload a material to unlock quizzes and flashcards.'),
          findsOneWidget,
        );
        expect(find.text('Add your first material'), findsOneWidget);

        await tester.tap(find.text('Quiz'));
        await tester.pumpAndSettle();
        expect(find.text('Study tools screen'), findsNothing);
      },
    );
  });

  group('unlocked (has materials)', () {
    final materials = [
      StudyMaterial(
        materialId: 'm1',
        title: 'Lecture 1',
        type: 'pptx',
        document: 'd',
        courseId: 'c1',
        extractedText: 't',
      ),
    ];

    testWidgets('Study Tools are tappable and the materials list shows', (
      tester,
    ) async {
      await pump(
        tester,
        FakeCoursesService(materialsByCourse: {'c1': materials}),
      );

      expect(
        find.text('Upload a material to unlock quizzes and flashcards.'),
        findsNothing,
      );
      expect(find.text('Lecture 1'), findsOneWidget);
      expect(find.text('All 1'), findsOneWidget);

      await tester.tap(find.text('Quiz'));
      await tester.pumpAndSettle();
      expect(find.text('Study tools screen'), findsOneWidget);
    });

    testWidgets('the type filter tabs narrow the visible materials list', (
      tester,
    ) async {
      await pump(
        tester,
        FakeCoursesService(
          materialsByCourse: {
            'c1': [
              ...materials,
              StudyMaterial(
                materialId: 'm2',
                title: 'Notes',
                type: 'docx',
                document: 'd2',
                courseId: 'c1',
                extractedText: 't',
              ),
            ],
          },
        ),
      );

      expect(find.text('Lecture 1'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);

      await tester.tap(find.text('PPTX 1'));
      await tester.pumpAndSettle();

      expect(find.text('Lecture 1'), findsOneWidget);
      expect(find.text('Notes'), findsNothing);
    });
  });

  group('delete', () {
    testWidgets('tapping the trash icon opens the confirmation dialog', (
      tester,
    ) async {
      await pump(tester, FakeCoursesService());

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete IS230?'), findsOneWidget);
      expect(
        find.text(
          'Deleting this course will also delete all its materials, '
          "quizzes, and flashcard sessions. This can't be undone.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('confirming calls deleteCourse and pops true', (
      tester,
    ) async {
      final service = FakeCoursesService();
      await pump(tester, service);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete course'));
      await tester.pumpAndSettle();

      expect(service.deleteCourseCalls, 1);
    });

    testWidgets('"Keep it" dismisses with no change', (tester) async {
      final service = FakeCoursesService();
      await pump(tester, service);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(service.deleteCourseCalls, 0);
      expect(find.text('IS230'), findsOneWidget);
    });
  });

  group('delete material', () {
    final material = StudyMaterial(
      materialId: 'm1',
      title: 'Lecture 1',
      type: 'pptx',
      document: 'd',
      courseId: 'c1',
      extractedText: 't',
    );
    final secondMaterial = StudyMaterial(
      materialId: 'm2',
      title: 'Notes',
      type: 'docx',
      document: 'd2',
      courseId: 'c1',
      extractedText: 't',
    );

    testWidgets('each material row shows a trash icon', (tester) async {
      await pump(
        tester,
        FakeCoursesService(
          materialsByCourse: {
            'c1': [material, secondMaterial],
          },
        ),
      );

      // One for the course-delete icon in the header, one per material row.
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(3));
    });

    testWidgets('tapping a material row trash icon opens the confirmation '
        'dialog with that material\'s name', (tester) async {
      await pump(
        tester,
        FakeCoursesService(materialsByCourse: {'c1': [material]}),
      );

      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      expect(find.text('Delete Lecture 1?'), findsOneWidget);
      expect(
        find.text(
          "This material will be permanently deleted. This can't be undone.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Keep it" dismisses with no change', (tester) async {
      final service = FakeCoursesService(
        materialsByCourse: {'c1': [material]},
      );
      await pump(tester, service);

      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(service.deleteMaterialCalls, 0);
      expect(find.text('Lecture 1'), findsOneWidget);
    });

    testWidgets(
      'confirming deletes the material and updates the list immediately, '
      'without navigating away',
      (tester) async {
        final service = FakeCoursesService(
          materialsByCourse: {
            'c1': [material, secondMaterial],
          },
        );
        await pump(tester, service);

        await tester.tap(find.byIcon(Icons.delete_outline).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete material'));
        await tester.pumpAndSettle();

        expect(service.deleteMaterialCalls, 1);
        expect(find.text('Notes'), findsNothing);
        // Still on Course Detail — the remaining material is visible.
        expect(find.text('Lecture 1'), findsOneWidget);
      },
    );

    testWidgets('a failure shows a SnackBar with Retry, and the row stays', (
      tester,
    ) async {
      final service = FakeCoursesService(
        materialsByCourse: {'c1': [material]},
        deleteMaterialError: CoursesFailure('Network error.'),
      );
      await pump(tester, service);

      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete material'));
      await tester.pumpAndSettle();

      expect(find.text('Network error.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Lecture 1'), findsOneWidget);
    });

    testWidgets(
      'deleting the last material re-locks Study Tools and shows the '
      'empty state',
      (tester) async {
        final service = FakeCoursesService(
          materialsByCourse: {'c1': [material]},
        );
        await pump(tester, service);

        expect(
          find.text('Upload a material to unlock quizzes and flashcards.'),
          findsNothing,
        );

        await tester.tap(find.byIcon(Icons.delete_outline).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete material'));
        await tester.pumpAndSettle();

        expect(
          find.text('Upload a material to unlock quizzes and flashcards.'),
          findsOneWidget,
        );
        expect(find.text('Add your first material'), findsOneWidget);
      },
    );
  });
}
