import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/calendar_event.dart';
import 'package:tadarab_app/utils/default_colors.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Map<String, dynamic> baseData() => {
    'eventName': 'Midterm',
    'eventDate': Timestamp.fromDate(DateTime(2026, 5, 14)),
    'eventTime': '23:59',
    'email': 'student@example.com',
  };

  Future<CalendarEvent> seedAndRead(Map<String, dynamic> data) async {
    final ref = await firestore.collection('events').add(data);
    final doc = await ref.get();
    return CalendarEvent.fromFirestore(doc);
  }

  group('fromFirestore color fallback', () {
    test('a missing color field falls back to kDefaultCourseColor', () async {
      final event = await seedAndRead(baseData());
      expect(event.color, kDefaultCourseColor);
    });

    test('an empty color field falls back to kDefaultCourseColor', () async {
      final event = await seedAndRead({...baseData(), 'color': ''});
      expect(event.color, kDefaultCourseColor);
    });

    test('a real stored color is read through unchanged', () async {
      final event = await seedAndRead({...baseData(), 'color': '#7C3AED'});
      expect(event.color, '#7C3AED');
    });
  });

  test('the constructor default is also kDefaultCourseColor', () {
    final event = CalendarEvent(
      eventId: 'e1',
      eventName: 'Midterm',
      eventDate: DateTime(2026, 5, 14),
      eventTime: '23:59',
      email: 'student@example.com',
    );
    expect(event.color, kDefaultCourseColor);
  });
}
