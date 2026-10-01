import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_sessions_screen.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard_session.dart';

import '../../../helpers/fake_flashcard_service.dart';

FlashcardSession _session({
  required String id,
  required bool completed,
  int numberOfFlashcards = 10,
  int knownCount = 0,
  int needsReviewCount = 0,
  int currentFlashcardIndex = 0,
  List<String> materialTitles = const ['Lecture 1 - Introduction'],
}) {
  return FlashcardSession(
    sessionId: id,
    createdAt: DateTime(2026, 1, 1),
    difficultyLevels: const [DifficultyLevel.easy],
    email: 'student@example.com',
    courseId: 'course-1',
    materialIds: const ['m1'],
    materialTitles: materialTitles,
    numberOfFlashcards: numberOfFlashcards,
    isSessionCompleted: completed,
    knownCount: knownCount,
    needsReviewCount: needsReviewCount,
    currentFlashcardIndex: currentFlashcardIndex,
  );
}

Widget _wrap(FakeFlashcardService service) {
  return MaterialApp(
    home: FlashcardSessionsScreen(
      uid: 'uid-1',
      courseId: 'course-1',
      email: 'student@example.com',
      service: service,
    ),
  );
}

void main() {
  testWidgets('empty state shows the no-sessions copy and hides the '
      'in-progress/completed sections', (tester) async {
    await tester.pumpWidget(_wrap(FakeFlashcardService(sessions: const [])));
    await tester.pumpAndSettle();

    expect(find.text('No sessions yet'), findsOneWidget);
    expect(
      find.textContaining('Turn a lecture into a deck'),
      findsOneWidget,
    );
    expect(find.text('IN PROGRESS'), findsNothing);
    expect(find.text('COMPLETED'), findsNothing);
    expect(find.text('0 sessions'), findsOneWidget);
    expect(find.text('Start new flashcards'), findsOneWidget);
  });

  testWidgets('shows a singular session count for exactly one session', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FakeFlashcardService(
          sessions: [_session(id: 's1', completed: false)],
        ),
      ),
    );
    // Not pumpAndSettle(): the row's default sample material title can be
    // wide enough to trigger the marquee's continuous (never-settling)
    // scroll — see the "material-title pill marquee" group below. This
    // test doesn't care about that; one frame is enough to see the text.
    await tester.pump();

    expect(find.text('1 session'), findsOneWidget);
  });

  testWidgets('an in-progress session shows the reviewed count and resume '
      'label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FakeFlashcardService(
          sessions: [
            _session(
              id: 's1',
              completed: false,
              numberOfFlashcards: 10,
              knownCount: 2,
              needsReviewCount: 1,
              currentFlashcardIndex: 3,
            ),
          ],
        ),
      ),
    );
    // Not pumpAndSettle() — see the note in the previous test.
    await tester.pump();

    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('3 of 10 reviewed'), findsOneWidget);
    expect(find.text('Resume at card 4'), findsOneWidget);
  });

  testWidgets('a completed session shows its known count and both action '
      'buttons', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FakeFlashcardService(
          sessions: [
            _session(
              id: 's1',
              completed: true,
              numberOfFlashcards: 10,
              knownCount: 8,
            ),
          ],
        ),
      ),
    );
    // Not pumpAndSettle() — see the note above the singular-count test.
    await tester.pump();

    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('10 cards · 8 known'), findsOneWidget);
    expect(find.text('View performance summary'), findsOneWidget);
    expect(find.text('Retake flashcards'), findsOneWidget);
  });

  group('material-title pill sizing', () {
    // The hug-vs-scroll decision needs one extra pump after the first: the
    // available width is read from a RenderBox in a post-frame callback,
    // then a setState schedules the frame that may switch into scroll mode.

    testWidgets('a single short title hugs its content — no scroll view '
        'is introduced', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FakeFlashcardService(
            sessions: [
              _session(
                id: 's1',
                completed: false,
                materialTitles: const ['Lecture 1'],
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Lecture 1'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('a long joined material-title list becomes exactly the '
        'available width and is genuinely drag-scrollable — not wrapped, '
        'not truncated, and not silently left hugging a wider box', (
      tester,
    ) async {
      const titles = [
        'Lecture 1 - Introduction to Databases',
        'Lecture 2 - Requirements Engineering',
        'Lecture 3 - Entity Relationship Diagrams',
      ];
      await tester.pumpWidget(
        _wrap(
          FakeFlashcardService(
            sessions: [
              _session(id: 's1', completed: false, materialTitles: titles),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final joined = titles.join(', ');
      // Single line, not wrapped, not ellipsized.
      expect(find.text(joined), findsOneWidget);

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(scrollFinder).scrollDirection,
        Axis.horizontal,
      );

      // Genuinely draggable, not just present: a drag actually moves the
      // scroll position away from zero.
      final scrollableState = tester.state<ScrollableState>(
        find.descendant(
          of: scrollFinder,
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollableState.position.pixels, 0.0);

      await tester.drag(scrollFinder, const Offset(-80, 0));
      await tester.pump();

      expect(
        scrollableState.position.pixels,
        greaterThan(0.0),
        reason: 'Dragging the pill did not move its scroll position — it '
            "isn't actually scrollable.",
      );
    });
  });
}
