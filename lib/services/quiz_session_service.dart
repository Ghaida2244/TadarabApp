import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../logic/session_stacking.dart';
import '../models/enums.dart';
import '../models/question.dart';
import '../models/quiz_session.dart';
import '../models/session.dart';
import '../models/study_material.dart';
import '../utils/rank.dart';
import 'generation_topics.dart';
import 'material_catalog.dart';
import 'quiz_generation_client.dart';
import 'streak_service.dart';

/// Points earned per correct answer — per the Quiz design's fixed rule
/// ("Points = 4 per correct answer, and they feed the home streak counts").
const int pointsPerCorrectAnswer = 4;

/// Total points earned for [correctAnswers] correct answers.
int pointsForCorrectAnswers(int correctAnswers) =>
    correctAnswers * pointsPerCorrectAnswer;

/// One row in the grouped Quiz sessions list, pairing a session group
/// (today's plain card for a lone session, or a Retake Stack for 2+
/// sharing a retake chain — see [groupSessionsIntoStacks]) with whether a
/// section header ("IN PROGRESS" / "COMPLETED") belongs above it.
class QuizSessionListEntry {
  QuizSessionListEntry({
    required this.group,
    required this.showHeader,
    required this.headerLabel,
  });

  final SessionStack<QuizSession> group;
  final bool showHeader;
  final String headerLabel;
}

