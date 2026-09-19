import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/services/calendar_service.dart';

import '../helpers/fake_reminder_scheduler.dart';

/// A Firestore whose batches always fail to commit — the only way to reach
/// deleteEventsForCourse's batch failure path, since fake_cloud_firestore
/// can't inject an exception on a rebuilt `.where()` query.
class _FailingBatchFirestore extends FakeFirebaseFirestore {
  @override
  WriteBatch batch() => _FailingBatch();
}

class _FailingBatch implements WriteBatch {
  @override
  void delete(DocumentReference document) {}

  @override
  Future<void> commit() async =>
      throw FirebaseException(plugin: 'cloud_firestore');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Supplies a signed-in email without needing a FirebaseAuth mock.
class _SignedInCalendarService extends CalendarService {
  _SignedInCalendarService({super.firestore, super.reminderScheduler});

  @override
  String? get currentEmail => 'student@example.com';
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeReminderScheduler reminders;
  late CalendarService service;

  CollectionReference<Map<String, dynamic>> events(String uid) =>
      firestore.collection('users').doc(uid).collection('events');

  Future<String> seed(String uid, {String? courseId, String name = 'E'}) async {
    final ref = await events(uid).add(
      CalendarEvent(
        eventId: '',
        eventName: name,
        eventDate: DateTime(2026, 5, 14),
        eventTime: '12:00',
        email: 'student@example.com',
        courseId: courseId,
      ).toFirestore(),
    );
    return ref.id;
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    reminders = FakeReminderScheduler();
    service = CalendarService(
      firestore: firestore,
      reminderScheduler: reminders,
    );
  });

  group('deleteEventsForCourse', () {
    test('deletes only that course\'s events and cancels their reminders', () async {
      final a = await seed('uid-1', courseId: 'c1');
      final b = await seed('uid-1', courseId: 'c1');
      final otherCourse = await seed('uid-1', courseId: 'c2');
      final noCourse = await seed('uid-1');

      final deleted = await service.deleteEventsForCourse('uid-1', 'c1');

      expect(deleted, 2);
      final remaining = (await events('uid-1').get()).docs.map((d) => d.id);
      expect(remaining, unorderedEquals([otherCourse, noCourse]));
      expect(reminders.cancelled, unorderedEquals([a, b]));
    });

    test('never touches another student\'s events with the same course ID', () async {
      await seed('uid-1', courseId: 'c1');
      final someoneElses = await seed('uid-2', courseId: 'c1');

      await service.deleteEventsForCourse('uid-1', 'c1');

      final theirs = (await events('uid-2').get()).docs.map((d) => d.id);
      expect(theirs, [someoneElses]);
    });

    test('a course with no events deletes nothing and cancels nothing', () async {
      final kept = await seed('uid-1', courseId: 'c2');

      final deleted = await service.deleteEventsForCourse('uid-1', 'c1');

      expect(deleted, 0);
      expect(reminders.cancelled, isEmpty);
      expect((await events('uid-1').get()).docs.single.id, kept);
    });

    test('deletes past the 500-per-batch Firestore limit', () async {
      // 501 forces a second batch; a single-batch implementation would
      // either fail or silently leave the 501st event behind.
      for (var i = 0; i < 501; i++) {
        await seed('uid-1', courseId: 'c1');
      }

      final deleted = await service.deleteEventsForCourse('uid-1', 'c1');

      expect(deleted, 501);
      expect((await events('uid-1').get()).docs, isEmpty);
      expect(reminders.cancelled.length, 501);
    });

    test('a failed commit throws CalendarFailure and cancels no reminders', () async {
      firestore = _FailingBatchFirestore();
      service = CalendarService(
        firestore: firestore,
        reminderScheduler: reminders,
      );
      await seed('uid-1', courseId: 'c1');

      await expectLater(
        service.deleteEventsForCourse('uid-1', 'c1'),
        throwsA(isA<CalendarFailure>()),
      );
      // The events still exist, so their reminders must still fire.
      expect(reminders.cancelled, isEmpty);
    });
  });

  group('deleteEvent', () {
    test('deletes the event and cancels its reminder', () async {
      final id = await seed('uid-1');

      await service.deleteEvent('uid-1', id);

      expect((await events('uid-1').get()).docs, isEmpty);
      expect(reminders.cancelled, [id]);
    });

    test('a failed delete throws and leaves the reminder scheduled', () async {
      final id = await seed('uid-1');
      whenCalling(Invocation.method(#delete, null))
          .on(events('uid-1').doc(id))
          .thenThrow(FirebaseException(plugin: 'cloud_firestore'));

      await expectLater(
        service.deleteEvent('uid-1', id),
        throwsA(isA<CalendarFailure>()),
      );
      expect(reminders.cancelled, isEmpty);
    });
  });

  group('addEvent', () {
    test('stamps the signed-in student\'s email onto the stored event', () async {
      // `email` is a non-null FK to Student in the Attributes Dictionary
      // Table; the Add Event form passes an empty one.
      final signedIn = _SignedInCalendarService(
        firestore: firestore,
        reminderScheduler: reminders,
      );

      final id = await signedIn.addEvent(
        'uid-1',
        CalendarEvent(
          eventId: '',
          eventName: 'Midterm',
          eventDate: DateTime(2026, 5, 5),
          eventTime: '12:00',
          email: '',
        ),
      );

      final doc = await events('uid-1').doc(id).get();
      expect(doc.data()!['email'], 'student@example.com');
    });

    test('keeps an email the caller already set', () async {
      final signedIn = _SignedInCalendarService(
        firestore: firestore,
        reminderScheduler: reminders,
      );

      final id = await signedIn.addEvent(
        'uid-1',
        CalendarEvent(
          eventId: '',
          eventName: 'Midterm',
          eventDate: DateTime(2026, 5, 5),
          eventTime: '12:00',
          email: 'explicit@example.com',
        ),
      );

      final doc = await events('uid-1').doc(id).get();
      expect(doc.data()!['email'], 'explicit@example.com');
    });

    test('writes to a reserved ID when the event carries one', () async {
      final reserved = service.newEventId('uid-1');
      // Reserving writes nothing — the event only exists once it's added.
      expect((await events('uid-1').doc(reserved).get()).exists, isFalse);

      final id = await service.addEvent(
        'uid-1',
        CalendarEvent(
          eventId: reserved,
          eventName: 'Midterm',
          eventDate: DateTime(2026, 5, 5),
          eventTime: '12:00',
          email: 'student@example.com',
        ),
      );

      expect(id, reserved);
      expect((await events('uid-1').get()).docs.single.id, reserved);
    });

    test('reserves a different ID each time', () {
      expect(service.newEventId('uid-1'), isNot(service.newEventId('uid-1')));
    });

    test('writes the event and returns its Firestore-assigned ID', () async {
      final id = await service.addEvent(
        'uid-1',
        CalendarEvent(
          eventId: '',
          eventName: 'Midterm',
          eventDate: DateTime(2026, 5, 5),
          eventTime: '12:00',
          email: 'student@example.com',
        ),
      );

      final doc = await events('uid-1').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['eventName'], 'Midterm');
    });
  });
}
