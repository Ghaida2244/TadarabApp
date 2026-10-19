import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/widgets/scrollable_title_pill.dart';

const _style = TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800);

void main() {
  Future<void> pump(WidgetTester tester, String text, {double width = 200}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: width, child: ScrollableTitlePill(text: text, style: _style)),
        ),
      ),
    );
    // The hug-vs-scroll decision needs an extra pump after the first: the
    // available width is read from a RenderBox in a post-frame callback,
    // then a setState schedules the frame that may switch into scroll mode.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a short title hugs its content — no scroll view is '
      'introduced', (tester) async {
    await pump(tester, 'Lecture 1');

    expect(find.text('Lecture 1'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('a long title becomes exactly the available width and is '
      'genuinely drag-scrollable — not wrapped, not truncated', (
    tester,
  ) async {
    const text =
        'Lecture 1 - Introduction to Databases, Lecture 2 - Requirements '
        'Engineering, Lecture 3 - Entity Relationship Diagrams';
    await pump(tester, text, width: 200);

    expect(find.text(text), findsOneWidget);
    final scrollFinder = find.byType(SingleChildScrollView);
    expect(scrollFinder, findsOneWidget);
    expect(
      tester.widget<SingleChildScrollView>(scrollFinder).scrollDirection,
      Axis.horizontal,
    );

    final scrollableState = tester.state<ScrollableState>(
      find.descendant(of: scrollFinder, matching: find.byType(Scrollable)),
    );
    expect(scrollableState.position.pixels, 0.0);

    await tester.drag(scrollFinder, const Offset(-80, 0));
    await tester.pump();

    expect(scrollableState.position.pixels, greaterThan(0.0));
  });

  testWidgets(
    'regression: when the text changes after the first build (e.g. '
    'resolving asynchronously, as Quiz Sessions\' materials label does), '
    'the overflow decision reflects the NEW text, not a stale '
    'measurement of whatever text was showing at the very first build',
    (tester) async {
      // First build: a short placeholder, well within a generous width —
      // correctly hugs with no scroll view.
      await pump(tester, 'Material removed', width: 300);
      expect(find.byType(SingleChildScrollView), findsNothing);

      // The real label arrives later and is far longer than the first
      // one — rebuilding with the SAME widget (no key change, same
      // State object, exactly how a parent's FutureBuilder/StreamBuilder
      // resolving later behaves).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: ScrollableTitlePill(
                text:
                    'Lecture 1 - Introduction to Databases, Lecture 2 - '
                    'Requirements Engineering, Lecture 3 - Entity '
                    'Relationship Diagrams',
                style: _style,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byType(SingleChildScrollView),
        findsOneWidget,
        reason: 'the pill must re-measure the new (much longer) text, not '
            'keep using a cached measurement of the old placeholder',
      );
    },
  );
}
