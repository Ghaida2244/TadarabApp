import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// A single flashcard. Stored at
/// users/{uid}/flashcardSessions/{sessionId}/flashcards/{flashcardId}.
class Flashcard {
  Flashcard({
    required this.flashcardId,
    required this.frontText,
    required this.backText,
    required this.reviewStatus,
    required this.sourceLocation,
    required this.sessionId,
  });

  /// Firestore document ID.
  final String flashcardId;

  /// Text shown on the front of the card (the prompt).
  final String frontText;

  /// Text revealed on the back of the card (the answer).
  final String backText;

  /// Whether the student has marked this "I Know It" or "Needs Review".
  final ReviewStatus reviewStatus;

  /// Excerpt/location in the source material this flashcard was grounded in.
  final String sourceLocation;

  /// Owning flashcard session's ID (foreign key to FlashcardSession).
  final String sessionId;

  factory Flashcard.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Flashcard(
      flashcardId: doc.id,
      frontText: data['frontText'] as String,
      backText: data['backText'] as String,
      reviewStatus: ReviewStatusJson.fromJson(data['reviewStatus'] as String),
      sourceLocation: data['sourceLocation'] as String,
      sessionId: data['sessionId'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'frontText': frontText,
      'backText': backText,
      'reviewStatus': reviewStatus.toJson(),
      'sourceLocation': sourceLocation,
      'sessionId': sessionId,
    };
  }
}
