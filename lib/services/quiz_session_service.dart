import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../dev_tools/fake_quiz_generation.dart';
import '../models/enums.dart';
import '../models/question.dart';
import '../models/quiz_session.dart';
import '../models/study_material.dart';
import 'material_catalog.dart';
import 'quiz_generation_client.dart';
import 'streak_service.dart';

/// Points earned per correct answer — per the Quiz design's fixed rule
/// ("Points = 4 per correct answer, and they feed the home streak counts").
const int pointsPerCorrectAnswer = 4;

/// Total points earned for [correctAnswers] correct answers.
int pointsForCorrectAnswers(int correctAnswers) =>
    correctAnswers * pointsPerCorrectAnswer;

/// One row in the grouped Quiz sessions list, pairing a session with
/// whether a group header ("IN PROGRESS" / "COMPLETED") belongs above it.
class QuizSessionListEntry {
  QuizSessionListEntry({
    required this.session,
    required this.showHeader,
    required this.headerLabel,
  });

  final QuizSession session;
  final bool showHeader;
  final String headerLabel;
}

/// Groups sessions with in-progress ones first, completed ones after —
/// mirroring the design's Quiz sessions list — and marks which entries
/// start a new group so the screen can render a header above them. Within
/// each group, newest first: completed sessions by [QuizSession.completedAt]
/// descending, in-progress ones by [QuizSession.createdAt] descending (an
/// in-progress session has no completedAt yet, so createdAt — when the
/// student started it — is the only meaningful "newest" for that group).
/// The most recent session should be the first thing the student sees
/// under either header, not the oldest. Falls back to the input's original
/// relative order if a timestamp is unexpectedly missing — Dart's
/// [List.sort] isn't guaranteed stable, so this sorts on a decorated index
/// instead of relying on that for the fallback case.
List<QuizSessionListEntry> groupQuizSessions(List<QuizSession> sessions) {
  final indexed = sessions.asMap().entries.toList()
    ..sort((a, b) {
      final aDone = a.value.isSessionCompleted ? 1 : 0;
      final bDone = b.value.isSessionCompleted ? 1 : 0;
      if (aDone != bDone) return aDone.compareTo(bDone);
      if (a.value.isSessionCompleted) {
        final aCompletedAt = a.value.completedAt;
        final bCompletedAt = b.value.completedAt;
        if (aCompletedAt != null && bCompletedAt != null) {
          final cmp = bCompletedAt.compareTo(aCompletedAt); // newest first
          if (cmp != 0) return cmp;
        }
      } else {
        final cmp = b.value.createdAt.compareTo(a.value.createdAt); // newest first
        if (cmp != 0) return cmp;
      }
      // Equal (or missing) timestamps: fall back to stable input order.
      return a.key.compareTo(b.key);
    });

  final result = <QuizSessionListEntry>[];
  bool? lastCompleted;
  for (final entry in indexed) {
    final session = entry.value;
    final isFirstInGroup =
        lastCompleted == null || lastCompleted != session.isSessionCompleted;
    result.add(
      QuizSessionListEntry(
        session: session,
        showHeader: isFirstInGroup,
        headerLabel: session.isSessionCompleted ? 'COMPLETED' : 'IN PROGRESS',
      ),
    );
    lastCompleted = session.isSessionCompleted;
  }
  return result;
}

/// Whether the question at [currentQuestionIndex] should be shown in its
/// read-only "revealed" (answered) state — right after submitting, or on
/// resuming a question that was already answered. Learning-mode-only: Exam
/// mode never reveals a question's correctness until the final submit.
bool isRevealedState({required Mode mode, required Question? current}) {
  return mode == Mode.learning && current?.studentAnswer != null;
}

/// The Next/Submit button's label, per the design's exact button rules.
String nextButtonLabel({
  required Mode mode,
  required bool revealed,
  required bool isLastQuestion,
}) {
  if (mode == Mode.learning) {
    if (!revealed) return 'Submit answer';
    return isLastQuestion ? 'Finish quiz' : 'Next question';
  }
  return isLastQuestion ? 'Submit quiz' : 'Next';
}

/// Whether the Worker generated fewer items than the student asked for —
/// triggers the Setup screen's "fewer questions than asked" limit dialog.
bool generatedFewerThanRequested({
  required int requestedCount,
  required int actualCount,
}) => actualCount < requestedCount;

