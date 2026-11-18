import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../features/flashcards/logic/flashcard_logic.dart';
import '../models/enums.dart';
import '../models/flashcard.dart';
import '../models/flashcard_session.dart';
import '../models/session.dart';
import '../models/study_material.dart';
import '../utils/error_messages.dart';
import '../utils/rank.dart';
import 'flashcard_generation_service.dart';
import 'generation_topics.dart';
import 'streak_service.dart';

/// Shown when a retake produces zero usable cards and the Worker sent no
/// `note` of its own explaining why. Quiz's parallel case
/// (`kQuizNoItemsMessage` in `quiz_session_service.dart`) already says
/// "...couldn't support any questions..." — the same sentence with the
/// noun swapped.
const kFlashcardNoItemsMessage =
    "Your material couldn't support any flashcards. Try adding another material.";

/// A user-facing flashcard-feature failure — every Firestore write and the
/// Worker call surface one of these rather than a raw exception, per the NFR
/// that every network/API call shows a clear, retry-able message.
class FlashcardFailure implements Exception {
  FlashcardFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Firestore-backed data/actions for the Flashcards feature, scoped to one
/// student and one course (the Setup/Sessions screens always operate inside
/// a specific course — see CLAUDE.md). Injectable (like [AuthService] and
/// [HomeDataService]) so widget tests can supply canned results instead of
/// needing a real Firestore.
///
/// Owns a private [FlashcardGenerationService] for the Worker-calling step
/// (see that class's doc comment) — the same role [QuizSessionService]'s own
/// `_generationClient` plays for Quiz. [generateFlashcards] is kept here too,
/// as a thin passthrough, because every screen and test fake in this
/// feature already holds one [FlashcardSessionService] object for
/// everything (materials, generation, and session writes).
class FlashcardSessionService {
  FlashcardSessionService({
    required this.uid,
    required this.courseId,
    FirebaseFirestore? firestore,
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
    Uri? endpoint,
    StreakService? streakService,
    FlashcardGenerationService? generationService,
  }) : _firestoreOverride = firestore,
       _streakService = streakService ?? StreakService() {
    _generationService =
        generationService ??
        FlashcardGenerationService(
          fetchMaterials: fetchMaterials,
          httpClient: httpClient,
          idTokenProvider: idTokenProvider,
          endpoint: endpoint,
        );
  }

  final String uid;
  final String courseId;
  final FirebaseFirestore? _firestoreOverride;
  final StreakService _streakService;

  /// The Worker-calling generation step, factored out to
  /// [FlashcardGenerationService] (flashcard_generation_service.dart).
  /// Constructed with this service's own [fetchMaterials] so there's one
  /// source for that Firestore read — see that class's doc comment.
  late final FlashcardGenerationService _generationService;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _studentDoc =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _materialsRef => _studentDoc
      .collection('courses')
      .doc(courseId)
      .collection('materials');

  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _studentDoc.collection('flashcardSessions');

