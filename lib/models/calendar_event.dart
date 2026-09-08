import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// A calendar entry, optionally linked to a course, with an optional reminder.
/// Stored at users/{uid}/events/{eventId}.
class CalendarEvent {
  CalendarEvent({
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.eventTime,
    this.reminderEnabled = false,
    this.reminderBefore,
    this.reminderUnit,
    this.color = '#10B981',
    required this.email,
    this.courseId,
  });

  /// Firestore document ID.
  final String eventId;

  /// Display name of the event.
  final String eventName;

  /// Calendar date of the event (time-of-day is stored separately in [eventTime]).
  final DateTime eventDate;

  /// Time of day of the event, as "HH:mm".
  final String eventTime;

  /// Whether a reminder notification is enabled for this event.
  final bool reminderEnabled;

  /// How long before the event the reminder should fire, in [reminderUnit] units.
  final int? reminderBefore;

  /// Unit for [reminderBefore] (Minutes/Hours/Days/Weeks).
  final ReminderUnit? reminderUnit;

  /// Hex color used to display this event on the calendar.
  final String color;

  /// Owning student's email (foreign key to Student).
  final String email;

  /// Linked course's ID, if any (foreign key to Course; nullable).
  final String? courseId;

  factory CalendarEvent.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final reminderUnitValue = data['reminderUnit'] as String?;
    return CalendarEvent(
      eventId: doc.id,
      eventName: data['eventName'] as String,
      eventDate: (data['eventDate'] as Timestamp).toDate(),
      eventTime: data['eventTime'] as String,
      reminderEnabled: data['reminderEnabled'] as bool? ?? false,
      reminderBefore: (data['reminderBefore'] as num?)?.toInt(),
      reminderUnit: reminderUnitValue == null
          ? null
          : ReminderUnitJson.fromJson(reminderUnitValue),
      color: data['color'] as String? ?? '#10B981',
      email: data['email'] as String,
      courseId: data['courseId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventName': eventName,
      'eventDate': Timestamp.fromDate(eventDate),
      'eventTime': eventTime,
      'reminderEnabled': reminderEnabled,
      'reminderBefore': reminderBefore,
      'reminderUnit': reminderUnit?.toJson(),
      'color': color,
      'email': email,
      'courseId': courseId,
    };
  }
}
