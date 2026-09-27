import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/screens/courses/courses_list_screen.dart';

import '../../helpers/fake_courses_service.dart';

void main() {
  Future<void> pump(WidgetTester tester, FakeCoursesService service) async {
    await tester.pumpWidget(
      MaterialApp(home: CoursesListScreen(uid: 'uid-1', coursesService: service)),
    );
    await tester.pumpAndSettle();
  }

  group('empty state', () {
    testWidgets('shows the no-courses illustration and CTA, no list', (
      tester,
    ) async {
      await pump(tester, FakeCoursesService());

      expect(find.text('No courses yet'), findsOneWidget);
      expect(find.text('Add your first course'), findsOneWidget);
      expect(find.text('Courses'), findsOneWidget);
    });
  });

  group('list state', () {
    final courses = [
      Course(courseId: 'c1', courseName: 'IS230', color: '#16A34A', email: 'e'),
      Course(courseId: 'c2', courseName: 'CS310', color: '#2563EB', email: 'e'),
    ];

    testWidgets('shows the header count and each course row — no delete '
        'control on this screen', (tester) async {
      await pump(
        tester,
        FakeCoursesService(
          courses: courses,
          materialsByCourse: {
            'c1': [
              StudyMaterial(
                materialId: 'm1',
                title: 'Lecture 1',
                type: 'pptx',
                document: 'd',
                courseId: 'c1',
                extractedText: 't',
              ),
            ],
          },
        ),
      );

      expect(find.text('2 courses'), findsOneWidget);
      expect(find.text('IS230'), findsOneWidget);
      expect(find.text('CS310'), findsOneWidget);
      expect(find.text('1 material'), findsOneWidget);
      expect(find.text('0 materials'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });

  group('reload when becoming the active tab', () {
    testWidgets(
      'a course added elsewhere while this tab was inactive shows up once '
      'it becomes active again — without needing a fresh push/pop',
      (tester) async {
        final service = FakeCoursesService();
        var active = false;

        // Mirrors how HomeScreen embeds this screen in a persistent
        // IndexedStack: the widget stays mounted, only `active` flips.
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => active = !active),
                      child: const Text('toggle active'),
                    ),
                    Expanded(
                      child: CoursesListScreen(
                        uid: 'uid-1',
                        coursesService: service,
                        active: active,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(service.fetchCoursesWithMaterialCountsCalls, 1);
        expect(find.text('No courses yet'), findsOneWidget);

        // A course "created elsewhere" while this tab sat inactive.
        service.courses.add(
          Course(
            courseId: 'c1',
            courseName: 'IS230',
            color: '#16A34A',
            email: 'e',
          ),
        );

        await tester.tap(find.text('toggle active'));
        await tester.pumpAndSettle();

        expect(service.fetchCoursesWithMaterialCountsCalls, 2);
        expect(find.text('IS230'), findsOneWidget);
        expect(find.text('No courses yet'), findsNothing);
      },
    );

    testWidgets('staying active (or going inactive) does not reload', (
      tester,
    ) async {
      final service = FakeCoursesService();

      await tester.pumpWidget(
        MaterialApp(
          home: CoursesListScreen(
            uid: 'uid-1',
            coursesService: service,
            active: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.fetchCoursesWithMaterialCountsCalls, 1);

      // Rebuilding with the same active:true shouldn't trigger a refetch.
      await tester.pumpWidget(
        MaterialApp(
          home: CoursesListScreen(
            uid: 'uid-1',
            coursesService: service,
            active: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.fetchCoursesWithMaterialCountsCalls, 1);
    });
  });
}
