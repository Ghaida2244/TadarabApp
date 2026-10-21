import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/widgets/draggable_overflow_text.dart';

const _style = TextStyle(fontFamily: 'Nunito', fontSize: 14, color: Colors.white);
const _fadeColor = Colors.black;

Finder get _scrollFinder =>
    find.byKey(const ValueKey('draggable-overflow-scroll'));
Finder get _fadeFinder => find.byKey(const ValueKey('draggable-overflow-fade'));

Future<void> _pump(
  WidgetTester tester,
  String text, {
  double width = 150,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: DraggableOverflowText(
            text: text,
            style: _style,
            fadeColor: _fadeColor,
          ),
        ),
      ),
    ),
  );
  // The hug-vs-scroll decision needs an extra pump after the first: the
  // available width is read from a RenderBox in a post-frame callback,
  // then a setState schedules the frame that may switch into scroll mode.
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('short text that fits renders statically — no scroll view, '
      'no fade hint', (tester) async {
    await _pump(tester, 'Slide 2');

    expect(find.text('Slide 2'), findsOneWidget);
    expect(_scrollFinder, findsNothing);
    expect(_fadeFinder, findsNothing);
  });

  testWidgets(
    'long text that overflows becomes drag-scrollable, and the scroll '
    'offset genuinely changes after a drag',
    (tester) async {
      const text =
          'Lecture_1 | Slide 9: What is BPM? A very long source location '
          'string that definitely overflows a 150px-wide chip';
      await _pump(tester, text);

      expect(find.text(text), findsOneWidget);
      expect(_scrollFinder, findsOneWidget);

      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: _scrollFinder, matching: find.byType(Scrollable)),
      );
      expect(scrollable.position.pixels, 0);

      await tester.drag(_scrollFinder, const Offset(-80, 0));
      await tester.pump();

      expect(scrollable.position.pixels, greaterThan(0));
    },
  );

  testWidgets(
    'no automatic movement: with no drag, the scroll position stays at '
    '0 no matter how long real time passes, and pumpAndSettle completes '
    'immediately (no pending timers or tickers)',
    (tester) async {
      const text =
          'Lecture_1 | Slide 9: What is BPM? A very long source location '
          'string that definitely overflows a 150px-wide chip';
      await _pump(tester, text);

      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: _scrollFinder, matching: find.byType(Scrollable)),
      );
      expect(scrollable.position.pixels, 0);

      // pumpAndSettle would hang forever if anything (a Timer, a ticking
      // AnimationController) kept scheduling frames on its own.
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, 0);

      await tester.pump(const Duration(seconds: 5));
      expect(scrollable.position.pixels, 0);
    },
  );

  testWidgets(
    'the fade hint is shown while there is more to scroll, and '
    'disappears once dragged all the way to the end',
    (tester) async {
      const text =
          'Lecture_1 | Slide 9: What is BPM? A very long source location '
          'string that definitely overflows a 150px-wide chip';
      await _pump(tester, text);

      // Visible from the start — there's overflow and position is 0.
      expect(_fadeFinder, findsOneWidget);

      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: _scrollFinder, matching: find.byType(Scrollable)),
      );

      // Drag all the way to the end.
      await tester.drag(_scrollFinder, const Offset(-4000, 0));
      await tester.pump();

      expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
      expect(_fadeFinder, findsNothing);

      // Drag back away from the end — the hint returns.
      await tester.drag(_scrollFinder, const Offset(40, 0));
      await tester.pump();

      expect(_fadeFinder, findsOneWidget);
    },
  );

  testWidgets(
    'regression: when the text changes after the first build, the '
    'overflow decision reflects the NEW text, not a stale measurement '
    'of the old one',
    (tester) async {
      await _pump(tester, 'short', width: 300);
      expect(_scrollFinder, findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: DraggableOverflowText(
                text:
                    'A much, much longer source location string that will '
                    'genuinely overflow this three-hundred-pixel-wide box',
                style: _style,
                fadeColor: _fadeColor,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        _scrollFinder,
        findsOneWidget,
        reason: 'must re-measure the new (much longer) text, not keep '
            'using a cached measurement of the old short one',
      );
    },
  );
}
