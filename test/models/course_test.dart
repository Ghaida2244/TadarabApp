import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/utils/default_colors.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Future<Course> seedAndRead(Map<String, dynamic> data) async {
    final ref = await firestore.collection('courses').add(data);
    final doc = await ref.get();
    return Course.fromFirestore(doc);
  }

  group('fromFirestore color fallback', () {
    test('a missing color field falls back to kDefaultCourseColor', () async {
      final course = await seedAndRead({
        'courseName': 'IS230',
        'email': 'student@example.com',
      });
      expect(course.color, kDefaultCourseColor);
    });

    test('an empty color field falls back to kDefaultCourseColor', () async {
      final course = await seedAndRead({
        'courseName': 'IS230',
        'email': 'student@example.com',
        'color': '',
      });
      expect(course.color, kDefaultCourseColor);
    });

    test('a real stored color is read through unchanged', () async {
      final course = await seedAndRead({
        'courseName': 'IS230',
        'email': 'student@example.com',
        'color': '#2563EB',
      });
      expect(course.color, '#2563EB');
    });
  });

  test('the constructor default is also kDefaultCourseColor', () {
    final course = Course(
      courseId: 'c1',
      courseName: 'IS230',
      email: 'student@example.com',
    );
    expect(course.color, kDefaultCourseColor);
  });
}
