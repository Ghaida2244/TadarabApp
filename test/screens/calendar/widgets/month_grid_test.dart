import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/screens/calendar/widgets/month_grid.dart';
import 'package:tadarab_app/theme/app_theme.dart';

void main() {
  // May 2026 is deliberately a six-row month: the 1st is a Friday, so five
  // leading blanks plus 31 days fills 36 cells. It is therefore the tightest
  // realistic layout the cell contents have to survive.
  final month = DateTime(2026, 5, 1);
  final today = DateTime(2026, 5, 3);

  CalendarEvent event(int index, {int day = 14}) => CalendarEvent(
    eventId: 'e$index',
    eventName: 'Event $index',
    eventDate: DateTime(2026, 5, day),
    eventTime: '0${index % 10}:00',
    color: '#2563EB',
    email: 'student@example.com',
  );

  /// Pumps the grid at a given surface, boxed to the height a real screen
  /// leaves it (the navy header and nav bar take the rest).
  Future<void> pumpGrid(
    WidgetTester tester, {
    required int eventsOnThe14th,
    Size surface = const Size(412, 892),
    double gridHeight = 520,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: gridHeight,
              child: MonthGrid(
                month: month,
                today: today,
                eventsByDay: {
                  if (eventsOnThe14th > 0)
                    DateTime(2026, 5, 14): [
                      for (var i = 0; i < eventsOnThe14th; i++) event(i),
                    ],
                },
                onDayTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Confirms the grid really did lay out six rows.
  void expectSixRows(WidgetTester tester) {
    expect(find.text('31'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  }

  group('dot row with overflow', () {
    for (final count in [3, 4, 10]) {
      testWidgets('$count events: two dots plus "+${count - 2}", unclipped', (
        tester,
      ) async {
        await pumpGrid(tester, eventsOnThe14th: count);
        expectSixRows(tester);

        // Exactly two dots, then the overflow label.
        expect(find.byKey(const ValueKey('day-dot-e0')), findsOneWidget);
        expect(find.byKey(const ValueKey('day-dot-e1')), findsOneWidget);
        expect(find.byKey(const ValueKey('day-dot-e2')), findsNothing);

        final label = find.text('+${count - 2}');
        expect(label, findsOneWidget);

        // The regression: a fixed 6px row painted the 9px label clipped.
        // Cross-axis overflow throws nothing, so the only way to catch it is
        // to measure.
        final size = tester.getSize(label);
        expect(
          size.height,
          greaterThan(6),
          reason: 'the "+N" label is being squashed into the dots\' 6px row',
        );
        expect(size.width, greaterThan(0));
        expect(tester.takeException(), isNull);
      });

      testWidgets('$count events: dots and "+${count - 2}" share one line', (
        tester,
      ) async {
        await pumpGrid(tester, eventsOnThe14th: count);

        final lastDot = tester.getRect(
          find.byKey(const ValueKey('day-dot-e1')),
        );
        final label = tester.getRect(find.text('+${count - 2}'));

        // Vertically centred on each other, within a pixel.
        expect(
          (lastDot.center.dy - label.center.dy).abs(),
          lessThan(1.0),
          reason: 'the dots and the "+N" label are not on one line',
        );
        // And the label sits after the dots, with the design's gap.
        expect(label.left, greaterThanOrEqualTo(lastDot.right));
        expect(label.left - lastDot.right, closeTo(kDayDotGap, 1.0));
      });
    }

    testWidgets('10 events still fits inside its day cell', (tester) async {
      await pumpGrid(tester, eventsOnThe14th: 10);

      final cell = tester.getRect(
        find.ancestor(
          of: find.text('14'),
          matching: find.byType(GestureDetector),
        ).first,
      );
      final label = tester.getRect(find.text('+8'));
      final firstDot = tester.getRect(
        find.byKey(const ValueKey('day-dot-e0')),
      );

      expect(firstDot.left, greaterThanOrEqualTo(cell.left));
      expect(label.right, lessThanOrEqualTo(cell.right));
      expect(label.bottom, lessThanOrEqualTo(cell.bottom + 0.5));
    });

    testWidgets('survives a deliberately short six-row grid', (tester) async {
      // Half the usual height, so every cell is compressed hard.
      await pumpGrid(tester, eventsOnThe14th: 10, gridHeight: 260);

      expect(tester.takeException(), isNull);
      expect(find.text('+8'), findsOneWidget);
      expect(tester.getSize(find.text('+8')).height, greaterThan(6));
    });

    testWidgets('survives a narrow 320dp phone', (tester) async {
      await pumpGrid(
        tester,
        eventsOnThe14th: 10,
        surface: const Size(320, 640),
        gridHeight: 400,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('+8'), findsOneWidget);
    });
  });

  group('dot row without overflow', () {
    testWidgets('one event shows a single dot and no label', (tester) async {
      await pumpGrid(tester, eventsOnThe14th: 1);

      expect(find.byKey(const ValueKey('day-dot-e0')), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('exactly two events show two dots and no label', (
      tester,
    ) async {
      await pumpGrid(tester, eventsOnThe14th: 2);

      expect(find.byKey(const ValueKey('day-dot-e0')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-dot-e1')), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('two dots sit a design gap apart', (tester) async {
      await pumpGrid(tester, eventsOnThe14th: 2);

      final first = tester.getRect(find.byKey(const ValueKey('day-dot-e0')));
      final second = tester.getRect(find.byKey(const ValueKey('day-dot-e1')));

      expect(second.left - first.right, closeTo(kDayDotGap, 0.5));
      expect((first.center.dy - second.center.dy).abs(), lessThan(0.5));
    });

    testWidgets('a day with no events renders no dots', (tester) async {
      await pumpGrid(tester, eventsOnThe14th: 0);

      expect(find.byKey(const ValueKey('day-dot-e0')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('today marker', () {
    testWidgets('is an outline, not a fill', (tester) async {
      await pumpGrid(tester, eventsOnThe14th: 0);

      final decoration = tester
              .widget<Container>(
                find.ancestor(
                  of: find.text('3'),
                  matching: find.byType(Container),
                ).first,
              )
              .decoration!
          as BoxDecoration;

      expect(decoration.color, AppColors.errorBannerBackground);
      expect((decoration.border! as Border).top.color, AppColors.red);
    });
  });
}
