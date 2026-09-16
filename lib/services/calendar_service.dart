import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/calendar_event.dart';
import '../utils/event_time.dart';

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

/// Firestore-backed calendar data, scoped to users/{uid}/events/{eventId}.
/// Injectable (like [HomeDataService] and [AuthService]) so widget tests can
/// supply canned events for every state without a real Firestore.
///
/// Every method wraps its Firestore call and rethrows a [CalendarFailure]
/// with a readable message, per the NFR that no network call may fail
/// silently or leave a frozen screen.
class CalendarService {
  CalendarService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  // Resolved lazily so constructing a Calendar screen never itself depends
  // on Firebase being initialized — only actually reading/writing does.
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

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
  Future<String> addEvent(String uid, CalendarEvent event) async {
    try {
      final ref = await _events(uid).add(event.toFirestore());
      return ref.id;
    } catch (_) {
      throw CalendarFailure(_saveFailureMessage);
    }
  }

  Future<void> deleteEvent(String uid, String eventId) async {
    try {
      await _events(uid).doc(eventId).delete();
    } catch (_) {
      throw CalendarFailure(_deleteFailureMessage);
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