/// The three result-message tiers the Performance Summary screen uses for
/// its mood icon, color, and message — same tiers CLAUDE.md's Points &
/// ranks section implies (trophy/star/arrow), keyed off the fraction
/// correct rather than a shown percentage (the design never shows one).
enum ResultMood { great, solid, keepPractising }

/// Picks the mood tier for [correct] out of [total]. A [total] of zero
/// (shouldn't happen for a real session, but guards against div-by-zero)
/// falls back to the lowest tier rather than throwing.
ResultMood resultMoodFor({required int correct, required int total}) {
  if (total <= 0) return ResultMood.keepPractising;
  final ratio = correct / total;
  if (ratio >= 0.8) return ResultMood.great;
  if (ratio >= 0.5) return ResultMood.solid;
  return ResultMood.keepPractising;
}

/// The motivational line shown under the correct/wrong counts, per mood
/// tier — exact copy from the design.
String resultMessageFor(ResultMood mood) {
  switch (mood) {
    case ResultMood.great:
      return 'Excellent work — keep it up. You are ready for the next lecture.';
    case ResultMood.solid:
      return 'Good progress. Close the gaps below and you have got this.';
    case ResultMood.keepPractising:
      return 'Keep practising, you are improving.';
  }
}

/// A newly (or freshly re-)generated session, plus whatever note the Worker
/// attached (grounding-check discards, or Claude generating fewer items
/// than requested) — the Setup screen shows [note] directly rather than
/// treating it as an error, per CLAUDE.md.
class GeneratedSessionResult {
  GeneratedSessionResult({
    required this.session,
    required this.note,
    required this.requestedCount,
    required this.questions,
  });

  final QuizSession session;
  final String? note;
  final int requestedCount;

  /// The generated questions, held in memory. [createSession] never
  /// writes anything to Firestore for *either* mode anymore — generation
  /// and persistence are deliberately separate steps, so the caller
  /// (QuizSetupScreen) can show the "fewer than requested" dialog first
  /// and only commit once the student has actually confirmed her
  /// decision, not before she's even seen it. See [QuizSessionService
  /// .commitLearningSession] (Learning) and `.submitExamSession` (Exam,
  /// deferred all the way to the end of the exam instead of its start).
  final List<Question> questions;

  bool get gotFewerThanRequested => generatedFewerThanRequested(
    requestedCount: requestedCount,
    actualCount: session.numberOfQuestions,
  );
}

/// Thrown when generation produced zero usable items — nothing to start a
/// session with. [note] (if present) is the Worker's explanation and should
/// be shown to the student instead of a generic error.
class NoQuestionsGeneratedException implements Exception {
  NoQuestionsGeneratedException(this.note);

  final String? note;
}

