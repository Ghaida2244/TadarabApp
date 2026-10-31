import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/services/calendar_service.dart';
import 'package:tadarab_app/services/courses_service.dart';

import '../helpers/fake_reminder_scheduler.dart';

/// A Firestore whose batches always fail to commit — the only way to force
/// [CalendarService.deleteEventsForCourse]'s batch-delete to fail, since
/// fake_cloud_firestore can't inject an exception on a rebuilt `.where()`
/// query's `.get()` (same technique `calendar_service_test.dart` uses for
/// its own equivalent test).
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

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeReminderScheduler reminders;
  late CalendarService calendarService;
  late CoursesService coursesService;

  CollectionReference<Map<String, dynamic>> coursesRef(
    FirebaseFirestore fs,
    String uid,
  ) => fs.collection('users').doc(uid).collection('courses');

  CollectionReference<Map<String, dynamic>> eventsRef(
    FirebaseFirestore fs,
    String uid,
  ) => fs.collection('users').doc(uid).collection('events');

  Future<void> seedCourse(
    FirebaseFirestore fs,
    String uid,
    String courseId,
  ) => coursesRef(fs, uid).doc(courseId).set(
    Course(
      courseId: courseId,
      courseName: 'Course $courseId',
      color: '#16A34A',
      email: 'student@example.com',
    ).toFirestore(),
  );

  Future<String> seedEvent(
    FirebaseFirestore fs, {
    required String uid,
    String? courseId,
  }) async {
    final ref = await eventsRef(fs, uid).add(
      CalendarEvent(
        eventId: '',
        eventName: 'E',
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
    calendarService = CalendarService(
      firestore: firestore,
      reminderScheduler: reminders,
    );
    coursesService = CoursesService(
      firestore: firestore,
      calendarService: calendarService,
    );
  });

  group('deleteCourse', () {
    test(
      'removes the course\'s events, cancels their reminders, and deletes '
      'the course itself',
      () async {
        await seedCourse(firestore, 'uid-1', 'c1');
        final e1 = await seedEvent(firestore, uid: 'uid-1', courseId: 'c1');
        final e2 = await seedEvent(firestore, uid: 'uid-1', courseId: 'c1');

        await coursesService.deleteCourse('uid-1', 'c1');

        expect(
          (await coursesRef(firestore, 'uid-1').doc('c1').get()).exists,
          isFalse,
        );
        expect((await eventsRef(firestore, 'uid-1').get()).docs, isEmpty);
        expect(reminders.cancelled, unorderedEquals([e1, e2]));
      },
    );

    test(
      'leaves events of other courses and standalone events untouched',
      () async {
        await seedCourse(firestore, 'uid-1', 'c1');
        await seedCourse(firestore, 'uid-1', 'c2');
        final otherCourse = await seedEvent(
          firestore,
          uid: 'uid-1',
          courseId: 'c2',
        );
        final standalone = await seedEvent(firestore, uid: 'uid-1');
        await seedEvent(firestore, uid: 'uid-1', courseId: 'c1');

        await coursesService.deleteCourse('uid-1', 'c1');

        final remaining = (await eventsRef(
          firestore,
          'uid-1',
        ).get()).docs.map((d) => d.id);
        expect(remaining, unorderedEquals([otherCourse, standalone]));
        expect(reminders.cancelled, isNot(contains(otherCourse)));
        expect(reminders.cancelled, isNot(contains(standalone)));
      },
    );

    test(
      'never touches another student\'s events with the same course ID',
      () async {
        await seedCourse(firestore, 'uid-1', 'c1');
        final someoneElses = await seedEvent(
          firestore,
          uid: 'uid-2',
          courseId: 'c1',
        );

        await coursesService.deleteCourse('uid-1', 'c1');

        final theirs = (await eventsRef(
          firestore,
          'uid-2',
        ).get()).docs.map((d) => d.id);
        expect(theirs, [someoneElses]);
        expect(reminders.cancelled, isEmpty);
      },
    );

    test(
      'a failure deleting events leaves the course and its events exactly '
      'as they were',
      () async {
        final failingFirestore = _FailingBatchFirestore();
        final failingCalendarService = CalendarService(
          firestore: failingFirestore,
          reminderScheduler: reminders,
        );
        final failingCoursesService = CoursesService(
          firestore: failingFirestore,
          calendarService: failingCalendarService,
        );
        await seedCourse(failingFirestore, 'uid-1', 'c1');
        final eventId = await seedEvent(
          failingFirestore,
          uid: 'uid-1',
          courseId: 'c1',
        );

        await expectLater(
          failingCoursesService.deleteCourse('uid-1', 'c1'),
          throwsA(isA<CoursesFailure>()),
        );

        // Nothing was deleted: the course delete never ran.
        expect(
          (await coursesRef(failingFirestore, 'uid-1').doc('c1').get()).exists,
          isTrue,
        );
        expect(
          (await eventsRef(failingFirestore, 'uid-1').doc(eventId).get()).exists,
          isTrue,
        );
        // The event still exists, so its reminder must still fire.
        expect(reminders.cancelled, isEmpty);
      },
    );
  });
}
