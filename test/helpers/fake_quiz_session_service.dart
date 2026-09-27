import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/question.dart';
import 'package:tadarab_app/models/quiz_session.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/quiz_session_service.dart';

/// A controllable stand-in for [QuizSessionService], used across the Quiz
/// screens' widget tests so they never depend on a real Firebase app or a
/// real Worker call. Mutates small in-memory lists so a test can drive a
/// real flow (answer -> advance -> finish) and assert on the result.
class FakeQuizSessionService extends QuizSessionService {
  FakeQuizSessionService({
    List<StudyMaterial>? materials,
    List<QuizSession>? sessions,
    Map<String, List<Question>>? questions,
    this.createSessionResult,
    this.createSessionError,
    this.retakeSessionResult,
  }) : materials = materials ?? const [],
       sessions = List.of(sessions ?? const []),
       questionsBySession = {
         for (final e in (questions ?? const {}).entries) e.key: List.of(e.value),
       };

  final List<StudyMaterial> materials;
  final List<QuizSession> sessions;
  final Map<String, List<Question>> questionsBySession;

  /// When set, [createSession] returns this instead of building a session
  /// from the request — lets a test control exactly what "generation"
  /// produced (including a fewer-than-requested result, for the limit
  /// dialog) without simulating the real Worker call.
  GeneratedSessionResult? createSessionResult;
  Object? createSessionError;
  GeneratedSessionResult? retakeSessionResult;

  int deleteCalls = 0;
  int completeCalls = 0;
  int reportCalls = 0;
  int createSessionCalls = 0;
  int fetchSessionsCalls = 0;
  int submitExamSessionCalls = 0;
  int commitLearningSessionCalls = 0;
  String? lastReportedQuestionId;
  List<String> submittedAnswers = [];
  // Snapshot of the questions handed to the most recent submitExamSession
  // call — lets a test assert on exactly what was (or wasn't) submitted,
  // separately from the answers seen via submitAnswer (which an Exam
  // draft never calls).
  List<Question>? lastSubmittedExamQuestions;

  @override
  Future<List<StudyMaterial>> fetchMaterials(String courseId) async {
    return materials;
  }

  @override
  Future<List<QuizSession>> fetchSessions(String courseId) async {
    fetchSessionsCalls++;
    return List.of(sessions);
  }

  @override
  Future<QuizSession> fetchSession(String sessionId) async {
    return sessions.firstWhere((s) => s.sessionId == sessionId);
  }

  @override
  Future<List<Question>> fetchQuestions(String sessionId) async {
    return List.of(questionsBySession[sessionId] ?? const []);
  }

  @override
  Future<GeneratedSessionResult> createSession({
    required String courseId,
    required List<StudyMaterial> materials,
    required List<DifficultyLevel> difficulties,
    required int count,
    required Mode mode,
    String? customPrompt,
  }) async {
    createSessionCalls++;
    if (createSessionError != null) throw createSessionError!;
    // Generation only — mirrors the real QuizSessionService.createSession,
    // which no longer writes anything for either mode. Nothing is added
    // to `sessions`/`questionsBySession` here; see commitLearningSession
    // (Learning) and submitExamSession (Exam) for the actual "writes".
    return createSessionResult!;
  }

  @override
  Future<void> commitLearningSession({
    required QuizSession session,
    required List<Question> questions,
  }) async {
    commitLearningSessionCalls++;
    sessions.add(session);
    questionsBySession[session.sessionId] = List.of(questions);
  }

  @override
  Future<void> submitAnswer({
    required String sessionId,
    required String questionId,
    required String answer,
  }) async {
    submittedAnswers.add(answer);
    final list = questionsBySession[sessionId];
    if (list == null) return;
    final idx = list.indexWhere((q) => q.questionId == questionId);
    if (idx != -1) list[idx] = list[idx].copyWith(studentAnswer: answer);
  }

  @override
  Future<void> setCurrentQuestionIndex({
    required String sessionId,
    required int index,
  }) async {
    final idx = sessions.indexWhere((s) => s.sessionId == sessionId);
    if (idx != -1) sessions[idx] = _withIndex(sessions[idx], index);
  }

