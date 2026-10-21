import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/courses_service.dart';

Course _course({
  required String id,
  required String name,
  String color = '#16A34A',
}) => Course(
  courseId: id,
  courseName: name,
  color: color,
  email: 'student@example.com',
);

StudyMaterial _material({required String id, required String title}) =>
    StudyMaterial(
      materialId: id,
      title: title,
      type: 'txt',
      document: 'users/u/courses/c/materials/$id.txt',
      courseId: 'c',
      extractedText: '[Paragraph 1]\nSome text.',
    );

void main() {
  group('courseInitials', () {
    test('normal case: takes the first two literal characters', () {
      expect(courseInitials('IS230'), 'IS');
    });

    test('literal characters, not first letter of each word', () {
      expect(courseInitials('Data Structures'), 'DA');
    });

    test('edge case: a single-character name uses just that character', () {
      expect(courseInitials('X'), 'X');
    });

    test('failure-ish case: an empty/whitespace-only name yields no initials', () {
      expect(courseInitials(''), '');
      expect(courseInitials('   '), '');
    });
  });

  group('isCourseNameTaken', () {
    final existing = [_course(id: '1', name: 'IS230')];

    test('normal case: an exact duplicate name is taken', () {
      expect(isCourseNameTaken('IS230', existing), isTrue);
    });

    test('edge case: comparison is case-sensitive, so different casing is allowed', () {
      expect(isCourseNameTaken('is230', existing), isFalse);
    });

    test('failure-ish case: an empty course list never has a taken name', () {
      expect(isCourseNameTaken('IS230', const []), isFalse);
    });
  });

  group('isMaterialNameTaken', () {
    final inCourseA = [_material(id: 'm1', title: 'Lecture 1')];

    test('normal case: a duplicate title within the same course is taken', () {
      expect(isMaterialNameTaken('Lecture 1', inCourseA), isTrue);
    });

    test('edge case: comparison is case-sensitive', () {
      expect(isMaterialNameTaken('lecture 1', inCourseA), isFalse);
    });

    test(
      'failure-ish case: the same title is fine when scoped to a different '
      "course's (empty) material list",
      () {
        expect(isMaterialNameTaken('Lecture 1', const []), isFalse);
      },
    );
  });

  group('isColorTaken', () {
    final existing = [_course(id: '1', name: 'IS230', color: '#16A34A')];

    test('normal case: a color already used by another course is taken', () {
      expect(isColorTaken('#16A34A', existing), isTrue);
    });

    test('edge case: comparison is case-insensitive on the hex string', () {
      expect(isColorTaken('#16a34a', existing), isTrue);
    });

    test(
      'a color frees up immediately once its course is no longer in the list '
      '(i.e. after deletion)',
      () {
        expect(isColorTaken('#16A34A', const []), isFalse);
      },
    );

    test('excludingCourseId lets a course ignore its own current color', () {
      expect(
        isColorTaken('#16A34A', existing, excludingCourseId: '1'),
        isFalse,
      );
    });
  });
}
