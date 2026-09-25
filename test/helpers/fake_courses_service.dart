import 'dart:async';
import 'dart:typed_data';

import 'package:tadarab_app/models/course.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/courses_service.dart';

/// A controllable stand-in for [CoursesService] used across the Courses
/// feature's widget tests, so they never depend on real Firebase — mirrors
/// FakeHomeDataService's role for the Home screen tests.
class FakeCoursesService extends CoursesService {
  FakeCoursesService({
    List<Course>? courses,
    this.materialsByCourse = const {},
    this.createCourseResult,
    this.createCourseError,
    this.deleteCourseError,
    this.deleteMaterialError,
    this.uploadMaterialResult,
    this.uploadMaterialError,
    this.uploadGate,
  }) : courses = courses ?? [];

  /// Mutable so a test can simulate "a course was created elsewhere" by
  /// updating this between reloads, rather than being stuck with whatever
  /// was passed to the constructor for the fake's whole lifetime.
  List<Course> courses;
  final Map<String, List<StudyMaterial>> materialsByCourse;
  final Course? createCourseResult;
  final CoursesFailure? createCourseError;
  final CoursesFailure? deleteCourseError;
  final CoursesFailure? deleteMaterialError;
  final StudyMaterial? uploadMaterialResult;
  final CoursesFailure? uploadMaterialError;

  /// When set, [uploadMaterial] waits on this before resolving/throwing —
  /// lets a test observe the "uploading" state before it completes.
  final Completer<void>? uploadGate;

  int createCourseCalls = 0;
  int deleteCourseCalls = 0;
  int deleteMaterialCalls = 0;
  int uploadMaterialCalls = 0;
  int fetchCoursesWithMaterialCountsCalls = 0;

  @override
  Future<List<Course>> fetchCourses(String uid) async => courses;

  @override
  Future<List<CourseListItem>> fetchCoursesWithMaterialCounts(
    String uid,
  ) async {
    fetchCoursesWithMaterialCountsCalls++;
    return [
      for (final c in courses)
        CourseListItem(
          course: c,
          materialCount: (materialsByCourse[c.courseId] ?? const []).length,
        ),
    ];
  }

  @override
  Future<List<StudyMaterial>> fetchMaterials(
    String uid,
    String courseId,
  ) async => materialsByCourse[courseId] ?? const [];

  @override
  Future<Course> createCourse(
    String uid, {
    required String courseName,
    required String color,
  }) async {
    createCourseCalls++;
    if (createCourseError != null) throw createCourseError!;
    final result =
        createCourseResult ??
        Course(
          courseId: 'new-course',
          courseName: courseName,
          color: color,
          email: 'student@example.com',
        );
    // Mirrors the real service: once created, it's part of what a
    // subsequent fetch returns. Mutated in place (not reassigned) so a
    // `courses` list shared with another fake (e.g. FakeHomeDataService, to
    // test both screens staying in sync) sees the addition too.
    courses.add(result);
    return result;
  }

  @override
  Future<void> deleteCourse(String uid, String courseId) async {
    deleteCourseCalls++;
    if (deleteCourseError != null) throw deleteCourseError!;
  }

  @override
  Future<void> deleteMaterial(
    String uid,
    String courseId,
    StudyMaterial material,
  ) async {
    deleteMaterialCalls++;
    if (deleteMaterialError != null) throw deleteMaterialError!;
    // Mutates in place, like `createCourse` above, so a test's own
    // `materialsByCourse[courseId]` list reflects the removal immediately.
    materialsByCourse[courseId]?.removeWhere(
      (m) => m.materialId == material.materialId,
    );
  }

  @override
  Future<StudyMaterial> uploadMaterial({
    required String uid,
    required String courseId,
    required String title,
    required String type,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    uploadMaterialCalls++;
    if (uploadGate != null) await uploadGate!.future;
    if (uploadMaterialError != null) throw uploadMaterialError!;
    onProgress?.call(1);
    return uploadMaterialResult ??
        StudyMaterial(
          materialId: 'new-material',
          title: title,
          type: type,
          document: 'users/$uid/courses/$courseId/materials/new-material.$type',
          courseId: courseId,
          extractedText: '[Paragraph 1]\nSome text.',
        );
  }
}
