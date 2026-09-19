import 'dart:async';

import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/services/calendar_service.dart';

/// A controllable stand-in for [CalendarService], so the Calendar widget
/// tests never touch a real Firestore. Configure [events] for what the
/// month stream emits, or [loadError]/[deleteError] to drive the failure
/// states.
class FakeCalendarService extends CalendarService {
  FakeCalendarService({
    this.events = const [],
    this.loadError,
    this.deleteError,
    this.addError,
    this.nextEventId = 'new-event-id',
  });

  /// Emitted by [watchEventsForMonth] regardless of which month is asked
  /// for — tests set up exactly the events they want visible.
  final List<CalendarEvent> events;

  final CalendarFailure? loadError;
  final CalendarFailure? deleteError;
  final CalendarFailure? addError;
  /// The ID handed out by [newEventId] and [addEvent].
  final String nextEventId;

  final List<String> deletedEventIds = [];
  final List<CalendarEvent> addedEvents = [];
  final List<DateTime> watchedMonths = [];

  @override
  Stream<List<CalendarEvent>> watchEventsForMonth(String uid, DateTime month) {
    watchedMonths.add(month);
    if (loadError != null) return Stream.error(loadError!);
    return Stream.value(events);
  }

  @override
  String newEventId(String uid) => nextEventId;

  @override
  Future<String> addEvent(String uid, CalendarEvent event) async {
    addedEvents.add(event);
    if (addError != null) throw addError!;
    return event.eventId.isNotEmpty ? event.eventId : nextEventId;
  }

  @override
  Future<void> deleteEvent(String uid, String eventId) async {
    if (deleteError != null) throw deleteError!;
    deletedEventIds.add(eventId);
  }
}