  @override
  Future<void> reportQuestion({
    required String sessionId,
    required String questionId,
  }) async {
    reportCalls++;
    lastReportedQuestionId = questionId;
    final list = questionsBySession[sessionId];
    if (list == null) return;
    final idx = list.indexWhere((q) => q.questionId == questionId);
    if (idx != -1) list[idx] = list[idx].copyWith(isReported: true);
  }

  @override
  Future<QuizSession> completeSession(String sessionId) async {
    completeCalls++;
    final questions = questionsBySession[sessionId] ?? const [];
    final correct = questions.where((q) => q.isCorrect == true).length;
    final idx = sessions.indexWhere((s) => s.sessionId == sessionId);
    if (idx != -1) {
      final s = sessions[idx];
      sessions[idx] = QuizSession(
        sessionId: s.sessionId,
        createdAt: s.createdAt,
        completedAt: DateTime(2026, 1, 1),
        earnedPoints: correct * pointsPerCorrectAnswer,
        isSessionCompleted: true,
        difficultyLevels: s.difficultyLevels,
        customPrompt: s.customPrompt,
        email: s.email,
        courseId: s.courseId,
        materialIds: s.materialIds,
        numberOfQuestions: s.numberOfQuestions,
        mode: s.mode,
        correctAnswers: correct,
        incorrectAnswers: questions.length - correct,
        currentQuestionIndex: s.currentQuestionIndex,
      );
      return sessions[idx];
    }
    return fetchSession(sessionId);
  }

  @override
  Future<QuizSession> submitExamSession({
    required QuizSession draftSession,
    required List<Question> answeredQuestions,
  }) async {
    submitExamSessionCalls++;
    lastSubmittedExamQuestions = List.of(answeredQuestions);
    final correct = answeredQuestions.where((q) => q.isCorrect == true).length;
    final completed = QuizSession(
      sessionId: draftSession.sessionId,
      createdAt: draftSession.createdAt,
      completedAt: DateTime(2026, 1, 1),
      earnedPoints: correct * pointsPerCorrectAnswer,
      isSessionCompleted: true,
      difficultyLevels: draftSession.difficultyLevels,
      customPrompt: draftSession.customPrompt,
      email: draftSession.email,
      courseId: draftSession.courseId,
      materialIds: draftSession.materialIds,
      numberOfQuestions: answeredQuestions.length,
      mode: Mode.exam,
      correctAnswers: correct,
      incorrectAnswers: answeredQuestions.length - correct,
      currentQuestionIndex: answeredQuestions.isEmpty
          ? 0
          : answeredQuestions.length - 1,
    );
    // Replace-or-add: a retake reuses the same session id, a brand-new
    // exam gets a fresh one — same either way from here.
    final idx = sessions.indexWhere((s) => s.sessionId == draftSession.sessionId);
    if (idx != -1) {
      sessions[idx] = completed;
    } else {
      sessions.add(completed);
    }
    questionsBySession[draftSession.sessionId] = List.of(answeredQuestions);
    return completed;
  }

  @override
  Future<GeneratedSessionResult> retakeSession(String sessionId) async {
    final result = retakeSessionResult!;
    // Mirrors the real retakeSession: only Learning writes immediately.
    // An Exam retake stays a pure in-memory draft until its own final
    // Submit (submitExamSession), so `sessions` must stay untouched —
    // still showing the original completed attempt — until then.
    if (result.session.mode == Mode.learning) {
      final idx = sessions.indexWhere((s) => s.sessionId == sessionId);
      if (idx != -1) sessions[idx] = result.session;
    }
    return result;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    deleteCalls++;
    sessions.removeWhere((s) => s.sessionId == sessionId);
    questionsBySession.remove(sessionId);
  }
}

QuizSession _withIndex(QuizSession s, int index) {
  return QuizSession(
    sessionId: s.sessionId,
    createdAt: s.createdAt,
    completedAt: s.completedAt,
    earnedPoints: s.earnedPoints,
    isSessionCompleted: s.isSessionCompleted,
    difficultyLevels: s.difficultyLevels,
    customPrompt: s.customPrompt,
    email: s.email,
    courseId: s.courseId,
    materialIds: s.materialIds,
    numberOfQuestions: s.numberOfQuestions,
    mode: s.mode,
    correctAnswers: s.correctAnswers,
    incorrectAnswers: s.incorrectAnswers,
    currentQuestionIndex: index,
  );
}
