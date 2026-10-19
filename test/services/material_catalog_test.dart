import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/material_catalog.dart';

void main() {
  group('CoursesMaterialCatalog.sourceTextFor', () {
    // fetchMaterials isn't covered here: it resolves the signed-in
    // student's uid via FirebaseAuth.instance, and this codebase has no
    // FirebaseAuth test double (CoursesService/QuizSessionService's own
    // Firebase-touching methods are exercised the same way — through their
    // Fake* subclasses at the screen level, not unit-tested directly).
    final catalog = CoursesMaterialCatalog();

    test(
      'normal case: reads the material\'s own extractedText, no lookup',
      () async {
        final material = StudyMaterial(
          materialId: 'm1',
          title: 'Lecture 1',
          type: 'pptx',
          document: 'users/u/courses/c/materials/m1.pptx',
          courseId: 'c1',
          extractedText: '[Slide 1]\nReal extracted content.',
        );

        expect(
          await catalog.sourceTextFor(material),
          '[Slide 1]\nReal extracted content.',
        );
      },
    );

    test('edge case: empty extractedText is returned as-is, not padded', () async {
      final material = StudyMaterial(
        materialId: 'm2',
        title: 'Empty',
        type: 'txt',
        document: 'users/u/courses/c/materials/m2.txt',
        courseId: 'c1',
        extractedText: '',
      );

      expect(await catalog.sourceTextFor(material), '');
    });
  });
}
