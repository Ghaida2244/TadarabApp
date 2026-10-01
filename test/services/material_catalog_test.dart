import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/material_catalog.dart';

void main() {
  const catalog = StubMaterialCatalog();

  group('fetchMaterials', () {
    test('normal case: returns a non-empty, course-scoped materials list', () async {
      final materials = await catalog.fetchMaterials('course-1');

      expect(materials, isNotEmpty);
      for (final m in materials) {
        expect(m.courseId, 'course-1');
        expect(m.materialId, startsWith('course-1-'));
      }
    });

    test('edge case: two different courses get distinctly-ided materials', () async {
      final a = await catalog.fetchMaterials('course-a');
      final b = await catalog.fetchMaterials('course-b');

      final aIds = a.map((m) => m.materialId).toSet();
      final bIds = b.map((m) => m.materialId).toSet();
      expect(aIds.intersection(bIds), isEmpty);
    });
  });

  group('sourceTextFor', () {
    test('normal case: every fetched material resolves non-empty source text', () async {
      final materials = await catalog.fetchMaterials('course-1');
      for (final m in materials) {
        final text = await catalog.sourceTextFor(m);
        expect(text, isNotEmpty);
        expect(text, contains('['));
      }
    });

    test('failure case: an unrecognized material still returns text, not an error', () async {
      final unknown = StudyMaterial(
        materialId: 'course-1-not-from-this-catalog',
        title: 'Unknown',
        type: 'txt',
        document: '',
        courseId: 'course-1',
        extractedText: '',
      );
      final text = await catalog.sourceTextFor(unknown);
      expect(text, isNotEmpty);
    });
  });

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
