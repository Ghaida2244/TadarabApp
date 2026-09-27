import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/course.dart';
import '../models/study_material.dart';
import 'text_extraction_service.dart';

/// A user-facing Courses/Materials failure. [message] is always safe to
/// show directly, per the NFR that every network/API call surfaces a clear,
/// actionable message rather than a raw exception — mirrors [AuthFailure]'s
/// role for the auth screens.
class CoursesFailure implements Exception {
  CoursesFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

const _networkFailureMessage =
    "Couldn't reach Tadarab. Check your connection and try again.";
const _genericFailureMessage = 'Something went wrong. Please try again.';

/// Every Firestore call below is bounded by this, per the NFR that no
/// network call may leave the screen frozen with no way out — without it,
/// a lost connection mid-write leaves the student staring at an infinite
/// spinner with no error and no retry option.
const _networkTimeout = Duration(seconds: 15);

/// The raw file upload to Storage gets a longer budget than plain Firestore
/// reads/writes, since it's an actual multi-MB transfer (up to
/// [kMaxMaterialFileSizeBytes]) rather than a small document.
const _uploadTimeout = Duration(seconds: 60);

/// The 5 preset course-color swatches (courses_material_upload_spec.md §2),
/// lifted from the design handoff's `PALETTE` (its first 5 entries — the
/// same ones the mockup's own "quick palette" surfaces).
const kCoursePresetColors = <String>[
  '#16A34A', // green
  '#2563EB', // blue
  '#F5A524', // amber
  '#E31B23', // red
  '#7C3AED', // purple
];

/// Default per courses_material_upload_spec.md §8: CLAUDE.md's NFR says
/// 10MB, the design mockup's copy says 20MB — this conflict is unresolved
/// and flagged for the team; 10MB is used here and in the upload UI's copy
/// until that's settled, per the spec's explicit instruction.
const kMaxMaterialFileSizeBytes = 10 * 1024 * 1024;

/// The course's initials shown on its icon: always the first two literal
/// characters of the course name (not first-letter-of-each-word), per
/// courses_material_upload_spec.md §2. Handles names shorter than 2
/// characters by using whatever's there.
String courseInitials(String courseName) {
  final trimmed = courseName.trim();
  if (trimmed.isEmpty) return '';
  final length = trimmed.length < 2 ? trimmed.length : 2;
  return trimmed.substring(0, length).toUpperCase();
}

/// Course-name uniqueness is case-sensitive and scoped to the student's own
/// courses ("IS230" and "is230" are different and both allowed).
bool isCourseNameTaken(String name, List<Course> existingCourses) {
  return existingCourses.any((c) => c.courseName == name);
}

/// Material-name uniqueness is case-sensitive and scoped to *this course
/// only* — the same name is fine in a different course.
bool isMaterialNameTaken(String title, List<StudyMaterial> existingInCourse) {
  return existingInCourse.any((m) => m.title == title);
}

/// A preset swatch is locked once another of the student's courses already
/// uses it; [excludingCourseId] lets an edit flow (not used yet — only
/// create exists today) exclude the course being edited from the check.
/// Colors are compared case-insensitively since they're just hex strings.
bool isColorTaken(
  String colorHex,
  List<Course> existingCourses, {
  String? excludingCourseId,
}) {
  final normalized = colorHex.toUpperCase();
  return existingCourses.any(
    (c) => c.courseId != excludingCourseId && c.color.toUpperCase() == normalized,
  );
}

/// A course paired with its materials count, for the courses list row
/// ("N materials") without the screen needing a second round trip per row.
class CourseListItem {
  CourseListItem({required this.course, required this.materialCount});

  final Course course;
  final int materialCount;
}

/// Firestore + Storage backed data and actions for the Courses & Material
/// Upload feature. Injectable (like [AuthService]/[HomeDataService]) so
/// widget tests can supply canned results instead of needing real Firebase.
class CoursesService {
  CoursesService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) : _firestoreOverride = firestore,
       _storageOverride = storage,
       _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseStorage? _storageOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _coursesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('courses');

  CollectionReference<Map<String, dynamic>> _materialsRef(
    String uid,
    String courseId,
  ) => _coursesRef(uid).doc(courseId).collection('materials');

  Future<List<Course>> fetchCourses(String uid) async {
    try {
      final snap = await _coursesRef(uid).get().timeout(_networkTimeout);
      return snap.docs.map(Course.fromFirestore).toList();
    } on FirebaseException {
      throw CoursesFailure(_networkFailureMessage);
    } on TimeoutException {
      throw CoursesFailure(_networkFailureMessage);
    }
  }

  /// Courses with their materials count, for the courses list. Runs one
  /// cheap count-aggregate query per course (no document reads) in
  /// parallel, rather than fetching every material document just to count them.
  Future<List<CourseListItem>> fetchCoursesWithMaterialCounts(
    String uid,
  ) async {
    final courses = await fetchCourses(uid);
    final counts = await Future.wait(
      courses.map((c) => _materialCount(uid, c.courseId)),
    );
    return [
      for (var i = 0; i < courses.length; i++)
        CourseListItem(course: courses[i], materialCount: counts[i]),
    ];
  }

  Future<int> _materialCount(String uid, String courseId) async {
    try {
      final snapshot = await _materialsRef(
        uid,
        courseId,
      ).count().get().timeout(_networkTimeout);
      return snapshot.count ?? 0;
    } on FirebaseException {
      throw CoursesFailure(_networkFailureMessage);
    } on TimeoutException {
      throw CoursesFailure(_networkFailureMessage);
    }
  }

