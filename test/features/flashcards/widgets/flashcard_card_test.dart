import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/features/flashcards/widgets/flashcard_card.dart';
import 'package:tadarab_app/theme/app_theme.dart';
import 'package:tadarab_app/widgets/draggable_overflow_text.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('unflipped: shows the question, QUESTION tag and the flip hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FlashcardCard(
          frontText: 'What is a database?',
          backText: 'A collection of related data.',
          sourceLocation: 'Lecture 1 - Slide 8',
          flipped: false,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('What is a database?'), findsOneWidget);
    expect(find.text('QUESTION'), findsOneWidget);
    expect(find.textContaining('Tap to flip'), findsOneWidget);
    expect(find.text('A collection of related data.'), findsNothing);
  });

  testWidgets('flipped: shows the answer, ANSWER tag and the source badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FlashcardCard(
          frontText: 'What is a database?',
          backText: 'A collection of related data.',
          sourceLocation: 'Lecture 1 - Slide 8',
          flipped: true,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A collection of related data.'), findsOneWidget);
    expect(find.text('ANSWER'), findsOneWidget);
    // Deliberate departure from the design handoff (which has no such
    // heading) — an explicit request: navy strip, white icon, a dim
    // "FIND IT IN YOUR MATERIAL" label above the bold location line.
    expect(find.text('FIND IT IN YOUR MATERIAL'), findsOneWidget);
    expect(find.text('Lecture 1 - Slide 8'), findsOneWidget);
    expect(find.text('What is a database?'), findsNothing);
  });

  testWidgets(
    'the answer text matches the question text\'s size and weight, not '
    'the smaller subtitle style it used before',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlashcardCard(
            frontText: 'What is a database?',
            backText: 'A collection of related data.',
            sourceLocation: 'Lecture 1 - Slide 8',
            flipped: false,
            onTap: () {},
          ),
        ),
      );
      final questionStyle = tester
          .widget<Text>(find.text('What is a database?'))
          .style!;

      await tester.pumpWidget(
        _wrap(
          FlashcardCard(
            frontText: 'What is a database?',
            backText: 'A collection of related data.',
            sourceLocation: 'Lecture 1 - Slide 8',
            flipped: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final answerStyle = tester
          .widget<Text>(find.text('A collection of related data.'))
          .style!;

      // NOTE 10: fontSize 20 / w800 (was 22 / w900).
      expect(answerStyle.fontSize, 20);
      expect(answerStyle.fontWeight, FontWeight.w800);
      expect(answerStyle.color, AppColors.navy);
      expect(answerStyle.fontSize, questionStyle.fontSize);
      expect(answerStyle.fontWeight, questionStyle.fontWeight);
    },
  );

  testWidgets('tapping the card invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        FlashcardCard(
          frontText: 'Q',
          backText: 'A',
          sourceLocation: 'Slide 1',
          flipped: false,
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Q'));
    expect(tapped, isTrue);
  });

  group('fixed card size', () {
    const shortLong = 'What is a database?';
    const veryLong =
        'A relational database management system, or RDBMS, is a piece of '
        'software that lets applications and users create, read, update '
        'and delete structured data organized into tables of rows and '
        'columns, while enforcing constraints, relationships between '
        'tables, and transactional guarantees across many concurrent '
        'users at once.';

    Size cardSize(WidgetTester tester) =>
        tester.getSize(find.byType(FlashcardCard));

    testWidgets(
      'front and back render at the exact same size, regardless of text',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            FlashcardCard(
              frontText: shortLong,
              backText: veryLong,
              sourceLocation: 'Slide 1',
              flipped: false,
              onTap: () {},
            ),
          ),
        );
        final frontSize = cardSize(tester);

        await tester.pumpWidget(
          _wrap(
            FlashcardCard(
              frontText: shortLong,
              backText: veryLong,
              sourceLocation: 'Slide 1',
              flipped: true,
              onTap: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 260));
        final backSize = cardSize(tester);

        expect(frontSize, const Size(352, 352));
        expect(backSize, const Size(352, 352));
      },
    );

    testWidgets(
      'text long enough to overflow the fixed size does not grow the '
      'card and does not throw a render-overflow error — it scrolls '
      'inside instead',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            FlashcardCard(
              frontText: veryLong,
              backText: veryLong,
              sourceLocation: 'Slide 1',
              flipped: false,
              onTap: () {},
            ),
          ),
        );

        // A RenderFlex/overflow error would surface as a FlutterError caught
        // by the test framework; getting this far without one is itself
        // part of the proof. The card must still be exactly the fixed size.
        expect(tester.takeException(), isNull);
        expect(cardSize(tester), const Size(352, 352));

        // And the overflow is actually handled by scrolling, not clipping
        // silently: the scroll view's position can move.
        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(FlashcardCard),
            matching: find.byType(Scrollable),
          ),
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
      },
    );

    testWidgets('short text stays visually centered within the fixed card '
        '(no dead space forcing it to the top)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlashcardCard(
            frontText: 'Q',
            backText: 'A',
            sourceLocation: 'Slide 1',
            flipped: false,
            onTap: () {},
          ),
        ),
      );

      final cardCenter = tester.getCenter(find.byType(FlashcardCard));
      final textCenter = tester.getCenter(find.text('Q'));

      // The question text should sit at roughly the vertical center of the
      // card, not pinned to the top — "roughly" because the QUESTION tag
      // and the flip hint above/below it shift it slightly.
      expect(
        (textCenter.dy - cardCenter.dy).abs(),
        lessThan(40),
        reason: 'Short content should be centered in the fixed card, not '
            'stuck at the top.',
      );
    });
  });

  group('source-location strip fixed size', () {
    Widget flipped(String sourceLocation) => _wrap(
      FlashcardCard(
        frontText: 'Q',
        backText: 'A',
        sourceLocation: sourceLocation,
        flipped: true,
        onTap: () {},
      ),
    );

    testWidgets(
      'the strip is the same size for a short and a very long location — '
      'it does not grow with the text',
      (tester) async {
        await tester.pumpWidget(flipped('Slide 1'));
        await tester.pumpAndSettle();
        final shortSize = tester.getSize(
          find.byKey(const ValueKey('source-strip')),
        );

        await tester.pumpWidget(
          flipped(
            'Lecture 12 - Introduction to Advanced Relational Database '
            'Design Concepts and Normalization Theory - Slide 47',
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final longSize = tester.getSize(
          find.byKey(const ValueKey('source-strip')),
        );

        expect(longSize, shortSize);
      },
    );

    testWidgets(
      'NOTE 9: a location too long to fit is manually drag-scrollable '
      '(via DraggableOverflowText) instead of being truncated with an '
      'ellipsis, and does not move by itself',
      (tester) async {
        const longLocation =
            'Lecture 12 - Introduction to Advanced Relational Database '
            'Design Concepts and Normalization Theory - Slide 47';
        await tester.pumpWidget(flipped(longLocation));
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        // The full text is present (not truncated) — DraggableOverflowText
        // renders it at its real, untruncated width, scrollable by drag.
        expect(find.text(longLocation), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('source-strip')),
            matching: find.byType(DraggableOverflowText),
          ),
          findsOneWidget,
        );
        // Genuinely in scroll mode, not silently falling back to static —
        // the inner scroll view only exists once real overflow is
        // measured.
        final scrollFinder = find.descendant(
          of: find.byKey(const ValueKey('source-strip')),
          matching: find.byKey(const ValueKey('draggable-overflow-scroll')),
        );
        expect(scrollFinder, findsOneWidget);

        // No automatic movement: holding still (no drag) for a while
        // leaves the scroll position at 0.
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: scrollFinder, matching: find.byType(Scrollable)),
        );
        expect(scrollable.position.pixels, 0);
        await tester.pump(const Duration(seconds: 3));
        expect(scrollable.position.pixels, 0);
      },
    );

    testWidgets(
      'gesture priority: a horizontal drag starting on the chip scrolls '
      'it and does NOT flip the card — the card\'s own onTap is never '
      'invoked',
      (tester) async {
        const longLocation =
            'Lecture 12 - Introduction to Advanced Relational Database '
            'Design Concepts and Normalization Theory - Slide 47';
        var tapCount = 0;
        await tester.pumpWidget(
          _wrap(
            FlashcardCard(
              frontText: 'Q',
              backText: 'A',
              sourceLocation: longLocation,
              flipped: true,
              onTap: () => tapCount++,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final scrollFinder = find.byKey(
          const ValueKey('draggable-overflow-scroll'),
        );
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: scrollFinder, matching: find.byType(Scrollable)),
        );
        expect(scrollable.position.pixels, 0);

        await tester.drag(scrollFinder, const Offset(-80, 0));
        await tester.pump();

        expect(
          scrollable.position.pixels,
          greaterThan(0),
          reason: 'the chip itself must have actually scrolled',
        );
        expect(
          tapCount,
          0,
          reason: "the card's onTap (flip) must not fire from a drag that "
              'started on the chip',
        );
      },
    );

    testWidgets(
      'the strip is noticeably narrower than the card (not edge-to-edge) '
      'and horizontally centered within it',
      (tester) async {
        await tester.pumpWidget(flipped('Lecture 1 - Slide 15'));
        await tester.pumpAndSettle();

        final cardRect = tester.getRect(find.byType(FlashcardCard));
        final stripRect = tester.getRect(
          find.byKey(const ValueKey('source-strip')),
        );

        // Roughly 70-75% of the card's inner (padding-excluded) width —
        // asserting a wide "clearly narrower, not full width" band rather
        // than the exact private constant, so this doesn't pin an
        // implementation detail.
        final ratio = stripRect.width / cardRect.width;
        expect(
          ratio,
          inInclusiveRange(0.55, 0.85),
          reason: 'Strip width should be a clear fraction of the card '
              'width, not stretch edge-to-edge.',
        );

        expect(
          stripRect.center.dx,
          closeTo(cardRect.center.dx, 1),
          reason: 'Strip should be horizontally centered in the card.',
        );
      },
    );
  });
}
