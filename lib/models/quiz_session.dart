import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'session.dart';

/// A quiz study session. Stored at users/{uid}/quizSessions/{sessionId}.
class QuizSession extends Session {
  QuizSession({
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
    this.numberOfQuestions = 0,
    required this.mode,
    this.correctAnswers = 0,
    this.incorrectAnswers = 0,
    this.currentQuestionIndex = 0,
  });

  /// Total number of questions generated for this session.
  final int numberOfQuestions;

  /// Exam (answer-all-then-submit) or Learning (immediate feedback) mode.
  final Mode mode;

  /// Count of questions answered correctly so far.
  final int correctAnswers;

  /// Count of questions answered incorrectly so far.
  final int incorrectAnswers;

  /// Index of the question the student is currently on (for resuming).
  final int currentQuestionIndex;

  factory QuizSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final shared = SessionFields.fromMap(data);
    return QuizSession(
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
      numberOfQuestions: (data['numberOfQuestions'] as num?)?.toInt() ?? 0,
      mode: ModeJson.fromJson(data['mode'] as String),
      correctAnswers: (data['correctAnswers'] as num?)?.toInt() ?? 0,
      incorrectAnswers: (data['incorrectAnswers'] as num?)?.toInt() ?? 0,
      currentQuestionIndex:
          (data['currentQuestionIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      ...sharedFieldsToFirestore(),
      'numberOfQuestions': numberOfQuestions,
      'mode': mode.toJson(),
      'correctAnswers': correctAnswers,
      'incorrectAnswers': incorrectAnswers,
      'currentQuestionIndex': currentQuestionIndex,
    };
  }
}
