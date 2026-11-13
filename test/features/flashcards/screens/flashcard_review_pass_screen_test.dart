import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/screens/flashcard_review_pass_screen.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';
import 'package:tadarab_app/theme/app_theme.dart';
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

Color _borderColorOf(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.widgetWithText(AppButton, label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration as BoxDecoration).border!.top.color;
}

Color _textColorOf(WidgetTester tester, String label) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.widgetWithText(AppButton, label),
      matching: find.byType(Text),
    ),
  );
  return text.style!.color!;
}

List<BoxShadow>? _shadowOf(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.widgetWithText(AppButton, label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration as BoxDecoration).boxShadow;
}

void main() {
  testWidgets('a single-card set shows "Done reviewing" immediately with '
      'no Previous button at all', (tester) async {
    await tester.pumpWidget(_wrap([_card('a', 0)]));
    await tester.pumpAndSettle();

    expect(find.text('Card 1 of 1'), findsOneWidget);
    expect(find.text('Done reviewing'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Previous'), findsNothing);
  });

  testWidgets('a multi-card set shows "Next" until the last card, then '
      '"Done reviewing"', (tester) async {
    await tester.pumpWidget(_wrap([_card('a', 0), _card('b', 1), _card('c', 2)]));
    await tester.pumpAndSettle();

    expect(find.text('Card 1 of 3'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Done reviewing'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Card 2 of 3'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Card 3 of 3'), findsOneWidget);
    expect(find.text('Done reviewing'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('Previous is enabled after moving off the first card', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap([_card('a', 0), _card('b', 1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
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

    await tester.tap(find.text('Done reviewing'));
    await tester.pumpAndSettle();

    expect(find.byType(FlashcardReviewPassScreen), findsNothing);
    expect(find.text('Performance Summary'), findsOneWidget);
  });

  testWidgets('Previous is disabled and dimmed on the first card, and '
      'tapping it does nothing', (tester) async {
    await tester.pumpWidget(
      _wrap([_card('a', 0), _card('b', 1), _card('c', 2)]),
    );
    await tester.pumpAndSettle();

    expect(_button(tester, 'Previous').onPressed, isNull);
    expect(_borderColorOf(tester, 'Previous'), AppColors.borderDefault);
    expect(_textColorOf(tester, 'Previous'), AppColors.textSecondary);
    expect(_shadowOf(tester, 'Previous'), isNull);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('Card 1 of 3'), findsOneWidget);
  });

  testWidgets('Previous looks active once enabled, and dims again back on '
      'the first card', (tester) async {
    await tester.pumpWidget(_wrap([_card('a', 0), _card('b', 1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(_button(tester, 'Previous').onPressed, isNotNull);
    expect(_borderColorOf(tester, 'Previous'), AppColors.navy.withValues(alpha: 0.32));
    expect(_textColorOf(tester, 'Previous'), AppColors.navy);
    final shadow = _shadowOf(tester, 'Previous');
    expect(shadow, isNotNull);
    expect(shadow!.single.color, AppColors.navy.withValues(alpha: 0.10));
    expect(shadow.single.offset, const Offset(0, 3));
    expect(shadow.single.blurRadius, 0);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();

    expect(find.text('Card 1 of 2'), findsOneWidget);
    expect(_button(tester, 'Previous').onPressed, isNull);
    expect(_borderColorOf(tester, 'Previous'), AppColors.borderDefault);
    expect(_textColorOf(tester, 'Previous'), AppColors.textSecondary);
    expect(_shadowOf(tester, 'Previous'), isNull);
  });

  group('overflow safety at a narrow screen and larger text scale', () {
    testWidgets('renders with no overflow at 320x568 and 1.3x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _wrap([_card('a', 0), _card('b', 1)]),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a single-card set renders with no overflow at 320x568 and '
        '1.3x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _wrap([_card('a', 0)]),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
