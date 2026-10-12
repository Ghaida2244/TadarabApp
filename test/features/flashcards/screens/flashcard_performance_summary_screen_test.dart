import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_performance_summary_screen.dart';

Widget _wrap({
  required int knownCount,
  required int needsReviewCount,
  int earnedPoints = 20,
}) {
  return MaterialApp(
    home: FlashcardPerformanceSummaryScreen(
      uid: 'uid-1',
      courseId: 'course-1',
      sessionId: 'session-1',
      knownCount: knownCount,
      needsReviewCount: needsReviewCount,
      earnedPoints: earnedPoints,
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
}
