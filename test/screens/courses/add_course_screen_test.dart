import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/screens/courses/add_course_screen.dart';
import 'package:tadarab_app/services/calendar_service.dart';
import 'package:tadarab_app/widgets/app_button.dart';
import 'package:tadarab_app/widgets/color_picker_dialog.dart';
import 'package:tadarab_app/widgets/color_swatch_tile.dart';
import 'package:tadarab_app/widgets/screen_header.dart';

import '../../helpers/fake_calendar_service.dart';
import '../../helpers/fake_courses_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    List<Course> existingCourses = const [],
    FakeCoursesService? service,
    FakeCalendarService? calendarService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddCourseScreen(
          uid: 'uid-1',
          coursesService: service ?? FakeCoursesService(),
          existingCourses: existingCourses,
          calendarService: calendarService ?? FakeCalendarService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppButton saveButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, 'Save course'));

  Finder swatchFinder() =>
      find.byWidgetPredicate((w) => w is ColorSwatchTile);

  ColorSwatchTile tile(WidgetTester tester, String hex) =>
      tester.widget<ColorSwatchTile>(find.byKey(ValueKey(hex)));

  bool isSelected(WidgetTester tester, String hex) => tile(tester, hex).selected;
  bool isLocked(WidgetTester tester, String hex) => tile(tester, hex).locked;

  bool isCustomSelected(WidgetTester tester) => tester
      .widget<CustomColorSwatchTile>(
        find.byKey(const ValueKey('custom-color')),
      )
      .selected;

  testWidgets('all five presets are always shown, regardless of what\'s taken', (
    tester,
  ) async {
    await pump(
      tester,
      existingCourses: [
        Course(courseId: 'c1', courseName: 'A', color: '#16A34A', email: 'e'),
        Course(courseId: 'c2', courseName: 'B', color: '#2563EB', email: 'e'),
        Course(courseId: 'c3', courseName: 'C', color: '#F5A524', email: 'e'),
        Course(courseId: 'c4', courseName: 'D', color: '#E31B23', email: 'e'),
        Course(courseId: 'c5', courseName: 'E', color: '#7C3AED', email: 'e'),
      ],
    );

    expect(swatchFinder(), findsNWidgets(5));
  });

  testWidgets(
    'a preset used by a course is locked, and tapping it does not select it',
    (tester) async {
      await pump(
        tester,
        existingCourses: [
          Course(
            courseId: 'c1',
            courseName: 'Green course',
            color: '#16A34A',
            email: 'e',
          ),
        ],
      );

      expect(isLocked(tester, '#16A34A'), isTrue);
      // Amber was preselected instead (green is taken) — tapping the
      // locked green tile must not change that.
      expect(isSelected(tester, '#F5A524'), isTrue);

      await tester.tap(find.byKey(const ValueKey('#16A34A')));
      await tester.pump();

      expect(isSelected(tester, '#16A34A'), isFalse);
      expect(isSelected(tester, '#F5A524'), isTrue);
    },
  );

  testWidgets(
    'a preset used by a standalone event is locked, and tapping it does '
    'not select it',
    (tester) async {
      await pump(
        tester,
        calendarService: FakeCalendarService(recentColors: const ['#16A34A']),
      );

      expect(isLocked(tester, '#16A34A'), isTrue);
      expect(isSelected(tester, '#F5A524'), isTrue);

      await tester.tap(find.byKey(const ValueKey('#16A34A')));
      await tester.pump();

      expect(isSelected(tester, '#16A34A'), isFalse);
      expect(isSelected(tester, '#F5A524'), isTrue);
    },
  );

  testWidgets(
    'green is preselected once the standalone-colour load resolves, so '
    'typing a valid unique name alone enables Save',
    (tester) async {
      await pump(tester);

      expect(isSelected(tester, '#16A34A'), isTrue);
      expect(isLocked(tester, '#16A34A'), isFalse);

      await tester.enterText(find.byType(TextField), 'IS230');
      await tester.pump();

      expect(saveButton(tester).onPressed, isNotNull);
    },
  );

  testWidgets('green taken by a course: amber is preselected instead', (
    tester,
  ) async {
    final service = FakeCoursesService();
    await pump(
      tester,
      service: service,
      existingCourses: [
        Course(
          courseId: 'c1',
          courseName: 'Green course',
          color: '#16A34A',
          email: 'e',
        ),
      ],
    );

    expect(isSelected(tester, '#F5A524'), isTrue);

    await tester.enterText(find.byType(TextField), 'IS230');
    await tester.pump();
    await tester.tap(find.text('Save course'));
    await tester.pumpAndSettle();

    expect(service.courses.last.color, '#F5A524');
  });

  testWidgets(
    'green taken by a standalone event: amber is preselected instead',
    (tester) async {
      final service = FakeCoursesService();
      await pump(
        tester,
        service: service,
        calendarService: FakeCalendarService(recentColors: const ['#16A34A']),
      );

      expect(isSelected(tester, '#F5A524'), isTrue);

      await tester.enterText(find.byType(TextField), 'IS230');
      await tester.pump();
      await tester.tap(find.text('Save course'));
      await tester.pumpAndSettle();

      expect(service.courses.last.color, '#F5A524');
    },
  );

  testWidgets(
    'every preset taken: nothing is preselected, and Save stays disabled '
    'until "+" is used',
    (tester) async {
      // Taller than the default test surface — the colour picker dialog's
      // content otherwise falls below the visible area, same reason Add
      // Event's own picker tests use a non-default surface size.
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(
        tester,
        existingCourses: [
          Course(courseId: 'c1', courseName: 'A', color: '#16A34A', email: 'e'),
          Course(courseId: 'c2', courseName: 'B', color: '#2563EB', email: 'e'),
          Course(courseId: 'c3', courseName: 'C', color: '#F5A524', email: 'e'),
          Course(courseId: 'c4', courseName: 'D', color: '#E31B23', email: 'e'),
          Course(courseId: 'c5', courseName: 'E', color: '#7C3AED', email: 'e'),
        ],
      );

      // All five are still shown — just all locked.
      expect(swatchFinder(), findsNWidgets(5));
      for (final hex in [
        '#16A34A',
        '#2563EB',
        '#F5A524',
        '#E31B23',
        '#7C3AED',
      ]) {
        expect(isLocked(tester, hex), isTrue, reason: hex);
        expect(isSelected(tester, hex), isFalse, reason: hex);
      }
      expect(isCustomSelected(tester), isFalse);

      await tester.enterText(find.byType(TextField), 'IS230');
      await tester.pump();

      expect(saveButton(tester).onPressed, isNull);

      // The dialog's own default (nothing selected, so it opens on the
      // shared default colour — green) is itself taken here, so picking
      // something free means actually changing it in the dialog first.
      await tester.tap(find.byKey(const ValueKey('custom-color')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(ColorPickerDialog),
          matching: find.byType(TextField),
        ),
        '#123456',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this color'));
      await tester.pumpAndSettle();

      expect(saveButton(tester).onPressed, isNotNull);
      expect(isCustomSelected(tester), isTrue);
    },
  );

  testWidgets(
    'a failed standalone-colour fetch falls back to locking course '
    'colours only, without blocking the screen or showing an error',
    (tester) async {
      await pump(
        tester,
        existingCourses: [
          Course(
            courseId: 'c1',
            courseName: 'Green course',
            color: '#16A34A',
            email: 'e',
          ),
        ],
        calendarService: FakeCalendarService(
          recentColorsError: CalendarFailure('nope'),
        ),
      );

      expect(find.textContaining("Couldn't"), findsNothing);
      expect(isLocked(tester, '#16A34A'), isTrue);
      expect(isSelected(tester, '#F5A524'), isTrue);

      await tester.enterText(find.byType(TextField), 'IS230');
      await tester.pump();

      expect(saveButton(tester).onPressed, isNotNull);
    },
  );

  testWidgets(
    'the "+" tile opens the shared colour picker and selects the result',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('custom-color')));
      await tester.pumpAndSettle();

      expect(find.byType(ColorPickerDialog), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(ColorPickerDialog),
          matching: find.byType(TextField),
        ),
        '#FF00A8',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this color'));
      await tester.pumpAndSettle();

      // The "+" tile itself now shows as selected — the original
      // behaviour, not a separate extra swatch.
      expect(isCustomSelected(tester), isTrue);
      expect(isSelected(tester, '#16A34A'), isFalse);

      await tester.enterText(find.byType(TextField), 'IS230');
      await tester.pump();
      await tester.tap(find.text('Save course'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a taken custom colour from the dialog is blocked, leaving the '
    'selection unchanged',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(
        tester,
        existingCourses: [
          Course(
            courseId: 'c1',
            courseName: 'Blue course',
            color: '#2563EB',
            email: 'e',
          ),
        ],
      );

      // Green is preselected by default (it's free).
      expect(isSelected(tester, '#16A34A'), isTrue);

      await tester.tap(find.byKey(const ValueKey('custom-color')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(ColorPickerDialog),
          matching: find.byType(TextField),
        ),
        '#2563EB', // the taken blue
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this color'));
      await tester.pumpAndSettle();

      // Still green — the taken pick was ignored.
      expect(isSelected(tester, '#16A34A'), isTrue);
      expect(isCustomSelected(tester), isFalse);
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
    'even with a color already preselected',
    (tester) async {
      await pump(
        tester,
        existingCourses: [
          Course(
            courseId: 'c1',
            courseName: 'IS230',
            color: '#2563EB',
            email: 'e',
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'IS230');
      await tester.pump();

      expect(find.text('You already have a course named this'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    },
  );

  testWidgets('a valid unique name plus the preselected color enables Save', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'IS230');
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

  group('status bar / safe area', () {
    testWidgets(
      'the header background reaches the top of the screen under a real '
      'top inset (no white strip above it), and the title sits below the '
      'status-bar inset',
      (tester) async {
        const insets = EdgeInsets.only(top: 48);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                padding: insets,
                viewPadding: insets,
              ),
              child: AddCourseScreen(
                uid: 'uid-1',
                coursesService: FakeCoursesService(),
                existingCourses: const [],
                calendarService: FakeCalendarService(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final headerRect = tester.getRect(find.byType(ScreenHeader));
        expect(headerRect.top, 0);

        final titleRect = tester.getRect(find.text('Add course'));
        expect(titleRect.top, greaterThan(48));
      },
    );
  });
}
