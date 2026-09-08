import 'package:cloud_firestore/cloud_firestore.dart';

/// An uploaded lecture file (PPTX/DOCX/TXT) tied to a course.
/// Stored at users/{uid}/courses/{courseId}/materials/{materialId}.
///
/// The Attributes Dictionary Table types `document` as a BLOB, but the file
/// itself lives in Firebase Storage (see CLAUDE.md Storage section) — this
/// field holds the Storage path/download URL, not the raw file bytes.
class StudyMaterial {
  StudyMaterial({
    required this.materialId,
    required this.title,
    required this.type,
    required this.document,
    required this.courseId,
  });

  /// Firestore document ID.
  final String materialId;

  /// Display title of the material.
  final String title;

  /// File type, e.g. "pptx", "docx", "txt".
  final String type;

  /// Firebase Storage path (or download URL) of the uploaded file.
  final String document;

  /// Owning course's ID (foreign key to Course).
  final String courseId;

  factory StudyMaterial.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return StudyMaterial(
      materialId: doc.id,
      title: data['title'] as String,
      type: data['type'] as String,
      document: data['document'] as String,
      courseId: data['courseId'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'type': type,
      'document': document,
      'courseId': courseId,
    };
  }
}
