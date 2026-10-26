import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/services/home_data_service.dart';

void main() {
  group('startOfWeek', () {
    test('a Wednesday resolves to the preceding Sunday', () {
      // 2026-03-11 is a Wednesday.
      expect(startOfWeek(DateTime(2026, 3, 11)), DateTime(2026, 3, 8));
    });

    test('a Sunday resolves to itself', () {
      expect(startOfWeek(DateTime(2026, 3, 8)), DateTime(2026, 3, 8));
    });

    test('a Saturday resolves to the Sunday six days earlier', () {
      expect(startOfWeek(DateTime(2026, 3, 14)), DateTime(2026, 3, 8));
    });
  });

  group('aggregateWeeklyProgress', () {
    final weekStart = DateTime(2026, 3, 8); // Sunday

    test('an empty entry list produces all-zero days for the full week', () {
      final result = aggregateWeeklyProgress(
        weekStart: weekStart,
        entries: const [],
      );

      expect(result.days.length, 7);
      expect(result.days.every((d) => d.combined == 0), isTrue);
      expect(result.weekStart, weekStart);
    });

    test('sums multiple entries landing on the same day', () {
      final result = aggregateWeeklyProgress(
        weekStart: weekStart,
        entries: [
          (date: DateTime(2026, 3, 10), questionCount: 5, flashcardCount: 0),
          (date: DateTime(2026, 3, 10), questionCount: 0, flashcardCount: 3),
        ],
      );

      final tuesday = result.days[2]; // Sun=0, Mon=1, Tue=2
      expect(tuesday.questionCount, 5);
      expect(tuesday.flashcardCount, 3);
      expect(tuesday.combined, 8);
    });

    test('a flashcards-only day still counts toward the combined total', () {
      final result = aggregateWeeklyProgress(
        weekStart: weekStart,
        entries: [
          (date: DateTime(2026, 3, 9), questionCount: 0, flashcardCount: 4),
        ],
      );

      expect(result.days[1].combined, 4);
    });

    test('entries outside the week are ignored rather than throwing', () {
      final result = aggregateWeeklyProgress(
        weekStart: weekStart,
        entries: [
          (
            date: DateTime(2026, 3, 1),
            questionCount: 9,
            flashcardCount: 0,
          ), // before the week
          (
            date: DateTime(2026, 3, 20),
            questionCount: 9,
            flashcardCount: 0,
          ), // after the week
        ],
      );

      expect(result.days.every((d) => d.combined == 0), isTrue);
    });

    test(
      'a timestamp with a time-of-day still lands on the correct local day',
      () {
        final result = aggregateWeeklyProgress(
          weekStart: weekStart,
          entries: [
            (
              date: DateTime(2026, 3, 8, 23, 59),
              questionCount: 2,
              flashcardCount: 0,
            ),
          ],
        );

        expect(result.days[0].questionCount, 2);
      },
    );
  });

  group('WeeklyProgress.dayForDate', () {
    test('returns the matching day within the week', () {
      final progress = aggregateWeeklyProgress(
        weekStart: DateTime(2026, 3, 8),
        entries: [
          (date: DateTime(2026, 3, 11), questionCount: 7, flashcardCount: 0),
        ],
      );

      expect(progress.dayForDate(DateTime(2026, 3, 11)).questionCount, 7);
    });

    test(
      'returns a zeroed day for a date outside the week rather than throwing',
      () {
        final progress = aggregateWeeklyProgress(
          weekStart: DateTime(2026, 3, 8),
          entries: const [],
        );

        final outside = progress.dayForDate(DateTime(2026, 4, 1));
        expect(outside.combined, 0);
      },
    );
  });

  group('notYetStartedUpcoming', () {
    // A fixed Wednesday afternoon, matching the convention used elsewhere
    // (e.g. test/screens/home_screen_test.dart) for a deterministic clock.
    final now = DateTime(2026, 3, 11, 14, 30);

    CalendarEvent event({
      required String id,
      required DateTime date,
      required String time,
    }) => CalendarEvent(
      eventId: id,
      eventName: id,
      eventDate: date,
      eventTime: time,
      email: 'e@x.com',
    );

    test(
      'an event earlier today is hidden while a later one today and one '
      'tomorrow are shown',
      () {
        final earlierToday = event(
          id: 'earlier',
          date: DateTime(2026, 3, 11),
          time: '09:00',
        );
        final laterToday = event(
          id: 'later',
          date: DateTime(2026, 3, 11),
          time: '18:00',
        );
        final tomorrow = event(
          id: 'tomorrow',
          date: DateTime(2026, 3, 12),
          time: '08:00',
        );

        final result = notYetStartedUpcoming(
          [earlierToday, laterToday, tomorrow],
          now: now,
        );

        expect(result.map((e) => e.eventId), ['later', 'tomorrow']);
      },
    );

    test(
      'started events do not consume the 5-slot limit — real upcoming '
      'events still all make it in',
      () {
        final startedToday = List.generate(
          4,
          (i) => event(
            id: 'started-$i',
            date: DateTime(2026, 3, 11),
            time: '0$i:00', // 00:00, 01:00, 02:00, 03:00 — all before 14:30
          ),
        );
        final upcoming = List.generate(
          5,
          (i) => event(
            id: 'upcoming-$i',
            date: DateTime(2026, 3, 11 + i),
            time: '18:00',
          ),
        );

        final result = notYetStartedUpcoming([
          ...startedToday,
          ...upcoming,
        ], now: now);

        expect(result.length, 5);
        expect(
          result.every((e) => e.eventId.startsWith('upcoming-')),
          isTrue,
        );
      },
    );

    test(
      'boundary: an event starting exactly at now is hidden, one minute '
      'later is shown',
      () {
        final exactlyNow = event(
          id: 'exactly-now',
          date: DateTime(2026, 3, 11),
          time: '14:30',
        );
        final oneMinuteLater = event(
          id: 'one-minute-later',
          date: DateTime(2026, 3, 11),
          time: '14:31',
        );

        final result = notYetStartedUpcoming([
          exactlyNow,
          oneMinuteLater,
        ], now: now);

        expect(result.map((e) => e.eventId), ['one-minute-later']);
      },
    );

    test('orders by date, then by time within the same day', () {
      final a = event(id: 'a', date: DateTime(2026, 3, 12), time: '09:00');
      final b = event(id: 'b', date: DateTime(2026, 3, 11), time: '20:00');
      final c = event(id: 'c', date: DateTime(2026, 3, 11), time: '16:00');

      // Deliberately not already in the expected order.
      final result = notYetStartedUpcoming([a, b, c], now: now);

      expect(result.map((e) => e.eventId), ['c', 'b', 'a']);
    });

    test(
      'an unparsable stored time is treated as starting at 00:00 of its '
      'day — already-past for any event dated today or earlier',
      () {
        final badTimeToday = event(
          id: 'bad-time-today',
          date: DateTime(2026, 3, 11),
          time: 'not-a-time',
        );
        final badTimeTomorrow = event(
          id: 'bad-time-tomorrow',
          date: DateTime(2026, 3, 12),
          time: 'not-a-time',
        );

        final result = notYetStartedUpcoming([
          badTimeToday,
          badTimeTomorrow,
        ], now: now);

        // Today's instance falls back to 00:00 today, already before
        // `now` (14:30) — hidden. Tomorrow's falls back to 00:00
        // tomorrow, still after `now` — shown.
        expect(result.map((e) => e.eventId), ['bad-time-tomorrow']);
      },
    );

    test('respects a custom limit', () {
      final events = List.generate(
        3,
        (i) => event(
          id: 'e$i',
          date: DateTime(2026, 3, 11 + i),
          time: '18:00',
        ),
      );

      expect(notYetStartedUpcoming(events, now: now, limit: 2).length, 2);
    });
  });

  group('notYetStartedUpcomingViews', () {
    final now = DateTime(2026, 3, 11, 14, 30);

    test(
      'applies the same not-yet-started/sort/limit rule to the already-'
      'resolved UpcomingEventView, preserving courseName',
      () {
        final started = UpcomingEventView(
          event: CalendarEvent(
            eventId: 'started',
            eventName: 'started',
            eventDate: DateTime(2026, 3, 11),
            eventTime: '09:00',
            email: 'e@x.com',
          ),
          courseName: 'IS230',
        );
        final upcoming = UpcomingEventView(
          event: CalendarEvent(
            eventId: 'upcoming',
            eventName: 'upcoming',
            eventDate: DateTime(2026, 3, 11),
            eventTime: '18:00',
            email: 'e@x.com',
          ),
          courseName: 'IS230',
        );

        final result = notYetStartedUpcomingViews([
          started,
          upcoming,
        ], now: now);

        expect(result, hasLength(1));
        expect(result.single.event.eventId, 'upcoming');
        expect(result.single.courseName, 'IS230');
      },
    );
  });

  group('HomeDataService.fetchUpcomingEvents', () {
    final now = DateTime(2026, 3, 11, 14, 30);

    Future<void> seedEvent(
      FakeFirebaseFirestore firestore,
      String uid, {
      required String id,
      required DateTime date,
      required String time,
    }) => firestore
        .collection('users')
        .doc(uid)
        .collection('events')
        .doc(id)
        .set(
          CalendarEvent(
            eventId: id,
            eventName: id,
            eventDate: date,
            eventTime: time,
            email: 'e@x.com',
          ).toFirestore(),
        );

    test(
      'overfetches enough to let several already-started events today '
      'not crowd out real upcoming ones, without a composite index',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = HomeDataService(firestore: firestore);
        const uid = 'uid-1';

        // 4 already-started events today, then 5 real upcoming ones —
        // mirrors the pure-function test above, but through the real
        // Firestore-backed query + overfetch + filter pipeline.
        for (var i = 0; i < 4; i++) {
          await seedEvent(
            firestore,
            uid,
            id: 'started-$i',
            date: DateTime(2026, 3, 11),
            time: '0$i:00',
          );
        }
        for (var i = 0; i < 5; i++) {
          await seedEvent(
            firestore,
            uid,
            id: 'upcoming-$i',
            date: DateTime(2026, 3, 11 + i),
            time: '18:00',
          );
        }

        final result = await service.fetchUpcomingEvents(uid, now: now);

        expect(result.length, 5);
        expect(
          result.every((v) => v.event.eventId.startsWith('upcoming-')),
          isTrue,
        );
      },
    );
  });
}
