import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/screens/calendar/calendar_screen.dart';
import 'package:tadarab_app/services/calendar_service.dart';

import '../../helpers/fake_calendar_service.dart';
import '../../helpers/fake_home_data_service.dart';

void main() {
  // A fixed "today" inside May 2026 — the month the mockups show, whose
  // 1st falls on a Friday, so the grid layout matches the design exactly.
  final now = DateTime(2026, 5, 3, 9, 0);

  CalendarEvent event({
    String id = 'e1',
    String name = 'Midterm',
    int day = 14,
    String time = '23:59',
    String color = '#F0A93B',
  }) {
    return CalendarEvent(
      eventId: id,
      eventName: name,
      eventDate: DateTime(2026, 5, day),
      eventTime: time,
      color: color,
      email: 'student@example.com',
    );
  }

  Future<void> pumpCalendar(
    WidgetTester tester, {
    FakeCalendarService? service,
    VoidCallback? onEventsChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            uid: 'uid-1',
            calendarService: service ?? FakeCalendarService(),
            homeDataService: FakeHomeDataService(),
            now: now,
            onEventsChanged: onEventsChanged,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('empty state (01_calendar_empty)', () {
    testWidgets('shows the month grid, Add Event, and the empty line', (
      tester,
    ) async {
      await pumpCalendar(tester);

      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('+ Add Event'), findsOneWidget);
      expect(find.text('May 2026'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(
        find.text('No events yet. Tap "Add Event" to schedule your first one.'),
        findsOneWidget,
      );
    });

    testWidgets('has no Upcoming Events list — that belongs on Home', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(events: [event()]),
      );

      expect(find.text('Upcoming Events'), findsNothing);
      expect(find.text('See all'), findsNothing);
    });
  });

  group('with events (02_calendar_with_events)', () {
    testWidgets('hides the empty line once the month has events', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(events: [event()]),
      );

      expect(
        find.text('No events yet. Tap "Add Event" to schedule your first one.'),
        findsNothing,
      );
    });

    testWidgets('renders a dot per event, including on today', (tester) async {
      // Today (the 3rd) gets a dot like any other day — the red today
      // marker does not suppress it.
      await pumpCalendar(
        tester,
        service: FakeCalendarService(
          events: [
            event(id: 'a', day: 3),
            event(id: 'b', day: 14),
            event(id: 'c', day: 14),
          ],
        ),
      );

      expect(find.byKey(const ValueKey('day-dot-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-dot-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-dot-c')), findsOneWidget);
    });
  });

  group('month navigation', () {
    testWidgets('steps forward and back, re-querying each month', (
      tester,
    ) async {
      final service = FakeCalendarService();
      await pumpCalendar(tester, service: service);

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('June 2026'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('April 2026'), findsOneWidget);

      expect(
        service.watchedMonths,
        containsAll([
          DateTime(2026, 5, 1),
          DateTime(2026, 6, 1),
          DateTime(2026, 4, 1),
        ]),
      );
    });

    testWidgets('rolls over the year boundary', (tester) async {
      await pumpCalendar(tester);

      for (var i = 0; i < 8; i++) {
        await tester.tap(find.bySemanticsLabel('Next month'));
        await tester.pumpAndSettle();
      }

      expect(find.text('January 2027'), findsOneWidget);
    });
  });

  group('day details sheet (03_calendar_event_details)', () {
    testWidgets('tapping a day with events lists them with their times', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(
          events: [
            event(id: 'a', name: 'GP1 Report Submission', day: 14),
            event(id: 'b', name: 'GP1 Presentation Submission', day: 14),
          ],
        ),
      );

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();

      expect(find.text('May 14, 2026'), findsOneWidget);
      expect(find.text('GP1 Report Submission'), findsOneWidget);
      expect(find.text('GP1 Presentation Submission'), findsOneWidget);
      expect(find.text('11:59 PM'), findsNWidgets(2));
    });

    testWidgets('tapping a day with no events opens nothing', (tester) async {
      await pumpCalendar(
        tester,
        service: FakeCalendarService(events: [event(day: 14)]),
      );

      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();

      expect(find.text('May 21, 2026'), findsNothing);
    });
  });

  group('delete (04_delete_event_confirmation)', () {
    testWidgets('confirming deletes the event and reports the change', (
      tester,
    ) async {
      final service = FakeCalendarService(events: [event(id: 'e9', day: 14)]);
      var changed = 0;
      await pumpCalendar(
        tester,
        service: service,
        onEventsChanged: () => changed++,
      );

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete this event?'), findsOneWidget);
      expect(
        find.text('The selected event will be removed from your calendar.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(service.deletedEventIds, ['e9']);
      expect(changed, 1);
    });

    testWidgets('cancelling deletes nothing and keeps the sheet open', (
      tester,
    ) async {
      final service = FakeCalendarService(events: [event(id: 'e9', day: 14)]);
      await pumpCalendar(tester, service: service);

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.deletedEventIds, isEmpty);
      expect(find.text('May 14, 2026'), findsOneWidget);
    });

    testWidgets('a failed delete surfaces a message instead of failing silently', (
      tester,
    ) async {
      final service = FakeCalendarService(
        events: [event(id: 'e9', day: 14)],
        deleteError: CalendarFailure('Network unavailable.'),
      );
      await pumpCalendar(tester, service: service);

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(service.deletedEventIds, isEmpty);
      expect(find.text('Network unavailable.'), findsOneWidget);
    });
  });

  group('load failure', () {
    testWidgets('shows the error banner with a retry instead of a blank grid', (
      tester,
    ) async {
      final service = FakeCalendarService(
        loadError: CalendarFailure("Couldn't reach Tadarab."),
      );
      await pumpCalendar(tester, service: service);

      expect(find.text("Couldn't load your calendar"), findsOneWidget);
      expect(find.text("Couldn't reach Tadarab."), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('retry re-subscribes to the month stream', (tester) async {
      final service = FakeCalendarService(
        loadError: CalendarFailure("Couldn't reach Tadarab."),
      );
      await pumpCalendar(tester, service: service);
      final before = service.watchedMonths.length;

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(service.watchedMonths.length, greaterThan(before));
    });
  });
}
