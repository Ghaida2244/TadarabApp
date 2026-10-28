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
    this.recentColors = const [],
    this.recentColorsError,
    this.savedColors = const [],
    this.savedColorsError,
  });

  /// Emitted by [watchEventsForMonth] regardless of which month is asked
  /// for — tests set up exactly the events they want visible.
  final List<CalendarEvent> events;

  final CalendarFailure? loadError;
  final CalendarFailure? deleteError;
  final CalendarFailure? addError;
  /// The ID handed out by [newEventId] and [addEvent].
  final String nextEventId;

  /// Returned by [standaloneEventColorsMostRecentFirst], already in the
  /// order a test wants — this fake doesn't re-derive it from [events].
  final List<String> recentColors;
  final CalendarFailure? recentColorsError;

  /// Returned by [loadSavedEventColors] — this fake doesn't model the
  /// missing-field seeding, since that's [CalendarService]'s own real
  /// logic, covered separately by `calendar_service_test.dart` against a
  /// fake Firestore.
  final List<String> savedColors;
  final CalendarFailure? savedColorsError;

  /// Every colour [recordStandaloneEventColor] was called with, in call
  /// order.
  final List<String> recordedColors = [];

  /// Every colour [removeSavedEventColor] was called with, in call order.
  final List<String> removedColors = [];

  final List<String> deletedEventIds = [];
  final List<CalendarEvent> addedEvents = [];
  final List<DateTime> watchedMonths = [];

  final List<int> watchedYears = [];

  @override
  Stream<List<CalendarEvent>> watchEventsForMonth(String uid, DateTime month) {
    watchedMonths.add(month);
    if (loadError != null) return Stream.error(loadError!);
    return Stream.value(events);
  }

  @override
  Stream<List<CalendarEvent>> watchEventsForYear(String uid, int year) {
    watchedYears.add(year);
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

  @override
  Future<List<String>> standaloneEventColorsMostRecentFirst(
    String uid, {
    int limit = 5,
    int? fetchCap,
  }) async {
    if (recentColorsError != null) throw recentColorsError!;
    return recentColors.take(limit).toList();
  }

  @override
  Future<List<String>> loadSavedEventColors(String uid) async {
    if (savedColorsError != null) throw savedColorsError!;
    return savedColors;
  }

  @override
  Future<void> recordStandaloneEventColor(String uid, String colorHex) async {
    recordedColors.add(colorHex);
  }

  @override
  Future<void> removeSavedEventColor(String uid, String colorHex) async {
    removedColors.add(colorHex);
  }
}
