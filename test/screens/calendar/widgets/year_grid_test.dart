import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/screens/calendar/widgets/year_grid.dart';
import 'package:tadarab_app/theme/app_theme.dart';

void main() {
  final today = DateTime(2026, 5, 3);

  CalendarEvent event({
    String id = 'e1',
    required DateTime date,
    String time = '09:00',
    String color = '#2563EB',
  }) => CalendarEvent(
    eventId: id,
    eventName: 'Midterm',
    eventDate: date,
    eventTime: time,
    color: color,
    email: 'student@example.com',
  );

  Future<List<int>> pumpYear(
    WidgetTester tester, {
    Map<DateTime, List<CalendarEvent>> eventsByDay = const {},
  }) async {
    final opened = <int>[];
    // The design's own canvas, so all twelve lazily-built cards exist.
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YearGrid(
            year: 2026,
            eventsByDay: eventsByDay,
            today: today,
            onMonthSelected: opened.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  /// The circular pill behind a given date inside a mini-month.
  BoxDecoration dayDecoration(WidgetTester tester, int month, int day) {
    return tester
            .widget<Container>(find.byKey(ValueKey('mini-day-$month-$day')))
            .decoration!
        as BoxDecoration;
  }

  testWidgets('renders all twelve months', (tester) async {
    await pumpYear(tester);

    for (var month = 1; month <= 12; month++) {
      expect(find.byKey(ValueKey('mini-month-$month')), findsOneWidget);
    }
    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('Dec'), findsOneWidget);
  });

  testWidgets('the current month card is outlined in red', (tester) async {
    await pumpYear(tester);

    final may = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('mini-month-5')),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (may.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppColors.red);
  });

  testWidgets('other month cards use the neutral tint border', (tester) async {
    await pumpYear(tester);

    final june = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('mini-month-6')),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (june.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppColors.cardTint);
  });

  testWidgets('today is ringed in red, per todayStyle = ring', (tester) async {
    await pumpYear(tester);

    final decoration = dayDecoration(tester, 5, 3);
    expect(decoration.color, AppColors.errorBannerBackground);
    expect((decoration.border! as Border).top.color, AppColors.red);
  });

  testWidgets('an event day is filled with its colour, per yearMarkers = fill', (
    tester,
  ) async {
    await pumpYear(
      tester,
      eventsByDay: {
        DateTime(2026, 7, 9): [event(date: DateTime(2026, 7, 9))],
      },
    );

    expect(dayDecoration(tester, 7, 9).color, const Color(0xFF2563EB));
  });

  testWidgets('fill uses the earliest event of the day', (tester) async {
    await pumpYear(
      tester,
      eventsByDay: {
        DateTime(2026, 7, 9): [
          event(id: 'late', date: DateTime(2026, 7, 9), time: '18:00'),
          event(
            id: 'early',
            date: DateTime(2026, 7, 9),
            time: '08:00',
            color: '#F5A524',
          ),
        ],
      },
    );

    expect(dayDecoration(tester, 7, 9).color, const Color(0xFFF5A524));
  });

  testWidgets('an event on today keeps the ring but takes the event fill', (
    tester,
  ) async {
    await pumpYear(
      tester,
      eventsByDay: {
        DateTime(2026, 5, 3): [event(date: DateTime(2026, 5, 3))],
      },
    );

    final decoration = dayDecoration(tester, 5, 3);
    expect(decoration.color, const Color(0xFF2563EB));
    expect((decoration.border! as Border).top.color, AppColors.red);
  });

  testWidgets('tapping a month reports its number', (tester) async {
    final opened = await pumpYear(tester);

    await tester.tap(find.byKey(const ValueKey('mini-month-11')));
    await tester.pumpAndSettle();

    expect(opened, [11]);
  });
}
