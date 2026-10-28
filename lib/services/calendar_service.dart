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
const _loadRecentColorsFailureMessage =
    "Couldn't load your recent colors. Check your connection and try again.";
const _loadSavedColorsFailureMessage =
    "Couldn't load your saved colors. Check your connection and try again.";

/// Firestore caps a single batched write at 500 operations.
const _maxBatchSize = 500;

/// The field on `users/{uid}` holding Add Event's saved quick-colour list.
const _savedEventColorsField = 'savedEventColors';

/// The most quick-colours Add Event ever saves for one student.
const _kMaxSavedEventColors = 5;

/// Hard cap on how many raw event documents
/// [CalendarService.standaloneEventColorsMostRecentFirst] ever reads.
/// `courseId == null` can't be pushed into the query itself without a new
/// composite index (an equality filter on `courseId` plus the `eventDate`
/// order-by is exactly the two-different-fields shape that needed Home's
/// composite indexes in Phase B) — so that filtering happens in Dart after
/// a plain, single-field-ordered fetch, and this cap bounds how much that
/// fetch ever reads. A student with more than 200 events is an accepted,
/// extreme edge case where the recent-colours list may miss a handful of
/// her most recent standalone events.
const _kStandaloneColorFetchCap = 200;

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

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

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

  /// Every event whose date falls inside [year], soonest first.
  ///
  /// Backs the year view, which fills each date with its first event's
  /// colour and so needs all twelve months at once. Exactly the same
  /// single-field range + order-by shape as [watchEventsForMonth], so it
  /// also needs no composite index.
  Stream<List<CalendarEvent>> watchEventsForYear(String uid, int year) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    return _events(uid)
        .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('eventDate', isLessThan: Timestamp.fromDate(end))
        .orderBy('eventDate')
        .snapshots()
        .map((snap) => snap.docs.map(CalendarEvent.fromFirestore).toList())
        .handleError((Object _) => throw CalendarFailure(_loadFailureMessage));
  }

  /// Reserves a document ID for a new event without writing anything.
  ///
  /// Firestore generates this locally, so it needs no network call. The Add
  /// Event screen uses it to schedule the reminder *before* the event is
  /// written, so the single write can record whether the reminder was
  /// actually set rather than what the student asked for.
  String newEventId(String uid) => _events(uid).doc().id;

  /// Creates an event and returns its document ID.
  ///
  /// Writes to [CalendarEvent.eventId] when it's set (an ID reserved with
  /// [newEventId]); otherwise Firestore assigns one.
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
      if (event.eventId.isNotEmpty) {
        await _events(uid).doc(event.eventId).set(data);
        return event.eventId;
      }
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

  /// The student's own recent colours, for Add Event's colour row: distinct
  /// colours of her events that are *not* linked to a course, most recently
  /// used first, capped at [limit].
  ///
  /// Ordered by `eventDate` descending rather than a creation timestamp —
  /// [CalendarEvent] has no `createdAt` field (adding one is a model change
  /// needing full-team review, and wasn't asked for here), so the event's
  /// own date is the closest available stand-in for "recently used".
  ///
  /// `courseId == null` is filtered in Dart, not in the query, to avoid
  /// needing a new composite index (see [_kStandaloneColorFetchCap]) — so
  /// this reads at most that many documents, then keeps going through them
  /// in order until [limit] distinct standalone colours are found.
  Future<List<String>> standaloneEventColorsMostRecentFirst(
    String uid, {
    int limit = 5,
  }) async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
    try {
      final snap = await _events(uid)
          .orderBy('eventDate', descending: true)
          .limit(_kStandaloneColorFetchCap)
          .get();
      docs = snap.docs;
    } catch (_) {
      throw CalendarFailure(_loadRecentColorsFailureMessage);
    }

    final colors = <String>[];
    final seen = <String>{};
    for (final doc in docs) {
      final event = CalendarEvent.fromFirestore(doc);
      if (event.courseId != null) continue;
      if (seen.add(event.color.toUpperCase())) colors.add(event.color);
      if (colors.length >= limit) break;
    }
    return colors;
  }

  List<String> _savedColorsFrom(Map<String, dynamic>? data) {
    final raw = data?[_savedEventColorsField];
    if (raw is List) return raw.whereType<String>().toList();
    return [];
  }

  /// Loads the student's saved quick-colours for Add Event's colour row:
  /// upper-case "#RRGGBB" strings on `users/{uid}`, newest first, at most
  /// [_kMaxSavedEventColors].
  ///
  /// If the field has never been written for this account, it's seeded
  /// (best effort — the seed is still returned even if the write below
  /// fails) from her standalone events via
  /// [standaloneEventColorsMostRecentFirst], so a student with existing
  /// colour history isn't started from scratch. Once the field exists —
  /// even as an empty list, e.g. after removing every saved colour — it's
  /// never reseeded.
  Future<List<String>> loadSavedEventColors(String uid) async {
    Map<String, dynamic>? data;
    try {
      final snap = await _userDoc(uid).get();
      data = snap.data();
    } catch (_) {
      throw CalendarFailure(_loadSavedColorsFailureMessage);
    }

    if (data != null && data.containsKey(_savedEventColorsField)) {
      return _savedColorsFrom(data);
    }

    final seeded = await standaloneEventColorsMostRecentFirst(
      uid,
      limit: _kMaxSavedEventColors,
    );
    try {
      await _userDoc(
        uid,
      ).set({_savedEventColorsField: seeded}, SetOptions(merge: true));
    } catch (_) {
      // Best effort — the seed is still handed back even if it couldn't be
      // persisted; the next load simply seeds again.
    }
    return seeded;
  }

  /// Moves [colorHex] to the front of the student's saved event-colour
  /// list, or adds it there if the list has room (fewer than
  /// [_kMaxSavedEventColors]). If the list is already full and doesn't
  /// already contain the colour, it's simply not added — the event that
  /// triggered this call is saved regardless; only this list declines the
  /// new entry.
  ///
  /// Runs inside a transaction, so two overlapping saves can't read-modify-
  /// write the list and silently lose one update. Best effort: a failure
  /// here never fails the event save that triggered it.
  Future<void> recordStandaloneEventColor(String uid, String colorHex) async {
    try {
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(_userDoc(uid));
        final current = _savedColorsFrom(snap.data());
        final upper = colorHex.toUpperCase();
        final withoutIt = current
            .where((c) => c.toUpperCase() != upper)
            .toList();
        final wasPresent = withoutIt.length != current.length;
        if (!wasPresent && current.length >= _kMaxSavedEventColors) {
          return;
        }
        txn.set(_userDoc(uid), {
          _savedEventColorsField: [colorHex, ...withoutIt],
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // Best effort, per the doc comment above.
    }
  }

  /// Removes [colorHex] from the student's saved event-colour list, run
  /// inside a transaction for the same read-modify-write safety as
  /// [recordStandaloneEventColor]. Best effort — the Add Event screen
  /// updates its own row immediately regardless of whether this succeeds.
  /// Never touches any event.
  Future<void> removeSavedEventColor(String uid, String colorHex) async {
    final upper = colorHex.toUpperCase();
    try {
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(_userDoc(uid));
        final current = _savedColorsFrom(snap.data());
        final updated = current.where((c) => c.toUpperCase() != upper).toList();
        if (updated.length == current.length) return;
        txn.set(_userDoc(uid), {
          _savedEventColorsField: updated,
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // Best effort, per the doc comment above.
    }
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