  CollectionReference<Map<String, dynamic>> _cardsRef(String sessionId) =>
      _sessionsRef.doc(sessionId).collection('flashcards');

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
  /// blocks completing the session. Mirrors
  /// `QuizSessionService._pointsAndRankUpdate` exactly — kept as its own
  /// copy rather than shared, since the two classes have different write
  /// shapes (a plain `.update()` there, a batch here).
  Future<Map<String, Object?>> _pointsAndRankUpdate(int earnedPoints) async {
    final updates = <String, Object?>{
      'totalPoints': FieldValue.increment(earnedPoints),
    };
    try {
      final snapshot = await _studentDoc.get();
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

  String _messageFor(FirebaseException e) {
    if (e.code == 'unavailable' || e.code == 'network-request-failed') {
      return kNetworkFailureMessage;
    }
    return kGenericFailureMessage;
  }

  /// The current course's materials, for the Setup screen's multi-select.
  Future<List<StudyMaterial>> fetchMaterials() async {
    try {
      final snap = await _materialsRef.get();
      return snap.docs.map(StudyMaterial.fromFirestore).toList();
    } on FirebaseException catch (e) {
      throw FlashcardFailure(_messageFor(e));
    }
  }

  /// All flashcard sessions for this course, newest first (Screen 1).
  ///
  /// Sorts in Dart rather than via a Firestore `orderBy('createdAt')` —
  /// combined with the `where('courseId', ...)` filter, that would need a
  /// composite index that doesn't exist (see `firestore.indexes.json`), and
  /// the query would fail with `failed-precondition` instead of returning
  /// results, live updates or not.
  Stream<List<FlashcardSession>> watchSessions() {
    return _sessionsRef
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map(
          (snap) => sortSessionsNewestFirst(
            snap.docs.map(FlashcardSession.fromFirestore).toList(),
          ),
        );
  }

  /// Calls the Worker's `POST /generate` (type: "flashcard") via
  /// [_generationService] — see [FlashcardGenerationService.generateFlashcards]
  /// for the real implementation. Kept as a passthrough on this class so
  /// callers that already hold one [FlashcardSessionService] for the whole
  /// feature (the Setup screen, the test fakes) don't need a second object.
  Future<FlashcardGenerationResult> generateFlashcards({
    required List<String> materialIds,
    required List<DifficultyLevel> difficulties,
    required int count,
    String? customPrompt,
    bool isRetake = false,
    List<String> previousTopics = const [],
  }) {
    return _generationService.generateFlashcards(
      materialIds: materialIds,
      difficulties: difficulties,
      count: count,
      customPrompt: customPrompt,
      isRetake: isRetake,
      previousTopics: previousTopics,
    );
  }

  /// Creates the FlashcardSession document and its Flashcard sub-documents,
  /// in the exact order [items] was received in. Returns the new session id.
  Future<String> createSession({
    required String email,
    required List<String> materialIds,
    required List<String> materialTitles,
    required List<DifficultyLevel> difficultyLevels,
    String? customPrompt,
    required List<FlashcardGenerationItem> items,
    List<String> coveredTopics = const [],
  }) async {
    final sessionRef = _sessionsRef.doc();
    final session = FlashcardSession(
      sessionId: sessionRef.id,
      createdAt: DateTime.now(),
      difficultyLevels: difficultyLevels,
      customPrompt: customPrompt,
      email: email,
      courseId: courseId,
      materialIds: materialIds,
      materialTitles: materialTitles,
      numberOfFlashcards: items.length,
      coveredTopics: coveredTopics,
    );
    try {
      final batch = _firestore.batch();
      batch.set(sessionRef, session.toFirestore());
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final cardRef = _cardsRef(sessionRef.id).doc();
        final card = Flashcard(
          flashcardId: cardRef.id,
          frontText: item.frontText,
          backText: item.backText,
          reviewStatus: null,
          sourceLocation: item.sourceLocation,
          sessionId: sessionRef.id,
          cardIndex: i,
        );
        batch.set(cardRef, card.toFirestore());
      }
      await batch.commit();
      return sessionRef.id;
    } on FirebaseException catch (e) {
      throw FlashcardFailure(_messageFor(e));
    }
  }

  /// One session's full document — used by [retake] to read the source
  /// session's `rootSessionId`/`coveredTopics`/settings before generating
  /// its replacement.
  Future<FlashcardSession> fetchSession(String sessionId) async {
    try {
      final doc = await _sessionsRef.doc(sessionId).get();
      return FlashcardSession.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FlashcardFailure(_messageFor(e));
    }
  }

  /// Every session in [sessionId]'s retake group (its `rootSessionId`'s
  /// original plus every retake made from it so far) — used by [retake] to
  /// compute the next retake's `retakeNumber`. Single-field filter, no
  /// `orderBy`, so (like [watchSessions]) this never needs a composite
  /// index.
  Future<List<FlashcardSession>> _fetchSessionsInGroup(
    String rootSessionId,
  ) async {
    final snap = await _sessionsRef
        .where('rootSessionId', isEqualTo: rootSessionId)
        .get();
    return snap.docs.map(FlashcardSession.fromFirestore).toList();
  }

  /// A session's flashcards in their current stored order (see
  /// [Flashcard.cardIndex]) — used by both Resume and Review Pass.
  Future<List<Flashcard>> fetchFlashcards(String sessionId) async {
    try {
      final snap = await _cardsRef(sessionId).orderBy('cardIndex').get();
      return snap.docs.map(Flashcard.fromFirestore).toList();
    } on FirebaseException catch (e) {
      throw FlashcardFailure(_messageFor(e));
    }
  }

  /// Persists a rating tap on a non-final card: the card's [status], and the
  /// session's running counts/index. Sets absolute values (rather than
  /// incrementing) so a retry after a failed write is safe to repeat.
  Future<void> markFlashcard({
    required String sessionId,
    required String flashcardId,
    required ReviewStatus status,
    required int currentFlashcardIndex,
    required int knownCount,
    required int needsReviewCount,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.update(_cardsRef(sessionId).doc(flashcardId), {
        'reviewStatus': status.toJson(),
      });
      batch.update(_sessionsRef.doc(sessionId), {
        'currentFlashcardIndex': currentFlashcardIndex,
        'knownCount': knownCount,
        'needsReviewCount': needsReviewCount,
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FlashcardFailure(_messageFor(e));
    }
  }

  /// Persists a rating tap on the final card: the card's [status], marks the
  /// session completed, computes and stores `earnedPoints`, adds the same
  /// amount to the student's `totalPoints` and updates `currentRank` to
  /// match (see [_pointsAndRankUpdate]) — once, here, never again outside
  /// of a fresh Retake completion — and records today's study activity for
  /// the streak (mirrors `QuizSessionService.completeSession`'s own call;
  /// Practice/Review rounds never call this method, so they never touch
  /// the streak).
  Future<void> completeSession({
    required String sessionId,
    required String flashcardId,
    required ReviewStatus status,
    required int finalIndex,
    required int knownCount,
    required int needsReviewCount,
    required DateTime completedAt,
  }) async {
    final earnedPoints = calculateEarnedPoints(knownCount: knownCount);
    try {
      final studentUpdates = await _pointsAndRankUpdate(earnedPoints);
      final batch = _firestore.batch();
      batch.update(_cardsRef(sessionId).doc(flashcardId), {
        'reviewStatus': status.toJson(),
      });
      batch.update(_sessionsRef.doc(sessionId), {
        'currentFlashcardIndex': finalIndex,
        'knownCount': knownCount,
        'needsReviewCount': needsReviewCount,
        'isSessionCompleted': true,
        'completedAt': Timestamp.fromDate(completedAt),
        'earnedPoints': earnedPoints,
      });
      batch.update(_studentDoc, studentUpdates);
      await batch.commit();
      await _streakService.recordStudyActivity(
        uid: uid,
        activityDate: completedAt,
      );
    } on FirebaseException catch (e) {
      throw FlashcardFailure(_messageFor(e));
    }
  }

  /// Retakes [sessionId] by generating a brand-new set of cards through the
  /// Worker (via [_generationService]) — same settings as the source
  /// session (materials/difficulties/count/customPrompt, all supplied by
  /// the caller, which already has them from the session doc) plus
  /// `isRetake: true` and `previousTopics` (the source session's own stored
  /// [FlashcardSession.coveredTopics], never a union across the rest of the
  /// retake group — see [buildPreviousTopics]) — then creates a brand-new
  /// [FlashcardSession] document for the result, sharing the source's
  /// `rootSessionId` and pointing `retakeOfSessionId` at it. The source
  /// session and its existing cards are never written to or deleted: a
  /// retake no longer overwrites, it adds a new entry to the same retake
  /// group.
  ///
  /// Firestore is read once at the very start — [fetchSession] on the
  /// source, purely to get its `coveredTopics` for `previousTopics` —
  /// before the Worker is ever called; it is only WRITTEN once the Worker
  /// succeeds (a non-empty result), so a failure of any kind (network,
  /// timeout, or zero usable cards) creates nothing and leaves every
  /// existing session completely unchanged. [FlashcardFailure] covers all
  /// of these — zero cards is treated the same as a Firestore failure, not
  /// a successful-but-empty retake.
  ///
  /// The new session's cards are all brand-new docs — [planRetakeCardWrites]
  /// is still used (with `existingCount: 0`, since the new session starts
  /// with none) so the write-building shape matches a pre-redesign retake
  /// exactly; [batchSizes] still splits the writes into Firestore-safe
  /// batches of at most 500 operations.
  Future<RetakeOutcome> retake({
    required String sessionId,
    required List<String> materialIds,
    required List<DifficultyLevel> difficulties,
    required int count,
    String? customPrompt,
  }) async {
    final source = await fetchSession(sessionId);
    final previousTopics = buildPreviousTopics(source.coveredTopics);

    final result = await _generationService.generateFlashcards(
      materialIds: materialIds,
      difficulties: difficulties,
      count: count,
      customPrompt: customPrompt,
      isRetake: true,
      previousTopics: previousTopics,
    );

    if (result.items.isEmpty) {
      throw FlashcardFailure(result.note ?? kFlashcardNoItemsMessage);
    }

    final group = await _fetchSessionsInGroup(source.rootSessionId);
    final retakeNumber = nextRetakeNumber(group.map((s) => s.retakeNumber));

    final newSessionRef = _sessionsRef.doc();
    final newSession = FlashcardSession(
      sessionId: newSessionRef.id,
      createdAt: DateTime.now(),
      difficultyLevels: difficulties,
      customPrompt: customPrompt,
      email: source.email,
      courseId: courseId,
      materialIds: materialIds,
      materialTitles: source.materialTitles,
      rootSessionId: source.rootSessionId,
      retakeNumber: retakeNumber,
      retakeOfSessionId: source.sessionId,
      coveredTopics: result.coveredTopics,
      numberOfFlashcards: result.items.length,
    );

    // A new session always starts with zero existing cards, so this plan
    // is always "add every one of them" (overwriteCount 0) — called anyway
    // so the write-building shape here still reuses the exact same
    // function the pre-redesign retake used.
    final plan = planRetakeCardWrites(existingCount: 0, newCount: result.items.length);
    assert(plan.overwriteCount == 0 && plan.addCount == result.items.length);
    final newCardsCollection = _cardsRef(newSessionRef.id);

    // Every write this retake needs, in one flat list — the new session
    // doc, then every one of its (all brand-new) cards — sliced into
    // Firestore-sized batches below.
    final writes = <void Function(WriteBatch batch)>[
      (batch) => batch.set(newSessionRef, newSession.toFirestore()),
      for (var i = 0; i < result.items.length; i++)
        (batch) {
          final item = result.items[i];
          final docRef = newCardsCollection.doc();
          batch.set(
            docRef,
            Flashcard(
              flashcardId: docRef.id,
              frontText: item.frontText,
              backText: item.backText,
              reviewStatus: null,
              sourceLocation: item.sourceLocation,
              sessionId: newSessionRef.id,
              cardIndex: i,
            ).toFirestore(),
          );
        },
    ];

    try {
      var start = 0;
      for (final size in batchSizes(totalOperations: writes.length)) {
        final batch = _firestore.batch();
        for (final write in writes.skip(start).take(size)) {
          write(batch);
        }
        await batch.commit();
        start += size;
      }
    } on FirebaseException catch (e) {
      throw FlashcardFailure(_messageFor(e));
    }

    return (
      requestedCount: result.requestedCount,
      actualCount: result.items.length,
      note: result.note,
      newSessionId: newSessionRef.id,
    );
  }

  /// Deletes the session document and every one of its flashcard
  /// sub-documents.
  Future<void> deleteSession({required String sessionId}) async {
    try {
      final cardsSnap = await _cardsRef(sessionId).get();
      final batch = _firestore.batch();
      for (final doc in cardsSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_sessionsRef.doc(sessionId));
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FlashcardFailure(_messageFor(e));
    }
  }
}
