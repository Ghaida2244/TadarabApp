import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/calendar_event.dart';
import '../utils/event_time.dart';
import 'reminder_scheduler.dart';

/// A user-facing calendar failure. Like [AuthFailure], [message] is always
/// safe to render directly, so screens never switch over Firestore codes.
class CalendarFailure implements Exception {
  CalendarFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

const _loadFailureMessage =
    "Couldn't load your calendar. Check your connection and try again.";
const _saveFailureMessage =
    "Couldn't save your event. Check your connection and try again.";
const _deleteFailureMessage =
    "Couldn't delete this event. Check your connection and try again.";
const _deleteCourseEventsFailureMessage =
    "Couldn't delete this course's events. Check your connection and try again.";

/// Firestore caps a single batched write at 500 operations.
const _maxBatchSize = 500;

/// Firestore-backed calendar data, scoped to users/{uid}/events/{eventId}.
/// Injectable (like [HomeDataService] and [AuthService]) so widget tests can
/// supply canned events for every state without a real Firestore.
///
/// Every method wraps its Firestore call and rethrows a [CalendarFailure]
/// with a readable message, per the NFR that no network call may fail
/// silently or leave a frozen screen.
///
/// Deleting an event also cancels its scheduled reminder. That lives here,
/// not in each screen, so that every delete path — including a course
/// cascade triggered from another feature — keeps the invariant that a
/// deleted event never sends a notification.
class CalendarService {
  CalendarService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ReminderScheduler? reminderScheduler,
  }) : _firestoreOverride = firestore,
       _authOverride = auth,
       _reminderSchedulerOverride = reminderScheduler;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  final ReminderScheduler? _reminderSchedulerOverride;

  late final ReminderScheduler _reminders =
      _reminderSchedulerOverride ?? ReminderScheduler();

  // Resolved lazily so constructing a Calendar screen never itself depends
  // on Firebase being initialized — only actually reading/writing does.
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  /// The signed-in student's email, stamped onto every event written.
  /// `email` is a non-null foreign key to Student in the SRS Attributes
  /// Dictionary Table. Overridable so tests needn't sign a user in.
  String? get currentEmail => _auth.currentUser?.email;

  CollectionReference<Map<String, dynamic>> _events(String uid) =>
      _firestore.collection('users').doc(uid).collection('events');

  /// Every event whose date falls inside [month], soonest first.
  ///
  /// This is a single-field range plus an order-by on that same field,
  /// which Firestore indexes automatically — deliberately *not* combined
  /// with a filter on another field, which is exactly the query shape that
  /// needed the composite indexes added for Home in Phase B.
  Stream<List<CalendarEvent>> watchEventsForMonth(String uid, DateTime month) {
    final start = firstOfMonth(month);
    final end = addMonths(start, 1);
    return _events(uid)
        .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('eventDate', isLessThan: Timestamp.fromDate(end))
        .orderBy('eventDate')
        .snapshots()
        .map((snap) => snap.docs.map(CalendarEvent.fromFirestore).toList())
        .handleError((Object _) => throw CalendarFailure(_loadFailureMessage));
  }

  /// Creates an event and returns the Firestore-assigned document ID, so
  /// the caller can schedule the reminder against it without re-reading it.
  ///
  /// Returns the ID rather than a filled-in [CalendarEvent] so this doesn't
  /// need a `copyWith` on the model — model classes are shared files frozen
  /// after Phase B, and the ID is all any caller actually needs.
  ///
  /// An empty [CalendarEvent.email] is filled in from [currentEmail], since
  /// the Add Event form has no access to the student's email.
  Future<String> addEvent(String uid, CalendarEvent event) async {
    try {
      final data = event.toFirestore();
      if (event.email.isEmpty) data['email'] = currentEmail ?? '';
      final ref = await _events(uid).add(data);
      return ref.id;
    } catch (_) {
      throw CalendarFailure(_saveFailureMessage);
    }
  }

  /// Deletes one event and cancels its reminder. The reminder is only
  /// cancelled once the delete has succeeded — if Firestore fails, the event
  /// still exists, so its reminder should still fire.
  Future<void> deleteEvent(String uid, String eventId) async {
    try {
      await _events(uid).doc(eventId).delete();
    } catch (_) {
      throw CalendarFailure(_deleteFailureMessage);
    }
    await _reminders.cancelReminder(eventId);
  }

  /// Deletes every event linked to [courseId] and cancels their reminders,
  /// returning how many were deleted. Called by the Courses feature when a
  /// course is deleted, so no event is left pointing at a course that no
  /// longer exists.
  ///
  /// Matches on the stored `courseId` key (the model's camelCase field name
  /// for the Attributes Dictionary Table's `courseID`). Deletes in batches of
  /// at most 500, Firestore's per-batch limit, cancelling each batch's
  /// reminders as soon as that batch commits — so a failure partway through
  /// never leaves reminders pending for events that are already gone.
  Future<int> deleteEventsForCourse(String uid, String courseId) async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
    try {
      final snap = await _events(
        uid,
      ).where('courseId', isEqualTo: courseId).get();
      docs = snap.docs;
    } catch (_) {
      throw CalendarFailure(_deleteCourseEventsFailureMessage);
    }

    for (var start = 0; start < docs.length; start += _maxBatchSize) {
      final chunk = docs.skip(start).take(_maxBatchSize).toList();
      try {
        final batch = _firestore.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (_) {
        throw CalendarFailure(_deleteCourseEventsFailureMessage);
      }
      for (final doc in chunk) {
        await _reminders.cancelReminder(doc.id);
      }
    }
    return docs.length;
  }
}

/// Groups [events] by their local calendar day, for the month grid's dots
/// and the day-details sheet. Pure, so the grouping is unit-testable and
/// the screen just reads the map.
Map<DateTime, List<CalendarEvent>> groupEventsByDay(
  List<CalendarEvent> events,
) {
  final grouped = <DateTime, List<CalendarEvent>>{};
  for (final event in events) {
    grouped.putIfAbsent(dateOnlyOf(event), () => []).add(event);
  }
  for (final list in grouped.values) {
    list.sort((a, b) => eventDateTime(a).compareTo(eventDateTime(b)));
  }
  return grouped;
}

/// The local calendar day an event belongs to, with time-of-day stripped.
DateTime dateOnlyOf(CalendarEvent event) => DateTime(
  event.eventDate.year,
  event.eventDate.month,
  event.eventDate.day,
);
