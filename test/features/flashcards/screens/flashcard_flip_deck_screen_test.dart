import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_flip_deck_screen.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_performance_summary_screen.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';

import '../../../helpers/fake_flashcard_service.dart';

Flashcard _card(String id, int index) => Flashcard(
  flashcardId: id,
  frontText: 'front-$id',
  backText: 'back-$id',
  reviewStatus: null,
  sourceLocation: 'Slide $index',
  sessionId: 'session-1',
  cardIndex: index,
);

Widget _wrap(FakeFlashcardService service, List<Flashcard> cards) {
  return MaterialApp(
    home: FlashcardFlipDeckScreen(
      uid: 'uid-1',
      courseId: 'course-1',
      sessionId: 'session-1',
      initialFlashcards: cards,
      initialIndex: 0,
      initialKnownCount: 0,
      initialNeedsReviewCount: 0,
      service: service,
    ),
  );
}

void main() {
  testWidgets('rating buttons only appear after flipping the card', (
    tester,
  ) async {
    final service = FakeFlashcardService();
    await tester.pumpWidget(_wrap(service, [_card('a', 0), _card('b', 1)]));
    await tester.pumpAndSettle();

    expect(find.text('Need review'), findsNothing);
    expect(find.text('I know it'), findsNothing);

    await tester.tap(find.text('front-a'));
    await tester.pumpAndSettle();

    expect(find.text('Need review'), findsOneWidget);
    expect(find.text('I know it'), findsOneWidget);
  });

  testWidgets('rating a non-final card persists via markFlashcard and moves '
      'to the next card instantly, unflipped', (tester) async {
    final service = FakeFlashcardService();
    await tester.pumpWidget(_wrap(service, [_card('a', 0), _card('b', 1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('front-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I know it'));
    await tester.pump();

    expect(find.text('Card 2 of 2'), findsOneWidget);
    expect(find.text('front-b'), findsOneWidget);
    expect(find.text('Need review'), findsNothing);
    expect(service.markFlashcardCalls, 1);
    expect(service.completeSessionCalls, 0);
    expect(service.lastMarkedStatus, ReviewStatus.knowIt);
  });

  testWidgets('rating the final card completes the session and navigates '
      'to the Performance Summary', (tester) async {
    final service = FakeFlashcardService();
    await tester.pumpWidget(_wrap(service, [_card('a', 0)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('front-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I know it'));
    await tester.pumpAndSettle();

    expect(service.completeSessionCalls, 1);
    expect(service.markFlashcardCalls, 0);
    expect(find.byType(FlashcardPerformanceSummaryScreen), findsOneWidget);
    expect(find.text('+2'), findsOneWidget); // 1 known card * 2 points
  });

  testWidgets('tapping X opens the Save-and-leave sheet with the current '
      'progress', (tester) async {
    final service = FakeFlashcardService();
    await tester.pumpWidget(_wrap(service, [_card('a', 0), _card('b', 1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Leave this deck?'), findsOneWidget);
    expect(
      find.text(
        'You have marked 0 of 2 cards. We will keep this session so you '
        'can pick it up at card 1.',
      ),
      findsOneWidget,
    );
  });
}
