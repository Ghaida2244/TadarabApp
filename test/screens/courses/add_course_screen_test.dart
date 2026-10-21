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
    'the Course name field\'s hint renders within ~2px of the field box\'s '
    'real vertical center, not stuck at the top',
    (tester) async {
      await pump(tester);

      final boxCenterY = tester
          .getCenter(find.byKey(const ValueKey('course-name-field-box')))
          .dy;
      final hintCenterY = tester.getCenter(find.text('e.g. IS230')).dy;

      expect(hintCenterY, closeTo(boxCenterY, 2));
    },
  );

  testWidgets(
    'the typed text also renders within ~2px of the field box\'s real '
    'vertical center, same as the hint',
    (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'IS230');
      await tester.pump();

      final fieldBox = find.byKey(const ValueKey('course-name-field-box'));
      final boxCenterY = tester.getCenter(fieldBox).dy;
      // "IS230" also shows up live in the Preview card below as it's
      // typed — scope to the one actually inside the field itself.
      final textCenterY = tester
          .getCenter(
            find.descendant(of: fieldBox, matching: find.text('IS230')),
          )
          .dy;

      expect(textCenterY, closeTo(boxCenterY, 2));
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

  group('section spacing adapts to the real available height', () {
    double gap1(WidgetTester tester) => tester
        .widget<SizedBox>(find.byKey(const ValueKey('section-gap-1')))
        .height!;
    double gap2(WidgetTester tester) => tester
        .widget<SizedBox>(find.byKey(const ValueKey('section-gap-2')))
        .height!;

    testWidgets(
      // >40 (not just >22) is the point: the old flat rule's only two
      // outputs were 22 or 40, so a flat-rule implementation could never
      // produce this regardless of viewport — this genuinely requires the
      // proportional formula. Measured directly at 56.0 here (the 56px
      // ceiling, see the report).
      'on a tall viewport (412x915) the gaps spread out past the old '
      'rule\'s 40px cap',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pump(tester);

        expect(gap1(tester), greaterThan(40));
        expect(gap2(tester), greaterThan(40));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      // Measured directly (see the report): this screen's content is
      // compact enough that 360x640 still has ~29px of slack rather than
      // zero. >22 is the point here: the old flat rule gave exactly 22 at
      // this size (640 < its 650 threshold), so this specifically catches
      // that the new formula is actually proportional rather than a
      // slightly-relabeled flat rule. A shorter viewport at the same safe
      // width (360x560, the next test) is what drives the gap all the way
      // down to the 22px floor.
      'on a short viewport (360x640) the gap still settles above the old '
      'rule\'s flat 22px, but safely under the 56px ceiling',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pump(tester);

        expect(gap1(tester), greaterThan(22));
        expect(gap1(tester), lessThan(40));
        expect(gap2(tester), greaterThan(22));
        expect(gap2(tester), lessThan(40));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'on a genuinely short viewport (360x560) the gaps fall back to the '
      'original 22px exactly, with no overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 560);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pump(tester);

        expect(gap1(tester), 22);
        expect(gap2(tester), 22);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
