import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_sessions_screen.dart';
import 'package:tadarab_app/logic/materials_search.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/screens/courses/course_detail_screen.dart';
import 'package:tadarab_app/services/courses_service.dart';
import 'package:tadarab_app/screens/courses/widgets/upload_material_sheet.dart';
import 'package:tadarab_app/theme/app_theme.dart';

import '../../helpers/fake_courses_service.dart';
import '../../helpers/fake_flashcard_service.dart';

void main() {
  final course = Course(
    courseId: 'c1',
    courseName: 'IS230',
    color: '#16A34A',
    email: 'e',
  );

  Future<void> pump(
    WidgetTester tester,
    FakeCoursesService service, {
    FakeFlashcardService? flashcardService,
    Future<PickedFile?> Function()? pickFile,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CourseDetailScreen(
          uid: 'uid-1',
          course: course,
          coursesService: service,
          flashcardService: flashcardService,
          pickFile: pickFile,
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

        // Locked tiles stay flat — no shadow — same as before this fix.
        final quizContainer = tester.widget<Container>(
          find.ancestor(
            of: find.text('Quiz'),
            matching: find.byType(Container),
          ).first,
        );
        expect(
          (quizContainer.decoration! as BoxDecoration).boxShadow,
          isNull,
        );

        await tester.tap(find.text('Quiz'));
        await tester.pumpAndSettle();
        expect(find.text('Quiz sessions'), findsNothing);
      },
    );

    testWidgets(
      'the search + sort row does not show at all with zero materials — '
      'the existing empty state is untouched',
      (tester) async {
        await pump(tester, FakeCoursesService());

        expect(find.byType(TextField), findsNothing);
        expect(find.byIcon(Icons.sort), findsNothing);
      },
    );

    testWidgets(
      'the empty "Add your first material" card centers vertically in the '
      'space below Study Tools (roughly equal slack above and below)',
      (tester) async {
        // The default 800x600 test surface is too short for the card's
        // natural content to leave any slack to center into (it fills or
        // exceeds the available space, so the scroll fallback — not
        // centering — legitimately takes over). Use a taller viewport,
        // closer to a real device, so there's genuine room to center.
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pump(tester, FakeCoursesService());

        final available = tester.getRect(find.byType(LayoutBuilder));
        final card = tester.getRect(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_EmptyMaterials',
          ),
        );

        final topSlack = card.top - available.top;
        final bottomSlack = available.bottom - card.bottom;

        expect(topSlack, greaterThan(20));
        expect(bottomSlack, greaterThan(20));
        expect((topSlack - bottomSlack).abs(), lessThan(40));
      },
    );

    testWidgets(
      'the populated materials list renders from the top instead of '
      'centering, even on the same tall viewport',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pump(
          tester,
          FakeCoursesService(
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

        // The "has materials" state's own scroll area — a CustomScrollView
        // now (Study Tools + the title/upload row scroll away, the
        // search + sort row pins underneath them).
        final available = tester.getRect(find.byType(CustomScrollView));
        final heading = tester.getTopLeft(find.text('Course materials'));

        // Hugs the top of the available area (just Study Tools' own
        // height above it) — nowhere near the ~half-of-available offset
        // centering would produce on this 1600px-tall viewport.
        expect(heading.dy - available.top, lessThan(available.height * 0.3));
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
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.sort), findsOneWidget);

      await tester.tap(find.text('Quiz'));
      // Not pumpAndSettle: QuizSessionsScreen shows a CircularProgress-
      // Indicator while its Firestore fetch is pending (no real Firebase
      // app in this test, so it never resolves) — an indeterminate spinner
      // animates forever, which would make pumpAndSettle hang. See the
      // identical pattern in home_screen_test.dart's course-picker test.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Quiz sessions'), findsOneWidget);
    });

    testWidgets(
      'unlocked: the Quiz and Flashcards tiles have the design\'s hard '
      'bottom-edge shadow (navy@0.1 / red@0.18, offset (0,3), no blur)',
      (tester) async {
        await pump(
          tester,
          FakeCoursesService(materialsByCourse: {'c1': materials}),
        );

        final quizContainer = tester.widget<Container>(
          find.ancestor(
            of: find.text('Quiz'),
            matching: find.byType(Container),
          ).first,
        );
        final quizShadow =
            (quizContainer.decoration! as BoxDecoration).boxShadow!.single;
        expect(quizShadow.color, AppColors.navy.withValues(alpha: 0.1));
        expect(quizShadow.offset, const Offset(0, 3));
        expect(quizShadow.blurRadius, 0);

        final flashcardsContainer = tester.widget<Container>(
          find.ancestor(
            of: find.text('Flashcards'),
            matching: find.byType(Container),
          ).first,
        );
        final flashcardsShadow =
            (flashcardsContainer.decoration! as BoxDecoration)
                .boxShadow!
                .single;
        expect(flashcardsShadow.color, AppColors.red.withValues(alpha: 0.18));
        expect(flashcardsShadow.offset, const Offset(0, 3));
        expect(flashcardsShadow.blurRadius, 0);
      },
    );

    testWidgets(
      'Flashcards tile opens the real Flashcard sessions screen, not a '
      'placeholder',
      (tester) async {
        await pump(
          tester,
          FakeCoursesService(materialsByCourse: {'c1': materials}),
          // Unlike QuizSessionService's fetchSessions (an async method,
          // so a no-Firebase-app error gets wrapped into its returned
          // Future rather than thrown), FlashcardService.watchSessions is
          // a plain synchronous function called directly from build(), so
          // it throws immediately without a fake backing it here.
          flashcardService: FakeFlashcardService(),
        );

        await tester.tap(find.text('Flashcards'));
        await tester.pumpAndSettle();
        // Asserting by widget type (rather than the header's own
        // "Flashcards" text, which would collide with the tile's
        // identical label still in the tree underneath) is unambiguous.
        expect(find.byType(FlashcardSessionsScreen), findsOneWidget);
        expect(find.text('Flashcard setup screen'), findsNothing);
      },
    );

    testWidgets('searching narrows the visible materials list, '
        'case-insensitively and trimmed', (tester) async {
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

      await tester.enterText(find.byType(TextField), '  LECTURE  ');
      await tester.pumpAndSettle();

      expect(find.text('Lecture 1'), findsOneWidget);
      expect(find.text('Notes'), findsNothing);
    });

    testWidgets(
      'a search matching nothing shows the "No materials match" card, and '
      '"Clear search" empties the field again',
      (tester) async {
        await pump(
          tester,
          FakeCoursesService(materialsByCourse: {'c1': materials}),
        );

        await tester.enterText(find.byType(TextField), 'midterm');
        await tester.pumpAndSettle();

        expect(find.text('Lecture 1'), findsNothing);
        expect(find.text('No materials match'), findsOneWidget);
        expect(
          find.text(
            'Nothing in this course has "midterm" in its name. Check the '
            'spelling or try a shorter word.',
          ),
          findsOneWidget,
        );

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clear search'));
        await tester.pumpAndSettle();

        expect(find.text('No materials match'), findsNothing);
        expect(find.text('Lecture 1'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
      },
    );

    testWidgets(
      'the matched part of a title is highlighted in red, case-'
      'insensitively',
      (tester) async {
        await pump(
          tester,
          FakeCoursesService(materialsByCourse: {'c1': materials}),
        );

        await tester.enterText(find.byType(TextField), 'LECTURE');
        await tester.pumpAndSettle();

        final materialRow = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_MaterialRow',
        );
        // The title renders via Text.rich (a Text with .textSpan set, not
        // .data) — a plain find.byType(RichText) would also match the
        // type-badge's own internal RichText (every Text, even a plain
        // one, renders through one), so this looks for the Text widget
        // itself instead.
        final titleText = tester.widget<Text>(
          find
              .descendant(
                of: materialRow,
                matching: find.byWidgetPredicate(
                  (w) => w is Text && w.textSpan != null,
                ),
              )
              .first,
        );
        final span = titleText.textSpan! as TextSpan;
        final matchSpan =
            span.children!.firstWhere(
                  (s) => (s as TextSpan).text == 'Lecture',
                )
                as TextSpan;
        expect(matchSpan.style!.color, AppColors.red);
      },
    );

    testWidgets(
      'sort: "A to Z" reorders the list, and the sort button shows the '
      'applied state',
      (tester) async {
        await pump(
          tester,
          FakeCoursesService(
            materialsByCourse: {
              'c1': [
                StudyMaterial(
                  materialId: 'm1',
                  title: 'Zebra notes',
                  type: 'txt',
                  document: 'd1',
                  courseId: 'c1',
                  extractedText: 't',
                ),
                StudyMaterial(
                  materialId: 'm2',
                  title: 'Apple notes',
                  type: 'txt',
                  document: 'd2',
                  courseId: 'c1',
                  extractedText: 't',
                ),
              ],
            },
          ),
        );

        await tester.tap(find.byIcon(Icons.sort));
        await tester.pumpAndSettle();
        expect(find.text('SORT BY'), findsOneWidget);
        expect(find.text('Newest first'), findsOneWidget);
        expect(find.text('Oldest first'), findsOneWidget);

        await tester.tap(find.text('A to Z'));
        await tester.pumpAndSettle();

        // Titles render via Text.rich, so find.text still matches them
        // (it checks textSpan.toPlainText() too) — order is confirmed by
        // vertical position, since both are now on screen simultaneously.
        expect(find.text('Apple notes'), findsOneWidget);
        expect(find.text('Zebra notes'), findsOneWidget);
        final appleTop = tester.getTopLeft(find.text('Apple notes')).dy;
        final zebraTop = tester.getTopLeft(find.text('Zebra notes')).dy;
        expect(appleTop, lessThan(zebraTop));

        final sortButtonContainer = tester.widget<Container>(
          find.descendant(
            of: find.byType(PopupMenuButton<MaterialSortOrder>),
            matching: find.byType(Container),
          ).first,
        );
        expect(
          (sortButtonContainer.decoration as BoxDecoration).color,
          AppColors.navy,
        );
      },
    );

    testWidgets(
      'with many materials, the search + sort row stays pinned while Study '
      'Tools and the title scroll away',
      (tester) async {
        final many = List.generate(
          15,
          (i) => StudyMaterial(
            materialId: 'm$i',
            title: 'Lecture $i',
            type: 'pptx',
            document: 'd$i',
            courseId: 'c1',
            extractedText: 't',
          ),
        );
        await pump(
          tester,
          FakeCoursesService(materialsByCourse: {'c1': many}),
        );

        expect(find.text('Study tools'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -500),
        );
        await tester.pump();

        expect(find.text('Study tools'), findsNothing);
        expect(find.text('Course materials'), findsNothing);
        // Still pinned under the (now scrolled-away) header.
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.sort), findsOneWidget);
      },
    );

    testWidgets(
      'deleting a visible (search-matching) material keeps the search '
      'active and the remaining matching material still shows',
      (tester) async {
        final lecture2 = StudyMaterial(
          materialId: 'm2',
          title: 'Lecture 2',
          type: 'docx',
          document: 'd2',
          courseId: 'c1',
          extractedText: 't',
        );
        final notes = StudyMaterial(
          materialId: 'm3',
          title: 'Notes',
          type: 'txt',
          document: 'd3',
          courseId: 'c1',
          extractedText: 't',
        );
        final service = FakeCoursesService(
          materialsByCourse: {
            'c1': [...materials, lecture2, notes],
          },
        );
        await pump(tester, service);

        await tester.enterText(find.byType(TextField), 'lecture');
        await tester.pumpAndSettle();
        // Both "Lecture" materials match; "Notes" is filtered out — only
        // 2 delete icons exist in the tree now (course header's + exactly
        // one row's), not 3, confirming "Notes" isn't just hidden but
        // genuinely not rendered.
        expect(find.text('Lecture 1'), findsOneWidget);
        expect(find.text('Lecture 2'), findsOneWidget);
        expect(find.text('Notes'), findsNothing);
        expect(find.byIcon(Icons.delete_outline), findsNWidgets(3));

        // Delete "Lecture 1" specifically (the row immediately following
        // its own title in the tree).
        await tester.tap(
          find
              .descendant(
                of: find.ancestor(
                  of: find.text('Lecture 1'),
                  matching: find.byWidgetPredicate(
                    (w) => w.runtimeType.toString() == '_MaterialRow',
                  ),
                ),
                matching: find.byIcon(Icons.delete_outline),
              ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete material'));
        await tester.pumpAndSettle();

        // The search survived the reload and still filters correctly:
        // "Lecture 1" is gone from the data, "Lecture 2" still matches and
        // still shows, "Notes" is still excluded.
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'lecture',
        );
        expect(find.text('Lecture 1'), findsNothing);
        expect(find.text('Lecture 2'), findsOneWidget);
        expect(find.text('Notes'), findsNothing);
      },
    );

    testWidgets(
      'uploading a new material while a search is active keeps the '
      'search, and the new material shows up if it matches',
      (tester) async {
        final service = FakeCoursesService(
          materialsByCourse: {'c1': List.of(materials)},
          uploadMaterialResult: StudyMaterial(
            materialId: 'new-material',
            title: 'Lecture 2',
            type: 'pptx',
            document: 'd-new',
            courseId: 'c1',
            extractedText: '[Slide 1]\nText.',
            createdAt: DateTime.now(),
          ),
        );
        await pump(
          tester,
          service,
          pickFile: () async => (
            name: 'Lecture 2.pptx',
            bytes: Uint8List.fromList(utf8.encode('hi')),
          ),
        );

        await tester.enterText(find.byType(TextField), 'lecture');
        await tester.pumpAndSettle();
        expect(find.text('Lecture 1'), findsOneWidget);

        await tester.tap(find.text('+ Upload'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose a file'));
        await tester.pump();
        await tester.tap(find.text('Upload'));
        await tester.pump();
        await tester.pump();
        // Auto-dismiss, same timing as upload_material_sheet_test.dart's
        // own "success" case.
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(service.uploadMaterialCalls, 1);
        // The search survived the reload, and the newly-added material —
        // which matches "lecture" — shows up without the search needing
        // to be re-entered.
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'lecture',
        );
        expect(find.text('Lecture 1'), findsOneWidget);
        expect(find.text('Lecture 2'), findsOneWidget);
      },
    );

    testWidgets(
      'search text and sort choice reset after actually leaving and '
      're-entering the screen (a real pop + a fresh push) — they are '
      'never persisted anywhere outside this State',
      (tester) async {
        final service = FakeCoursesService(
          materialsByCourse: {'c1': materials},
        );

        Widget buildCourseDetail() => CourseDetailScreen(
          uid: 'uid-1',
          course: course,
          coursesService: service,
        );

        // A tiny harness: a Home-like page with a button that pushes a
        // *fresh* CourseDetailScreen — real navigation, not just a second
        // pumpWidget of the same widget (which Flutter would treat as an
        // update to the *same* Element/State, not a new instance, since
        // nothing about its type/key/position would differ).
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => buildCourseDetail()),
                    ),
                    child: const Text('Open course'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open course'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'lecture');
        await tester.tap(find.byIcon(Icons.sort));
        await tester.pumpAndSettle();
        await tester.tap(find.text('A to Z'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'lecture',
        );

        // Leave (pop) ...
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.text('Open course'), findsOneWidget);

        // ... and re-enter: a brand-new CourseDetailScreen instance.
        await tester.tap(find.text('Open course'));
        await tester.pumpAndSettle();

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
        final sortButtonContainer = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(PopupMenuButton<MaterialSortOrder>),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (sortButtonContainer.decoration as BoxDecoration).color,
          isNot(AppColors.navy),
        );
      },
    );

    testWidgets(
      'a large system text scale does not overflow the pinned search + '
      'sort row',
      (tester) async {
        // 1.3x — a common real "Large text" accessibility setting.
        // (2.0x, the platform maximum, overflows elsewhere on this screen
        // today — _MaterialsSectionHeader's "Course materials" + "+
        // Upload" row, pre-existing and unrelated to this feature; see the
        // report for this change.)
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.3),
            ),
            child: MaterialApp(
              home: CourseDetailScreen(
                uid: 'uid-1',
                course: course,
                coursesService: FakeCoursesService(
                  materialsByCourse: {'c1': materials},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.sort), findsOneWidget);
      },
    );
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
          'quizzes, flashcard sessions, and calendar events with their '
          "reminders. This can't be undone.",
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

  group('status bar / safe area', () {
    testWidgets(
      'the header background (course colour) reaches the top of the '
      'screen under a real top inset (no white strip above it), and the '
      'title sits below the status-bar inset',
      (tester) async {
        const insets = EdgeInsets.only(top: 48);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                padding: insets,
                viewPadding: insets,
              ),
              child: CourseDetailScreen(
                uid: 'uid-1',
                course: course,
                coursesService: FakeCoursesService(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final courseColor = parseHexColor(course.color);
        final headerFinder = find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final decoration = w.decoration;
          return decoration is BoxDecoration && decoration.color == courseColor;
        });
        expect(tester.getRect(headerFinder.first).top, 0);

        final titleRect = tester.getRect(find.text('IS230'));
        expect(titleRect.top, greaterThan(48));
      },
    );
  });
}
