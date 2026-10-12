import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_performance_summary_screen.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_review_pass_screen.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';
import 'package:tadarab_app/services/flashcard_service.dart';

import '../../../helpers/fake_flashcard_service.dart';

Widget _wrap({
  required int knownCount,
  required int needsReviewCount,
  int earnedPoints = 20,
  FlashcardService? service,
}) {
  return MaterialApp(
    home: FlashcardPerformanceSummaryScreen(
      uid: 'uid-1',
      courseId: 'course-1',
      sessionId: 'session-1',
      knownCount: knownCount,
      needsReviewCount: needsReviewCount,
      earnedPoints: earnedPoints,
      service: service,
    ),
  );
}

void main() {
  testWidgets('excellent tier (>= 80%) shows the NOTE 6 excellent message '
      'and no Review now button', (tester) async {
    await tester.pumpWidget(_wrap(knownCount: 8, needsReviewCount: 0));
    await tester.pumpAndSettle();

    expect(
      find.text('Excellent work! You nailed it. You should be proud of this one.'),
      findsOneWidget,
    );
    expect(find.text('Review now'), findsNothing);
    expect(find.text('8 CARDS REVIEWED'), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);
  });

  testWidgets('nice tier (50-80%) shows the NOTE 6 nice message and the '
      'Review now button', (tester) async {
    await tester.pumpWidget(_wrap(knownCount: 6, needsReviewCount: 4));
    await tester.pumpAndSettle();

    expect(
      find.text("Nice progress! You're close, keep it up."),
      findsOneWidget,
    );
    expect(find.text('Review now'), findsOneWidget);
  });

  testWidgets('needsWork tier (< 50%, including exactly 0%) shows the '
      'NOTE 6 needs-work message and the Review now button', (tester) async {
    await tester.pumpWidget(_wrap(knownCount: 0, needsReviewCount: 10));
    await tester.pumpAndSettle();

    expect(
      find.text("This one needs more work before it clicks. You'll get there."),
      findsOneWidget,
    );
    expect(find.text('Review now'), findsOneWidget);
  });

  testWidgets(
    'a zero-card session (zero reviewed) falls back to the needsWork '
    'tier message rather than dividing by zero',
    (tester) async {
      await tester.pumpWidget(_wrap(knownCount: 0, needsReviewCount: 0));
      await tester.pumpAndSettle();

      expect(
        find.text("This one needs more work before it clicks. You'll get there."),
        findsOneWidget,
      );
    },
  );

  testWidgets('Review now is hidden entirely when needsReviewCount is zero, '
      'even outside the excellent tier boundary', (tester) async {
    await tester.pumpWidget(_wrap(knownCount: 0, needsReviewCount: 0));
    await tester.pumpAndSettle();

    expect(find.text('Review now'), findsNothing);
    // NOTE 11: renamed from "Back to course".
    expect(find.text('Back to sessions'), findsOneWidget);
    expect(find.text('Back to course'), findsNothing);
  });

  testWidgets(
    'NOTE 11: the action buttons are pinned below the scrollable content, '
    'inside a SafeArea',
    (tester) async {
      await tester.pumpWidget(_wrap(knownCount: 8, needsReviewCount: 2));
      await tester.pumpAndSettle();

      final scrollView = find.byType(SingleChildScrollView);
      final safeAreaWithButtons = find.ancestor(
        of: find.text('Back to sessions'),
        matching: find.byType(SafeArea),
      );

      expect(scrollView, findsOneWidget);
      expect(safeAreaWithButtons, findsWidgets);
      // The buttons' SafeArea is a sibling after the scrollable area, not
      // inside it.
      expect(
        find.descendant(of: scrollView, matching: find.text('Back to sessions')),
        findsNothing,
      );
    },
  );

  group('Review now', () {
    Flashcard card(String id, ReviewStatus? status) => Flashcard(
      flashcardId: id,
      frontText: 'front-$id',
      backText: 'back-$id',
      reviewStatus: status,
      sourceLocation: 'Slide 1',
      sessionId: 'session-1',
      cardIndex: 0,
    );

    testWidgets(
      'opens a review pass with only the needs-review cards, none of the '
      'known ones',
      (tester) async {
        final service = FakeFlashcardService(
          flashcardsBySessionId: {
            'session-1': [
              card('a', ReviewStatus.needsReview),
              card('b', ReviewStatus.knowIt),
              card('c', ReviewStatus.needsReview),
              card('d', null),
            ],
          },
        );
        await tester.pumpWidget(
          _wrap(knownCount: 1, needsReviewCount: 2, service: service),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Review now'));
        await tester.pumpAndSettle();

        final reviewScreen = tester.widget<FlashcardReviewPassScreen>(
          find.byType(FlashcardReviewPassScreen),
        );
        expect(
          reviewScreen.flashcards.map((f) => f.flashcardId).toSet(),
          {'a', 'c'},
        );
      },
    );

    testWidgets(
      'leaving the review pass returns to this summary with its stored '
      'counts and points unchanged',
      (tester) async {
        final service = FakeFlashcardService(
          flashcardsBySessionId: {
            'session-1': [
              card('a', ReviewStatus.needsReview),
              card('b', ReviewStatus.needsReview),
            ],
          },
        );
        await tester.pumpWidget(
          _wrap(
            knownCount: 6,
            needsReviewCount: 2,
            earnedPoints: 12,
            service: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Review now'));
        await tester.pumpAndSettle();
        expect(find.byType(FlashcardReviewPassScreen), findsOneWidget);

        // Walk through both cards to the end (Done reviewing pops).
        await tester.tap(find.text('Next →'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done reviewing →'));
        await tester.pumpAndSettle();

        expect(find.byType(FlashcardReviewPassScreen), findsNothing);
        expect(find.text('6'), findsOneWidget); // knownCount, unchanged
        expect(find.text('2'), findsOneWidget); // needsReviewCount, unchanged
        expect(find.text('+12'), findsOneWidget); // earnedPoints, unchanged
      },
    );
  });
}
