import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tadarab_app/models/study_material.dart';

// StudyMaterial.fromFirestore itself isn't exercised here — it needs a
// real DocumentSnapshot, and this project has no Firestore-mocking
// package (none of CoursesService's other Firestore-touching methods are
// unit-tested directly either; they're exercised through FakeCoursesService
// in widget tests instead). toFirestore() is pure, though — exactly the
// half of the round-trip this file can cover directly.
StudyMaterial _material({DateTime? createdAt}) => StudyMaterial(
  materialId: 'm1',
  title: 'Lecture 1',
  type: 'pptx',
  document: 'users/u/courses/c1/materials/m1.pptx',
  courseId: 'c1',
  extractedText: '[Slide 1]\nSome text.',
  createdAt: createdAt,
);

void main() {
  group('toFirestore', () {
    test('normal: a known createdAt is written as a Timestamp', () {
      final createdAt = DateTime(2026, 3, 1, 12, 30);
      final map = _material(createdAt: createdAt).toFirestore();

      expect(map['createdAt'], Timestamp.fromDate(createdAt));
      expect(map['title'], 'Lecture 1');
      expect(map['type'], 'pptx');
      expect(map['document'], 'users/u/courses/c1/materials/m1.pptx');
      expect(map['courseId'], 'c1');
      expect(map['extractedText'], '[Slide 1]\nSome text.');
    });

    test(
      'edge: a null createdAt (an old document, or one not set yet) omits '
      'the key entirely rather than writing a null — tolerating a missing '
      'value is the model\'s own job on read (see StudyMaterial.fromFirestore)',
      () {
        final map = _material(createdAt: null).toFirestore();
        expect(map.containsKey('createdAt'), isFalse);
      },
    );
  });
}
