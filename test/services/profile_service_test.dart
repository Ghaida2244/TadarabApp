import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tadarab_app/services/profile_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProfileService service;

  DocumentReference<Map<String, dynamic>> studentDoc(String uid) =>
      firestore.collection('users').doc(uid);

  Future<void> seed(String uid) async {
    await studentDoc(uid).set({
      'email': 'student@example.com',
      'name': 'Leen',
      'totalPoints': 0,
      'currentRank': 'Beginner Learner',
      'reminderEnabled': false,
      'reminderTime': null,
    });
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    service = ProfileService(firestore: firestore);
    await seed('u1');
  });

  group('updateName', () {
    test('writes only the name field', () async {
      await service.updateName('u1', 'Leen Alhumaid');

      final data = (await studentDoc('u1').get()).data()!;
      expect(data['name'], 'Leen Alhumaid');
      // Nothing else is disturbed by the narrow update.
      expect(data['totalPoints'], 0);
      expect(data['email'], 'student@example.com');
      expect(data['currentRank'], 'Beginner Learner');
    });

    test('trims surrounding whitespace', () async {
      await service.updateName('u1', '   Leen   ');

      expect((await studentDoc('u1').get()).data()!['name'], 'Leen');
    });

    test('never touches another student\'s document', () async {
      await seed('u2');
      await service.updateName('u1', 'Changed');

      expect((await studentDoc('u2').get()).data()!['name'], 'Leen');
    });

    test('wraps a failure in a readable ProfileFailure', () async {
      whenCalling(
        Invocation.method(#update, null),
      ).on(studentDoc('u1')).thenThrow(
        FirebaseException(plugin: 'cloud_firestore'),
      );

      expect(
        () => service.updateName('u1', 'Leen'),
        throwsA(isA<ProfileFailure>()),
      );
    });
  });

  group('updateStudyReminder', () {
    test('stores an enabled reminder as "HH:mm"', () async {
      await service.updateStudyReminder(
        'u1',
        enabled: true,
        time: const TimeOfDay(hour: 16, minute: 0),
      );

      final data = (await studentDoc('u1').get()).data()!;
      expect(data['reminderEnabled'], isTrue);
      expect(data['reminderTime'], '16:00');
    });

    test('zero-pads a morning time', () async {
      await service.updateStudyReminder(
        'u1',
        enabled: true,
        time: const TimeOfDay(hour: 7, minute: 5),
      );

      expect((await studentDoc('u1').get()).data()!['reminderTime'], '07:05');
    });

    test('turning it off clears the time as well as the flag', () async {
      await service.updateStudyReminder(
        'u1',
        enabled: true,
        time: const TimeOfDay(hour: 16, minute: 0),
      );
      await service.updateStudyReminder('u1', enabled: false, time: null);

      final data = (await studentDoc('u1').get()).data()!;
      expect(data['reminderEnabled'], isFalse);
      // The same shape as an account that never set one.
      expect(data['reminderTime'], isNull);
    });

    test('an enabled reminder with no time stores no time', () async {
      // Shouldn't be reachable through the UI, but must not store a
      // half-state if it ever is.
      await service.updateStudyReminder('u1', enabled: true, time: null);

      final data = (await studentDoc('u1').get()).data()!;
      expect(data['reminderTime'], isNull);
    });

    test('wraps a failure in a readable ProfileFailure', () async {
      whenCalling(
        Invocation.method(#update, null),
      ).on(studentDoc('u1')).thenThrow(
        FirebaseException(plugin: 'cloud_firestore'),
      );

      expect(
        () => service.updateStudyReminder('u1', enabled: false, time: null),
        throwsA(isA<ProfileFailure>()),
      );
    });
  });
}
