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
    required this.cardIndex,
  });

  /// Firestore document ID.
  final String flashcardId;

  /// Text shown on the front of the card (the prompt).
  final String frontText;

  /// Text revealed on the back of the card (the answer).
  final String backText;

  /// Whether the student has marked this "I Know It" or "Needs Review".
  /// Null until the student flips and rates the card for the first time —
  /// also reset to null by Retake, since it must return to an unset state.
  final ReviewStatus? reviewStatus;

  /// Excerpt/location in the source material this flashcard was grounded in.
  final String sourceLocation;

  /// Owning flashcard session's ID (foreign key to FlashcardSession).
  final String sessionId;

  /// This card's position within its session's deck. Not in the Attributes
  /// Dictionary Table — an approved deviation. Firestore doesn't preserve
  /// document insertion order, but Resume must reopen the deck in its
  /// original stored order and Retake must persist a freshly-shuffled order,
  /// so an explicit, independently-updatable position field is required.
  final int cardIndex;

  factory Flashcard.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Flashcard(
      flashcardId: doc.id,
      frontText: data['frontText'] as String,
      backText: data['backText'] as String,
      reviewStatus: (data['reviewStatus'] as String?) == null
          ? null
          : ReviewStatusJson.fromJson(data['reviewStatus'] as String),
      sourceLocation: data['sourceLocation'] as String,
      sessionId: data['sessionId'] as String,
      cardIndex: (data['cardIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'frontText': frontText,
      'backText': backText,
      'reviewStatus': reviewStatus?.toJson(),
      'sourceLocation': sourceLocation,
      'sessionId': sessionId,
      'cardIndex': cardIndex,
    };
  }

  Flashcard copyWith({ReviewStatus? Function()? reviewStatus, int? cardIndex}) {
    return Flashcard(
      flashcardId: flashcardId,
      frontText: frontText,
      backText: backText,
      reviewStatus: reviewStatus == null ? this.reviewStatus : reviewStatus(),
      sourceLocation: sourceLocation,
      sessionId: sessionId,
      cardIndex: cardIndex ?? this.cardIndex,
    );
  }
}
