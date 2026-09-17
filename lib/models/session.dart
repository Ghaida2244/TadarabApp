import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// Shared fields for a study session (quiz or flashcard). Not a Firestore
/// collection of its own — QuizSession and FlashcardSession each store these
/// fields directly on their own documents (users/{uid}/quizSessions/... and
/// users/{uid}/flashcardSessions/...), per the Firestore schema in CLAUDE.md.
///
/// SessionMaterial (session-to-material) is likewise not a separate
/// collection: [materialIds] holds that relationship as a plain list.
abstract class Session {
  Session({
    required this.sessionId,
    required this.createdAt,
    this.completedAt,
    this.earnedPoints = 0,
    this.isSessionCompleted = false,
    required this.difficultyLevels,
    this.customPrompt,
    required this.email,
    required this.courseId,
    required this.materialIds,
  }) : assert(
         difficultyLevels.length > 0,
         'A session must request at least one difficulty level',
       );

  /// Firestore document ID.
  final String sessionId;

  /// When the session was created.
  final DateTime createdAt;

  /// When the session was completed; null while still in progress.
  final DateTime? completedAt;

  /// Points earned in this session.
  final int earnedPoints;

  /// Whether the session has been completed.
  final bool isSessionCompleted;

  /// Difficulty level(s) requested for this session's generated content.
  /// Multi-select (at least one) — an approved deviation from the Attributes
  /// Dictionary Table, which lists this as a single, non-multivalued ENUM:
  /// the Quiz/Flashcard setup screens let a student pick more than one
  /// level (e.g. Easy + Hard together) in the same request.
  final List<DifficultyLevel> difficultyLevels;

  /// Optional custom prompt supplied by the student for generation.
  final String? customPrompt;

  /// Owning student's email (foreign key to Student).
  final String email;

  /// Course this session's materials belong to (foreign key to Course).
  final String courseId;

  /// IDs of the StudyMaterial documents this session was generated from.
  final List<String> materialIds;

  /// Shared fields common to both QuizSession and FlashcardSession documents.
  /// Subclasses spread this into their own toFirestore() map.
  Map<String, dynamic> sharedFieldsToFirestore() {
    return {
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'earnedPoints': earnedPoints,
      'isSessionCompleted': isSessionCompleted,
      'difficultyLevels': difficultyLevels.map((l) => l.toJson()).toList(),
      'customPrompt': customPrompt,
      'email': email,
      'courseId': courseId,
      'materialIds': materialIds,
    };
  }
}

/// Reads the fields shared by every Session subtype out of a document.
class SessionFields {
  SessionFields({
    required this.createdAt,
    required this.completedAt,
    required this.earnedPoints,
    required this.isSessionCompleted,
    required this.difficultyLevels,
    required this.customPrompt,
    required this.email,
    required this.courseId,
    required this.materialIds,
  });

  final DateTime createdAt;
  final DateTime? completedAt;
  final int earnedPoints;
  final bool isSessionCompleted;
  final List<DifficultyLevel> difficultyLevels;
  final String? customPrompt;
  final String email;
  final String courseId;
  final List<String> materialIds;

  factory SessionFields.fromMap(Map<String, dynamic> data) {
    return SessionFields(
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      earnedPoints: (data['earnedPoints'] as num?)?.toInt() ?? 0,
      isSessionCompleted: data['isSessionCompleted'] as bool? ?? false,
      difficultyLevels: _readDifficultyLevels(data),
      customPrompt: data['customPrompt'] as String?,
      email: data['email'] as String,
      courseId: data['courseId'] as String,
      materialIds: List<String>.from(data['materialIds'] as List? ?? const []),
    );
  }
}

/// Reads `difficultyLevels` (current shape: a list) from a session document.
List<DifficultyLevel> _readDifficultyLevels(Map<String, dynamic> data) {
  final raw = data['difficultyLevels'] as List?;
  if (raw == null || raw.isEmpty) {
    throw StateError(
      'Session document ${data['sessionId'] ?? ''} is missing '
      'difficultyLevels',
    );
  }
  return raw.map((v) => DifficultyLevelJson.fromJson(v as String)).toList();
}
