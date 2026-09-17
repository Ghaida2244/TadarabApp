import 'package:cloud_firestore/cloud_firestore.dart';

import 'session.dart';

/// A flashcard study session. Stored at users/{uid}/flashcardSessions/{sessionId}.
class FlashcardSession extends Session {
  FlashcardSession({
    required super.sessionId,
    required super.createdAt,
    super.completedAt,
    super.earnedPoints,
    super.isSessionCompleted,
    required super.difficultyLevels,
    super.customPrompt,
    required super.email,
    required super.courseId,
    required super.materialIds,
    this.numberOfFlashcards = 0,
    this.currentFlashcardIndex = 0,
    this.needsReviewCount = 0,
    this.knownCount = 0,
  });

  /// Total number of flashcards generated for this session.
  final int numberOfFlashcards;

  /// Index of the flashcard the student is currently on (for resuming).
  final int currentFlashcardIndex;

  /// Count of flashcards marked "Needs Review".
  final int needsReviewCount;

  /// Count of flashcards marked "I Know It".
  final int knownCount;

  factory FlashcardSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final shared = SessionFields.fromMap(data);
    return FlashcardSession(
      sessionId: doc.id,
      createdAt: shared.createdAt,
      completedAt: shared.completedAt,
      earnedPoints: shared.earnedPoints,
      isSessionCompleted: shared.isSessionCompleted,
      difficultyLevels: shared.difficultyLevels,
      customPrompt: shared.customPrompt,
      email: shared.email,
      courseId: shared.courseId,
      materialIds: shared.materialIds,
      numberOfFlashcards: (data['numberOfFlashcards'] as num?)?.toInt() ?? 0,
      currentFlashcardIndex:
          (data['currentFlashcardIndex'] as num?)?.toInt() ?? 0,
      needsReviewCount: (data['needsReviewCount'] as num?)?.toInt() ?? 0,
      knownCount: (data['knownCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      ...sharedFieldsToFirestore(),
      'numberOfFlashcards': numberOfFlashcards,
      'currentFlashcardIndex': currentFlashcardIndex,
      'needsReviewCount': needsReviewCount,
      'knownCount': knownCount,
    };
  }
}
