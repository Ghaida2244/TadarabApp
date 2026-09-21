import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_review_pass_screen.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';
import 'package:tadarab_app/widgets/app_button.dart';

Flashcard _card(String id, int index) => Flashcard(
  flashcardId: id,
  frontText: 'front-$id',
  backText: 'back-$id',
  reviewStatus: ReviewStatus.needsReview,
  sourceLocation: 'Slide $index',
  sessionId: 'session-1',
  cardIndex: index,
);

Widget _wrap(List<Flashcard> cards) =>
    MaterialApp(home: FlashcardReviewPassScreen(flashcards: cards));

AppButton _button(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label));

void main() {
  testWidgets('a single-card set shows "Done reviewing" immediately with '
      'Previous disabled', (tester) async {
    await tester.pumpWidget(_wrap([_card('a', 0)]));
    await tester.pumpAndSettle();

    expect(find.text('Card 1 of 1'), findsOneWidget);
    expect(find.text('Done reviewing →'), findsOneWidget);
    expect(find.text('Next →'), findsNothing);
    expect(_button(tester, 'Previous').onPressed, isNull);
  });

  testWidgets('a multi-card set shows "Next" until the last card, then '
      '"Done reviewing"', (tester) async {
    await tester.pumpWidget(_wrap([_card('a', 0), _card('b', 1), _card('c', 2)]));
    await tester.pumpAndSettle();

    expect(find.text('Card 1 of 3'), findsOneWidget);
    expect(find.text('Next →'), findsOneWidget);
    expect(find.text('Done reviewing →'), findsNothing);

    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();
    expect(find.text('Card 2 of 3'), findsOneWidget);
    expect(find.text('Next →'), findsOneWidget);

    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();
    expect(find.text('Card 3 of 3'), findsOneWidget);
    expect(find.text('Done reviewing →'), findsOneWidget);
    expect(find.text('Next →'), findsNothing);
  });

  testWidgets('Previous is enabled after moving off the first card', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap([_card('a', 0), _card('b', 1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();

    expect(_button(tester, 'Previous').onPressed, isNotNull);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('Card 1 of 2'), findsOneWidget);
  });

  testWidgets('tapping Done reviewing on the last card pops back to the '
      'previous screen with zero writes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      FlashcardReviewPassScreen(flashcards: [_card('a', 0)]),
                ),
              ),
              child: const Text('Performance Summary'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Performance Summary'));
    await tester.pumpAndSettle();
    expect(find.byType(FlashcardReviewPassScreen), findsOneWidget);

    await tester.tap(find.text('Done reviewing →'));
    await tester.pumpAndSettle();

    expect(find.byType(FlashcardReviewPassScreen), findsNothing);
    expect(find.text('Performance Summary'), findsOneWidget);
  });
}
