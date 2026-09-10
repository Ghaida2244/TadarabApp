import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/screens/home/widgets/course_picker_sheet.dart';
import 'package:tadarab_app/services/home_data_service.dart';

import '../helpers/fake_home_data_service.dart';

/// Tests [CoursePickerSheet] directly, independent of Home's own
/// courses-gate — the sheet does its own Firestore fetch (so it stays
/// correct however it's reached), and this covers its empty state, which
/// Home's onboarding gate makes otherwise unreachable through the main UI
/// flow today (New quiz/Flashcards only show once the student has courses).
void main() {
  testWidgets(
    'shows the explanatory empty state, not an error, when the student has no courses',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCoursePickerSheet(
                  context: context,
                  dataService: FakeHomeDataService(courses: const []),
                  uid: 'uid-1',
                  kind: SessionKind.quiz,
                  onCourseSelected: (_) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No courses yet. Once courses are added, they\'ll show up here.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('lists real courses and reports which one was picked', (
    tester,
  ) async {
    Course? picked;
    final course = Course(
      courseId: 'c1',
      courseName: 'IS230',
      email: 'e@x.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCoursePickerSheet(
                context: context,
                dataService: FakeHomeDataService(courses: [course]),
                uid: 'uid-1',
                kind: SessionKind.flashcard,
                onCourseSelected: (c) => picked = c,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('IS230'), findsOneWidget);
    expect(find.text('Flashcards · pick the subject to study'), findsOneWidget);

    await tester.tap(find.text('IS230'));
    await tester.pump();

    expect(picked?.courseId, 'c1');
  });
}
