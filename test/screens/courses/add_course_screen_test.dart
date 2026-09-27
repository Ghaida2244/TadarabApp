import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/screens/courses/add_course_screen.dart';
import 'package:tadarab_app/widgets/app_button.dart';

import '../../helpers/fake_courses_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    List<Course> existingCourses = const [],
    FakeCoursesService? service,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddCourseScreen(
          uid: 'uid-1',
          coursesService: service ?? FakeCoursesService(),
          existingCourses: existingCourses,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppButton saveButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, 'Save course'));

  Finder swatchFinder() =>
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Swatch');

  testWidgets(
    'no color selected: Save is disabled even with a valid unique name',
    (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'IS230');
      await tester.pump();

      expect(saveButton(tester).onPressed, isNull);
    },
  );

  testWidgets(
    'duplicate name: Save stays disabled and an inline warning shows, '
    'even once a color is picked',
    (tester) async {
      await pump(
        tester,
        existingCourses: [
          Course(
            courseId: 'c1',
            courseName: 'IS230',
            color: '#16A34A',
            email: 'e',
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'IS230');
      await tester.pump();
      // Pick the second preset (blue) — the first (green) is locked, since
      // it's already IS230's color.
      await tester.tap(swatchFinder().at(1));
      await tester.pump();

      expect(find.text('You already have a course named this'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    },
  );

  testWidgets('a valid unique name plus a color enables Save', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'IS230');
    await tester.pump();
    await tester.tap(swatchFinder().first);
    await tester.pump();

    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('Save calls createCourse and pops true on success', (
    tester,
  ) async {
    final service = FakeCoursesService();
    await pump(tester, service: service);

    await tester.enterText(find.byType(TextField), 'IS230');
    await tester.pump();
    await tester.tap(swatchFinder().first);
    await tester.pump();

    await tester.tap(find.text('Save course'));
    await tester.pumpAndSettle();

    expect(service.createCourseCalls, 1);
  });
}
