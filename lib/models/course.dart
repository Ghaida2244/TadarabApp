import 'package:cloud_firestore/cloud_firestore.dart';

/// A course a student organizes their study materials under.
/// Stored at users/{uid}/courses/{courseId}.
class Course {
  Course({
    required this.courseId,
    required this.courseName,
    this.color = '#10B981',
    required this.email,
  });

  /// Firestore document ID.
  final String courseId;

  /// Display name of the course.
  final String courseName;

  /// Hex color used to tag this course throughout the UI (courses, calendar events).
  final String color;

  /// Owning student's email (foreign key to Student).
  final String email;

  factory Course.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Course(
      courseId: doc.id,
      courseName: data['courseName'] as String,
      color: data['color'] as String? ?? '#10B981',
      email: data['email'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'courseName': courseName, 'color': color, 'email': email};
  }
}
