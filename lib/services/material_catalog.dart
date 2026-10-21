import 'package:firebase_auth/firebase_auth.dart';

import '../models/study_material.dart';
import 'courses_service.dart';

/// Where Quiz Setup gets its list of materials for a course, and the text
/// sent to the generation Worker for each one.
///
/// [CoursesMaterialCatalog] is the only implementation — the running app's
/// default, now that the Courses & Material upload feature (Manar,
/// `feature/courses`) is merged and `StudyMaterial` carries real extracted
/// text. [QuizSessionService] (see quiz_session_service.dart) only depends
/// on this interface, so a future test double can be added without
/// changing anything else about it.
abstract class MaterialCatalog {
  /// The materials available to pick from for [courseId].
  Future<List<StudyMaterial>> fetchMaterials(String courseId);

  /// The text sent to the generation Worker for [material].
  Future<String> sourceTextFor(StudyMaterial material);
}

/// The real [MaterialCatalog]: the signed-in student's own courses and
/// materials, via [CoursesService] — the same Firestore-backed data
/// Manar's Courses & Material upload feature reads and writes. Every
/// [StudyMaterial] it returns already carries real `extractedText` (see
/// courses_material_upload_spec.md §7), so [sourceTextFor] just reads that
/// field back rather than looking anything up separately.
class CoursesMaterialCatalog implements MaterialCatalog {
  CoursesMaterialCatalog({CoursesService? coursesService, FirebaseAuth? auth})
    : _coursesService = coursesService ?? CoursesService(),
      _authOverride = auth;

  final CoursesService _coursesService;
  final FirebaseAuth? _authOverride;

  // A getter, not resolved in the initializer list — mirrors
  // QuizSessionService/CoursesService's own lazy pattern, so merely
  // constructing this (e.g. as QuizSessionService's default) never touches
  // FirebaseAuth.instance before it's actually needed.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  @override
  Future<List<StudyMaterial>> fetchMaterials(String courseId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const [];
    return _coursesService.fetchMaterials(uid, courseId);
  }

  @override
  Future<String> sourceTextFor(StudyMaterial material) async =>
      material.extractedText;
}
