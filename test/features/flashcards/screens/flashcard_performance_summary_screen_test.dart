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
  testWidgets('mastery tier (>= 80%) shows the trophy message and no '
      'Review now button', (tester) async {
    await tester.pumpWidget(_wrap(knownCount: 8, needsReviewCount: 0));
    await tester.pumpAndSettle();

    expect(find.text("You've mastered this."), findsOneWidget);
    expect(find.text('Review now'), findsNothing);
    expect(find.text('8 CARDS REVIEWED'), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);
  });

  testWidgets('developing tier (50-80%) shows the building-understanding '
      'message and the Review now button', (tester) async {
    await tester.pumpWidget(_wrap(knownCount: 6, needsReviewCount: 4));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "You're building real understanding; a bit more practice on the "
        "tricky parts will get you there.",
      ),
      findsOneWidget,
    );
    expect(find.text('Review now'), findsOneWidget);
  });

  testWidgets('needsReview tier (< 50%, including exactly 0%) shows the '
      'needs-more-work message and the Review now button', (tester) async {
    await tester.pumpWidget(_wrap(knownCount: 0, needsReviewCount: 10));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "This one needs more work before it clicks — let's go through it "
        "again together.",
      ),
      findsOneWidget,
    );
    expect(find.text('Review now'), findsOneWidget);
  });

  testWidgets('Review now is hidden entirely when needsReviewCount is zero, '
      'even outside the mastery tier boundary', (tester) async {
    await tester.pumpWidget(_wrap(knownCount: 0, needsReviewCount: 0));
    await tester.pumpAndSettle();

    expect(find.text('Review now'), findsNothing);
    expect(find.text('Back to course'), findsOneWidget);
  });
}
