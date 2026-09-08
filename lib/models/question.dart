import 'package:cloud_firestore/cloud_firestore.dart';

/// A single quiz question. Stored at
/// users/{uid}/quizSessions/{sessionId}/questions/{questionId}.
///
/// Deliberately has no stored `isCorrect` field: sessions have a small,
/// bounded number of questions and are always fetched in full for the
/// review-mistakes screens, so storing a value that's derivable from
/// [studentAnswer] and [correctAnswer] would only risk drifting out of sync.
/// Use [isCorrect] below to compute it on read instead.
class Question {
  Question({
    required this.questionId,
    required this.questionText,
    required this.correctAnswer,
    required this.explanation,
    required this.sourceLocation,
    this.studentAnswer,
    required this.options,
    required this.sessionId,
  });

  /// Firestore document ID.
  final String questionId;

  /// The question prompt shown to the student.
  final String questionText;

  /// The correct answer text.
  final String correctAnswer;

  /// Explanation shown after answering (Learning mode) or during review.
  final String explanation;

  /// Excerpt/location in the source material this question was grounded in.
  final String sourceLocation;

  /// The answer the student selected; null until answered.
  final String? studentAnswer;

  /// The list of answer options presented to the student.
  final List<String> options;

  /// Owning quiz session's ID (foreign key to QuizSession).
  final String sessionId;

  /// Whether the student's answer was correct. Computed, not stored — see
  /// class doc comment. Null if the student hasn't answered yet.
  bool? get isCorrect =>
      studentAnswer == null ? null : studentAnswer == correctAnswer;

  factory Question.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Question(
      questionId: doc.id,
      questionText: data['questionText'] as String,
      correctAnswer: data['correctAnswer'] as String,
      explanation: data['explanation'] as String,
      sourceLocation: data['sourceLocation'] as String,
      studentAnswer: data['studentAnswer'] as String?,
      options: List<String>.from(data['options'] as List? ?? const []),
      sessionId: data['sessionId'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'questionText': questionText,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'sourceLocation': sourceLocation,
      'studentAnswer': studentAnswer,
      'options': options,
      'sessionId': sessionId,
    };
  }
}