  Future<List<StudyMaterial>> fetchMaterials(String uid, String courseId) async {
    try {
      final snap = await _materialsRef(
        uid,
        courseId,
      ).get().timeout(_networkTimeout);
      return snap.docs.map(StudyMaterial.fromFirestore).toList();
    } on FirebaseException {
      throw CoursesFailure(_networkFailureMessage);
    } on TimeoutException {
      throw CoursesFailure(_networkFailureMessage);
    }
  }

  /// Creates a course. Callers validate name/color uniqueness against their
  /// own already-fetched course list before calling this (the Save button
  /// is disabled until that passes) — this just performs the write.
  Future<Course> createCourse(
    String uid, {
    required String courseName,
    required String color,
  }) async {
    try {
      final docRef = _coursesRef(uid).doc();
      final course = Course(
        courseId: docRef.id,
        courseName: courseName,
        color: color,
        email: _auth.currentUser?.email ?? '',
      );
      await docRef.set(course.toFirestore()).timeout(_networkTimeout);
      return course;
    } on FirebaseException {
      throw CoursesFailure(_networkFailureMessage);
    } on TimeoutException {
      throw CoursesFailure(_networkFailureMessage);
    }
  }

  /// Cascade-deletes a course: its materials (Firestore docs + Storage
  /// files), its calendar events, then the course document itself. Quiz/
  /// flashcard session documents aren't touched yet — those collections
  /// have no way to be created until Phase C's Quiz/Flashcard generation
  /// exists (courses_material_upload_spec.md §3).
  Future<void> deleteCourse(String uid, String courseId) async {
    try {
      final materialsSnap = await _materialsRef(
        uid,
        courseId,
      ).get().timeout(_networkTimeout);
      final eventsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .where('courseId', isEqualTo: courseId)
          .get()
          .timeout(_networkTimeout);

      final batch = _firestore.batch();
      for (final doc in materialsSnap.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in eventsSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_coursesRef(uid).doc(courseId));
      await batch.commit().timeout(_networkTimeout);

      // Best-effort: a Storage cleanup failure shouldn't undo the delete
      // that already succeeded at the data level, or block the user.
      for (final doc in materialsSnap.docs) {
        final material = StudyMaterial.fromFirestore(doc);
        try {
          await _storage.ref(material.document).delete().timeout(
            _networkTimeout,
          );
        } catch (_) {
          // Orphaned file; nothing references it any more from Firestore.
        }
      }
    } on FirebaseException {
      throw CoursesFailure(_networkFailureMessage);
    } on TimeoutException {
      throw CoursesFailure(_networkFailureMessage);
    }
  }

  /// Runs the full upload flow (courses_material_upload_spec.md §4): raw
  /// file to Storage, then client-side text extraction, rejecting (and
  /// cleaning up the uploaded file) if extraction fails or yields no text,
  /// otherwise writing the new [StudyMaterial] document.
  Future<StudyMaterial> uploadMaterial({
    required String uid,
    required String courseId,
    required String title,
    required String type,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final docRef = _materialsRef(uid, courseId).doc();
    final storagePath = 'users/$uid/courses/$courseId/materials/${docRef.id}.$type';
    final ref = _storage.ref(storagePath);

    try {
      final task = ref.putData(bytes);
      if (onProgress != null) {
        task.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes > 0) {
            onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
          }
        });
      }
      await task.timeout(
        _uploadTimeout,
        onTimeout: () {
          task.cancel();
          throw TimeoutException('Upload timed out');
        },
      );
    } on FirebaseException {
      throw CoursesFailure(_networkFailureMessage);
    } on TimeoutException {
      throw CoursesFailure(_networkFailureMessage);
    }

    String extractedText;
    try {
      extractedText = extractText(bytes: bytes, type: type);
    } on TextExtractionException catch (e) {
      await _deleteQuietly(ref);
      throw CoursesFailure(e.message);
    } catch (_) {
      await _deleteQuietly(ref);
      throw CoursesFailure(_genericFailureMessage);
    }

    if (extractedText.trim().isEmpty) {
      await _deleteQuietly(ref);
      throw CoursesFailure('This file has no readable text.');
    }

    final material = StudyMaterial(
      materialId: docRef.id,
      title: title,
      type: type,
      document: storagePath,
      courseId: courseId,
      extractedText: extractedText,
    );
    try {
      await docRef.set(material.toFirestore()).timeout(_networkTimeout);
    } on FirebaseException {
      await _deleteQuietly(ref);
      throw CoursesFailure(_networkFailureMessage);
    } on TimeoutException {
      await _deleteQuietly(ref);
      throw CoursesFailure(_networkFailureMessage);
    }
    return material;
  }

  /// Deletes a single material — its Firestore doc, then (best-effort) its
  /// Storage file. Leaves the course, every other material, and any quiz/
  /// flashcard sessions generated from it untouched.
  Future<void> deleteMaterial(
    String uid,
    String courseId,
    StudyMaterial material,
  ) async {
    try {
      await _materialsRef(uid, courseId)
          .doc(material.materialId)
          .delete()
          .timeout(_networkTimeout);
    } on FirebaseException {
      throw CoursesFailure(_networkFailureMessage);
    } on TimeoutException {
      throw CoursesFailure(_networkFailureMessage);
    }
    // Best-effort, same as deleteCourse's per-material cleanup: the
    // Firestore doc is already gone, so a failure here just orphans a
    // file rather than leaving anything user-visible broken.
    await _deleteQuietly(_storage.ref(material.document));
  }

  Future<void> _deleteQuietly(Reference ref) async {
    try {
      await ref.delete().timeout(_networkTimeout);
    } catch (_) {
      // Best-effort cleanup of a rejected upload; not user-visible either way.
    }
  }
}