/// Firestore-backed data/session layer for the Quiz generation & Sessions
/// feature — the single place that reads/writes `quizSessions` and their
/// `questions` subcollection, and orchestrates a call through
/// [QuizGenerationClient]. Injectable (same pattern as [HomeDataService])
/// so widget tests never need a real Firebase app.
class QuizSessionService {
  QuizSessionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    QuizGenerationClient? generationClient,
    MaterialCatalog? materialCatalog,
    StreakService? streakService,
  }) : _firestoreOverride = firestore,
       _authOverride = auth,
       // kUseFakeQuizGeneration (lib/dev_tools/fake_quiz_generation.dart) is
       // a dev-only switch — flip it there, not here, to go back to real
       // Worker/Claude calls. Only applies when no generationClient is
       // explicitly passed in (tests always pass their own).
       _generationClient =
           generationClient ??
           (kUseFakeQuizGeneration
               ? FakeQuizGenerationClient()
               : QuizGenerationClient()),
       _materialCatalog = materialCatalog ?? const StubMaterialCatalog(),
       _streakService = streakService ?? StreakService();

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  final QuizGenerationClient _generationClient;
  final MaterialCatalog _materialCatalog;
  final StreakService _streakService;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;
  String? get _email => _auth.currentUser?.email;

  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('quizSessions');

  Future<List<StudyMaterial>> fetchMaterials(String courseId) {
    return _materialCatalog.fetchMaterials(courseId);
  }

  Future<List<QuizSession>> fetchSessions(String courseId) async {
    final uid = _uid;
    if (uid == null) return const [];
    final snap = await _sessionsRef(
      uid,
    ).where('courseId', isEqualTo: courseId).get();
    return snap.docs.map(QuizSession.fromFirestore).toList();
  }

  Future<QuizSession> fetchSession(String sessionId) async {
    final uid = _uid!;
    final doc = await _sessionsRef(uid).doc(sessionId).get();
    return QuizSession.fromFirestore(doc);
  }

  Future<List<Question>> fetchQuestions(String sessionId) async {
    final uid = _uid!;
    final snap = await _sessionsRef(
      uid,
    ).doc(sessionId).collection('questions').orderBy(FieldPath.documentId).get();
    return snap.docs.map(Question.fromFirestore).toList();
  }

  /// Number of questions in [sessionId] that actually have a
  /// [Question.studentAnswer] set — used for the Sessions list's "X of N
  /// answered" label. Deliberately not `currentQuestionIndex`: the index is
  /// the student's *position*, not how many she's answered — Exam mode lets
  /// her move through questions via Previous/Next without answering them,
  /// and Learning mode lets her answer a question and leave before pressing
  /// Next (which is what actually advances the index).
  Future<int> countAnsweredQuestions(String sessionId) async {
    final questions = await fetchQuestions(sessionId);
    return questions.where((q) => q.studentAnswer != null).length;
  }

  /// Generates a fresh set of questions for a brand-new session — but,
  /// deliberately, writes nothing to Firestore, for either mode.
  /// Generation and persistence are two separate steps on purpose: the
  /// caller (QuizSetupScreen) needs to see the actual generated count
  /// before deciding whether to show the "fewer than requested" dialog,
  /// and nothing should be committed until that decision is final —
  /// declining it must leave zero trace behind, not an orphaned session.
  /// See [commitLearningSession] (Learning's one write, once confirmed)
  /// and `submitExamSession` (Exam's one write, deferred all the way to
  /// the end of the exam instead of its start).
  ///
  /// Throws [NoQuestionsGeneratedException] if nothing usable came back.
  Future<GeneratedSessionResult> createSession({
    required String courseId,
    required List<StudyMaterial> materials,
    required List<DifficultyLevel> difficulties,
    required int count,
    required Mode mode,
    String? customPrompt,
  }) async {
    final uid = _uid!;
    final email = _email ?? '';

    final generationMaterials = await Future.wait(
      materials.map(
        (m) async => GenerationMaterial(
          title: m.title,
          sourceText: await _materialCatalog.sourceTextFor(m),
        ),
      ),
    );

    final result = await _generationClient.generateQuiz(
      count: count,
      difficulties: difficulties,
      customPrompt: customPrompt,
      materials: generationMaterials,
    );

    if (result.items.isEmpty) {
      throw NoQuestionsGeneratedException(result.note);
    }

    // .doc() (no id) reserves a real Firestore document ID client-side —
    // no server round trip, and critically, no write. The session and
    // question IDs are real and stable from this point on, but nothing
    // with those IDs exists in Firestore until the caller explicitly
    // commits them.
    final sessionRef = _sessionsRef(uid).doc();
    final session = QuizSession(
      sessionId: sessionRef.id,
      createdAt: DateTime.now(),
      difficultyLevels: difficulties,
      customPrompt: customPrompt,
      email: email,
      courseId: courseId,
      materialIds: materials.map((m) => m.materialId).toList(),
      numberOfQuestions: result.items.length,
      mode: mode,
    );
    final questions = _reserveQuestions(sessionRef, result.items);

    return GeneratedSessionResult(
      session: session,
      note: result.note,
      requestedCount: count,
      questions: questions,
    );
  }

  /// The one and only Firestore write for a Learning-mode session's
  /// creation — [createSession] no longer performs it directly (see that
  /// method's doc comment). Called once the student's decision is final:
  /// immediately if the generated count met what she asked for, or only
  /// after she taps "Start with these" on the limit dialog if it fell
  /// short. Exam-mode sessions never go through this at all — their
  /// first-ever write is `submitExamSession`, at the very end of the
  /// whole exam instead of the beginning.
  Future<void> commitLearningSession({
    required QuizSession session,
    required List<Question> questions,
  }) async {
    final uid = _uid!;
    final sessionRef = _sessionsRef(uid).doc(session.sessionId);
    final batch = _firestore.batch();
    batch.set(sessionRef, session.toFirestore());
    final questionsRef = sessionRef.collection('questions');
    for (final q in questions) {
      batch.set(questionsRef.doc(q.questionId), q.toFirestore());
    }
    await batch.commit();
  }

  /// Builds [Question]s from freshly generated items, each with a real,
  /// stable Firestore document ID reserved (not written) under
  /// [sessionRef]'s `questions` subcollection — shared by [createSession]
  /// and [retakeSession], both of which may or may not actually write
  /// them depending on mode.
  List<Question> _reserveQuestions(
    DocumentReference<Map<String, dynamic>> sessionRef,
    List<GeneratedQuizItem> items,
  ) {
    final questionsRef = sessionRef.collection('questions');
    return [
      for (final item in items)
        Question(
          questionId: questionsRef.doc().id,
          questionText: item.questionText,
          correctAnswer: item.correctAnswer,
          explanation: item.explanation,
          sourceLocation: item.sourceLocation,
          options: item.options,
          sessionId: sessionRef.id,
        ),
    ];
  }

  /// Records the student's pick for one question. Does not advance
  /// `currentQuestionIndex` — per CLAUDE.md's resume/reveal rule, the
  /// index only moves on an explicit Next/Previous, never on answering.
  Future<void> submitAnswer({
    required String sessionId,
    required String questionId,
    required String answer,
  }) async {
    final uid = _uid!;
    await _sessionsRef(
      uid,
    ).doc(sessionId).collection('questions').doc(questionId).update({
      'studentAnswer': answer,
    });
  }

  /// Moves to [index] — Learning mode only ever moves forward by one
  /// (advance), Exam mode also allows moving back (Previous).
  Future<void> setCurrentQuestionIndex({
    required String sessionId,
    required int index,
  }) async {
    final uid = _uid!;
    await _sessionsRef(uid).doc(sessionId).update({
      'currentQuestionIndex': index,
    });
  }

  /// Flags a question via "Report this question" — flag-and-store only, no
  /// admin review flow (approved scope).
  Future<void> reportQuestion({
    required String sessionId,
    required String questionId,
  }) async {
    final uid = _uid!;
    await _sessionsRef(
      uid,
    ).doc(sessionId).collection('questions').doc(questionId).update({
      'isReported': true,
    });
  }

  /// Marks a real (non-practice) session completed: scores it from its
  /// questions' stored answers (an unanswered question counts as
  /// incorrect), writes the result, credits points to the student's
  /// totalPoints, and records today's study activity for the streak — the
  /// streak's first real caller.
  Future<QuizSession> completeSession(String sessionId) async {
    final uid = _uid!;
    final questions = await fetchQuestions(sessionId);
    final correct = questions.where((q) => q.isCorrect == true).length;
    final incorrect = questions.length - correct;
    final earnedPoints = pointsForCorrectAnswers(correct);
    final now = DateTime.now();

    await _sessionsRef(uid).doc(sessionId).update({
      'isSessionCompleted': true,
      'completedAt': Timestamp.fromDate(now),
      'correctAnswers': correct,
      'incorrectAnswers': incorrect,
      'earnedPoints': earnedPoints,
    });
    await _firestore.collection('users').doc(uid).update({
      'totalPoints': FieldValue.increment(earnedPoints),
    });
    await _streakService.recordStudyActivity(uid: uid, activityDate: now);

    return fetchSession(sessionId);
  }

  /// The one and only Firestore write for an Exam-mode session's entire
  /// lifecycle — creates the session doc already marked completed,
  /// together with its final question docs (each carrying the student's
  /// answer), in a single atomic batch. [draftSession] and
  /// [answeredQuestions] are the in-memory-only draft [createSession] (or
  /// [retakeSession]) handed back for Exam mode — see their doc comments.
  ///
  /// Exam sessions are never partially persisted: not created on start,
  /// not updated per-answer, not updated per-navigation. So if the student
  /// leaves for any reason before this runs — closing the app, a crash,
  /// anything — there is nothing in Firestore to resume: this method is
  /// the only place an Exam session's id is ever written.
  Future<QuizSession> submitExamSession({
    required QuizSession draftSession,
    required List<Question> answeredQuestions,
  }) async {
    final uid = _uid!;
    final sessionRef = _sessionsRef(uid).doc(draftSession.sessionId);

    // A retake reuses the same session id, so this clears out whatever
    // the previous completed attempt left in the questions subcollection
    // before writing the fresh set — same clear-then-write shape as the
    // old (pre-draft) retakeSession, just fired here instead of at
    // "Retake" tap time. For a brand-new exam (never before written),
    // this query is simply empty — nothing to delete.
    final existingQuestions = await sessionRef.collection('questions').get();

    final correct = answeredQuestions.where((q) => q.isCorrect == true).length;
    final incorrect = answeredQuestions.length - correct;
    final earnedPoints = pointsForCorrectAnswers(correct);
    final now = DateTime.now();

    final completed = QuizSession(
      sessionId: draftSession.sessionId,
      createdAt: draftSession.createdAt,
      completedAt: now,
      earnedPoints: earnedPoints,
      isSessionCompleted: true,
      difficultyLevels: draftSession.difficultyLevels,
      customPrompt: draftSession.customPrompt,
      email: draftSession.email,
      courseId: draftSession.courseId,
      materialIds: draftSession.materialIds,
      numberOfQuestions: answeredQuestions.length,
      mode: Mode.exam,
      correctAnswers: correct,
      incorrectAnswers: incorrect,
      currentQuestionIndex: answeredQuestions.isEmpty
          ? 0
          : answeredQuestions.length - 1,
    );

    final batch = _firestore.batch();
    for (final doc in existingQuestions.docs) {
      batch.delete(doc.reference);
    }
    batch.set(sessionRef, completed.toFirestore());
    final questionsRef = sessionRef.collection('questions');
    for (final q in answeredQuestions) {
      batch.set(questionsRef.doc(q.questionId), q.toFirestore());
    }
    await batch.commit();

    await _firestore.collection('users').doc(uid).update({
      'totalPoints': FieldValue.increment(earnedPoints),
    });
    await _streakService.recordStudyActivity(uid: uid, activityDate: now);

    return completed;
  }

  /// Retake: reuses the same session id (design's "session semantics"),
  /// clearing its old questions and result, then calls generation fresh
  /// and independently with the original settings (same materials,
  /// difficulty level(s), count, mode) — no awareness of the previous
  /// questions.
  Future<GeneratedSessionResult> retakeSession(String sessionId) async {
    final uid = _uid!;
    final existing = await fetchSession(sessionId);

    final allMaterials = await _materialCatalog.fetchMaterials(
      existing.courseId,
    );
    final materials = allMaterials
        .where((m) => existing.materialIds.contains(m.materialId))
        .toList();

    final generationMaterials = await Future.wait(
      materials.map(
        (m) async => GenerationMaterial(
          title: m.title,
          sourceText: await _materialCatalog.sourceTextFor(m),
        ),
      ),
    );

    final result = await _generationClient.generateQuiz(
      count: existing.numberOfQuestions,
      difficulties: existing.difficultyLevels,
      customPrompt: existing.customPrompt,
      materials: generationMaterials,
    );

    if (result.items.isEmpty) {
      throw NoQuestionsGeneratedException(result.note);
    }

    final sessionRef = _sessionsRef(uid).doc(sessionId);
    final refreshed = QuizSession(
      sessionId: sessionId,
      createdAt: existing.createdAt,
      difficultyLevels: existing.difficultyLevels,
      customPrompt: existing.customPrompt,
      email: existing.email,
      courseId: existing.courseId,
      materialIds: existing.materialIds,
      numberOfQuestions: result.items.length,
      mode: existing.mode,
      currentQuestionIndex: 0,
    );
    final questions = _reserveQuestions(sessionRef, result.items);

    if (existing.mode == Mode.exam) {
      // Same reasoning as createSession's Exam branch: nothing is written
      // here. The previous completed attempt is untouched in Firestore
      // and stays that way unless/until this retake's own final Submit
      // (submitExamSession) replaces it — so abandoning this retake for
      // any reason just silently reverts to the original result, never a
      // half-finished, resumable retake.
      return GeneratedSessionResult(
        session: refreshed,
        note: result.note,
        requestedCount: existing.numberOfQuestions,
        questions: questions,
      );
    }

    final oldQuestions = await sessionRef.collection('questions').get();
    final batch = _firestore.batch();
    for (final doc in oldQuestions.docs) {
      batch.delete(doc.reference);
    }
    batch.set(sessionRef, refreshed.toFirestore());
    final questionsRef = sessionRef.collection('questions');
    for (final q in questions) {
      batch.set(questionsRef.doc(q.questionId), q.toFirestore());
    }
    await batch.commit();

    return GeneratedSessionResult(
      session: refreshed,
      note: result.note,
      requestedCount: existing.numberOfQuestions,
      questions: questions,
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final uid = _uid!;
    final sessionRef = _sessionsRef(uid).doc(sessionId);
    final questions = await sessionRef.collection('questions').get();
    final batch = _firestore.batch();
    for (final doc in questions.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(sessionRef);
    await batch.commit();
  }
}