/// Groups sessions with in-progress ones first, completed ones after —
/// mirroring the design's Quiz sessions list — and marks which entries
/// start a new section so the screen can render a header above them.
/// Sessions sharing a retake chain ([Session.rootSessionId]) within the
/// same section become one [SessionStack]; see [groupSessionsIntoStacks]
/// for the exact within-stack and between-stack ordering (unchanged from
/// before stacking existed: completed groups by their top attempt's
/// [QuizSession.completedAt] descending, in-progress groups by
/// [QuizSession.createdAt] descending).
List<QuizSessionListEntry> groupQuizSessions(List<QuizSession> sessions) {
  final groups = groupSessionsIntoStacks<QuizSession>(
    sessions: sessions,
    isCompleted: (s) => s.isSessionCompleted,
    rootSessionId: (s) => s.rootSessionId,
    retakeNumber: (s) => s.retakeNumber,
    createdAt: (s) => s.createdAt,
    completedAt: (s) => s.completedAt,
  );

  final result = <QuizSessionListEntry>[];
  bool? lastCompleted;
  for (final group in groups) {
    final isFirstInGroup =
        lastCompleted == null || lastCompleted != group.isCompleted;
    result.add(
      QuizSessionListEntry(
        group: group,
        showHeader: isFirstInGroup,
        headerLabel: group.isCompleted ? 'COMPLETED' : 'IN PROGRESS',
      ),
    );
    lastCompleted = group.isCompleted;
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

/// Splits [totalOperations] Firestore writes into batches of at most 500
/// (Firestore's hard per-batch cap) — used by [QuizSessionService
/// .retakeSession]'s Learning-mode write. Same mechanism as Flashcards'
/// own `batchSizes()` (flashcard_logic.dart), duplicated here rather than
/// imported, to avoid a cross-feature dependency from Quiz into the
/// Flashcards feature's own logic file.
List<int> batchWriteSizes({required int totalOperations, int maxPerBatch = 500}) {
  assert(totalOperations >= 0, 'totalOperations cannot be negative');
  assert(maxPerBatch > 0, 'maxPerBatch must be positive');
  final sizes = <int>[];
  var remaining = totalOperations;
  while (remaining > 0) {
    final size = remaining < maxPerBatch ? remaining : maxPerBatch;
    sizes.add(size);
    remaining -= size;
  }
  return sizes;
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
       _generationClient = generationClient ?? QuizGenerationClient(),
       _materialCatalog = materialCatalog ?? CoursesMaterialCatalog(),
       _streakService = streakService ?? StreakService();

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  final QuizGenerationClient _generationClient;
  final MaterialCatalog _materialCatalog;
  final StreakService _streakService;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// Public (unlike [_firestore]/[_auth]) so a test subclass can override
  /// just the signed-in identity — same pattern as [CalendarService],
  /// [CoursesService] and [HomeDataService]'s own `currentUid`.
  String? get currentUid => _auth.currentUser?.uid;

  /// See [currentUid].
  String? get currentEmail => _auth.currentUser?.email;

  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('quizSessions');

  /// Builds the student-doc field updates for awarding [earnedPoints]:
  /// `totalPoints` always (via [FieldValue.increment], unchanged from
  /// before — so concurrent completions can't lose points), plus
  /// `currentRank` best-effort, per rank.dart's INTEGRATION POINT. Reads
  /// the student's *current* `totalPoints` first (a missing field on an
  /// existing doc reads as 0) to compute what the new total will become,
  /// then sets `currentRank` to [rankForPoints] of that. If the read
  /// throws, or the student doc doesn't exist, `currentRank` is omitted
  /// entirely — the displayed rank is always derived from `totalPoints`
  /// directly, so a missed write here never breaks anything and never
  /// blocks completing the session.
  Future<Map<String, Object?>> _pointsAndRankUpdate({
    required String uid,
    required int earnedPoints,
  }) async {
    final updates = <String, Object?>{
      'totalPoints': FieldValue.increment(earnedPoints),
    };
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      if (snapshot.exists) {
        final currentTotal =
            (snapshot.data()?['totalPoints'] as num?)?.toInt() ?? 0;
        final newTotal = currentTotal + earnedPoints;
        updates['currentRank'] = rankForPoints(newTotal).name;
      }
    } catch (_) {
      // Best-effort only — see the doc comment above.
    }
    return updates;
  }

  Future<List<StudyMaterial>> fetchMaterials(String courseId) {
    return _materialCatalog.fetchMaterials(courseId);
  }

  Future<List<QuizSession>> fetchSessions(String courseId) async {
    final uid = currentUid;
    if (uid == null) return const [];
    final snap = await _sessionsRef(
      uid,
    ).where('courseId', isEqualTo: courseId).get();
    return snap.docs.map(QuizSession.fromFirestore).toList();
  }

  Future<QuizSession> fetchSession(String sessionId) async {
    final uid = currentUid!;
    final doc = await _sessionsRef(uid).doc(sessionId).get();
    return QuizSession.fromFirestore(doc);
  }

  /// Every session in [rootSessionId]'s retake group (its original plus
  /// every retake made from it so far) — used by [retakeSession] to compute
  /// the next retake's `retakeNumber`. Single-field filter, no `orderBy`,
  /// so (like [fetchSessions]) this never needs a composite index.
  Future<List<QuizSession>> _fetchSessionsInGroup(
    String uid,
    String rootSessionId,
  ) async {
    final snap = await _sessionsRef(
      uid,
    ).where('rootSessionId', isEqualTo: rootSessionId).get();
    return snap.docs.map(QuizSession.fromFirestore).toList();
  }

  Future<List<Question>> fetchQuestions(String sessionId) async {
    final uid = currentUid!;
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
    final uid = currentUid!;
    final email = currentEmail ?? '';

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
      coveredTopics: result.coveredTopics,
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
    final uid = currentUid!;
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
    final uid = currentUid!;
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
    final uid = currentUid!;
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
    final uid = currentUid!;
    await _sessionsRef(
      uid,
    ).doc(sessionId).collection('questions').doc(questionId).update({
      'isReported': true,
    });
  }

  /// Marks a real (non-practice) session completed: scores it from its
  /// questions' stored answers (an unanswered question counts as
  /// incorrect), writes the result, credits points to the student's
  /// totalPoints and currentRank (see [_pointsAndRankUpdate]), and records
  /// today's study activity for the streak — the streak's first real
  /// caller.
  Future<QuizSession> completeSession(String sessionId) async {
    final uid = currentUid!;
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
    final studentUpdates = await _pointsAndRankUpdate(
      uid: uid,
      earnedPoints: earnedPoints,
    );
    await _firestore.collection('users').doc(uid).update(studentUpdates);
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
  /// the only place an Exam session's id is ever written. [draftSession
  /// .sessionId] is always a brand-new, never-before-written id (reserved
  /// via `.doc()` by [createSession] or [retakeSession], never reused), so
  /// there's never anything under it to clear first — unlike before the
  /// new-session-per-retake redesign, a retake no longer reuses its
  /// source's id.
  Future<QuizSession> submitExamSession({
    required QuizSession draftSession,
    required List<Question> answeredQuestions,
  }) async {
    final uid = currentUid!;
    final sessionRef = _sessionsRef(uid).doc(draftSession.sessionId);

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
      rootSessionId: draftSession.rootSessionId,
      retakeNumber: draftSession.retakeNumber,
      retakeOfSessionId: draftSession.retakeOfSessionId,
      coveredTopics: draftSession.coveredTopics,
      numberOfQuestions: answeredQuestions.length,
      mode: Mode.exam,
      correctAnswers: correct,
      incorrectAnswers: incorrect,
      currentQuestionIndex: answeredQuestions.isEmpty
          ? 0
          : answeredQuestions.length - 1,
    );

    final batch = _firestore.batch();
    batch.set(sessionRef, completed.toFirestore());
    final questionsRef = sessionRef.collection('questions');
    for (final q in answeredQuestions) {
      batch.set(questionsRef.doc(q.questionId), q.toFirestore());
    }
    await batch.commit();

    final studentUpdates = await _pointsAndRankUpdate(
      uid: uid,
      earnedPoints: earnedPoints,
    );
    await _firestore.collection('users').doc(uid).update(studentUpdates);
    await _streakService.recordStudyActivity(uid: uid, activityDate: now);

    return completed;
  }

  /// Retake: creates a brand-new session (a new, never-before-written id —
  /// see [createSession]'s "reserve, don't write" approach) rather than
  /// overwriting [sessionId] — the source session and its existing
  /// questions are never touched or deleted. The new session shares the
  /// source's `rootSessionId` and points `retakeOfSessionId` at it, with
  /// `retakeNumber` one more than the highest already in that group (see
  /// [nextRetakeNumber]). Generation is called fresh and independently with
  /// the source session's own settings (same materials, difficulty
  /// level(s), count, mode) plus `isRetake: true` and `previousTopics` —
  /// the source session's own stored `coveredTopics` only, never a union
  /// across the rest of the retake group (see [buildPreviousTopics]).
  Future<GeneratedSessionResult> retakeSession(String sessionId) async {
    final uid = currentUid!;
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

    final previousTopics = buildPreviousTopics(existing.coveredTopics);

    final result = await _generationClient.generateQuiz(
      count: existing.numberOfQuestions,
      difficulties: existing.difficultyLevels,
      customPrompt: existing.customPrompt,
      materials: generationMaterials,
      isRetake: true,
      previousTopics: previousTopics,
    );

    if (result.items.isEmpty) {
      throw NoQuestionsGeneratedException(result.note);
    }

    final group = await _fetchSessionsInGroup(uid, existing.rootSessionId);
    final retakeNumber = nextRetakeNumber(group.map((s) => s.retakeNumber));

    // .doc() (no id) reserves a brand-new, real Firestore document ID
    // client-side — no server round trip, no write. Same "reserve, don't
    // write yet" approach as createSession, so Exam mode below can hand
    // this id back in an unwritten draft.
    final sessionRef = _sessionsRef(uid).doc();
    final fresh = QuizSession(
      sessionId: sessionRef.id,
      createdAt: DateTime.now(),
      difficultyLevels: existing.difficultyLevels,
      customPrompt: existing.customPrompt,
      email: existing.email,
      courseId: existing.courseId,
      materialIds: existing.materialIds,
      rootSessionId: existing.rootSessionId,
      retakeNumber: retakeNumber,
      retakeOfSessionId: existing.sessionId,
      coveredTopics: result.coveredTopics,
      numberOfQuestions: result.items.length,
      mode: existing.mode,
      currentQuestionIndex: 0,
    );
    final questions = _reserveQuestions(sessionRef, result.items);

    if (existing.mode == Mode.exam) {
      // Nothing is written here — same reasoning as createSession's Exam
      // branch. The source session (and every other existing session) is
      // completely untouched, so abandoning this retake for any reason
      // before the final Submit (submitExamSession) leaves no trace at
      // all — not a half-finished, resumable retake, and not a change to
      // anything that already existed.
      return GeneratedSessionResult(
        session: fresh,
        note: result.note,
        requestedCount: existing.numberOfQuestions,
        questions: questions,
      );
    }

    final writes = <void Function(WriteBatch batch)>[
      (batch) => batch.set(sessionRef, fresh.toFirestore()),
      for (final q in questions)
        (batch) => batch.set(
          sessionRef.collection('questions').doc(q.questionId),
          q.toFirestore(),
        ),
    ];
    var start = 0;
    for (final size in batchWriteSizes(totalOperations: writes.length)) {
      final batch = _firestore.batch();
      for (final write in writes.skip(start).take(size)) {
        write(batch);
      }
      await batch.commit();
      start += size;
    }

    return GeneratedSessionResult(
      session: fresh,
      note: result.note,
      requestedCount: existing.numberOfQuestions,
      questions: questions,
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final uid = currentUid!;
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
