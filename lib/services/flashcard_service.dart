import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/flashcards/logic/flashcard_logic.dart';
import '../models/enums.dart';
import '../models/flashcard.dart';
import '../models/flashcard_session.dart';
import '../models/study_material.dart';

// TODO: replace these two with the shared public constants from
// auth_service.dart (kNetworkFailureMessage / kGenericFailureMessage) once
// it's confirmed safe to edit that file — a teammate may be actively
// working on it. Text must stay identical to auth_service.dart's. Public so
// the Setup screen can reuse the exact same copy for Worker-call failures.
const kFlashcardNetworkFailureMessage =
    "Couldn't reach Tadarab. Check your connection and try again.";
const kFlashcardGenericFailureMessage =
    'Something went wrong. Please try again.';

/// A user-facing flashcard-feature failure — every Firestore write and the
/// Worker call surface one of these rather than a raw exception, per the NFR
/// that every network/API call shows a clear, retry-able message.
class FlashcardFailure implements Exception {
  FlashcardFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown by [FlashcardService.generateFlashcards] when the Worker is
/// unreachable (no response at all — offline, timeout, DNS failure). Distinct
/// from a response the Worker did send back with an error, so the Setup
/// screen can show the network-failure message specifically for this case.
class WorkerUnreachableException implements Exception {}

/// Thrown by [FlashcardService.generateFlashcards] when the Worker responded
/// but with a non-200 status. Carries the raw body so a future caller could
/// log/debug it, though the UI only ever shows the generic-failure message
/// for this case per CLAUDE.md.
class WorkerResponseException implements Exception {
  WorkerResponseException(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic>? body;
}

/// One generated flashcard, as returned by the Worker's `items` array.
class FlashcardGenerationItem {
  FlashcardGenerationItem({
    required this.frontText,
    required this.backText,
    required this.sourceLocation,
    required this.difficulty,
  });

  final String frontText;
  final String backText;
  final String sourceLocation;
  final DifficultyLevel difficulty;
}

/// The Worker's successful `/generate` response for `type: "flashcard"`.
class FlashcardGenerationResult {
  FlashcardGenerationResult({required this.items});

  final List<FlashcardGenerationItem> items;
}

/// Firestore- and Worker-backed data/actions for the Flashcards feature,
/// scoped to one student and one course (the Setup/Sessions screens always
/// operate inside a specific course — see CLAUDE.md). Injectable (like
/// [AuthService] and [HomeDataService]) so widget tests can supply canned
/// results instead of needing a real Firestore.
class FlashcardService {
  FlashcardService({
    required this.uid,
    required this.courseId,
    FirebaseFirestore? firestore,
  }) : _firestoreOverride = firestore;

  final String uid;
  final String courseId;
  final FirebaseFirestore? _firestoreOverride;

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

  String _messageFor(FirebaseException e) {
    if (e.code == 'unavailable' || e.code == 'network-request-failed') {
      return kFlashcardNetworkFailureMessage;
    }
    return kFlashcardGenericFailureMessage;
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
  Stream<List<FlashcardSession>> watchSessions() {
    return _sessionsRef
        .where('courseId', isEqualTo: courseId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(FlashcardSession.fromFirestore).toList());
  }

  /// Calls the Cloudflare Worker's `POST /generate` (type: "flashcard").
  ///
  /// PENDING: the Worker's live deployed URL hasn't been provided yet, so
  /// this is a placeholder — see CLAUDE.md's "PENDING: network call, worker
  /// deployment status unconfirmed" note. Once the URL is confirmed, this is
  /// the only function that needs a real body: fetch each material's
  /// title/extractedText from `users/{uid}/courses/{courseId}/materials`,
  /// build the request per the "Real Worker contract" section, call
  /// `POST <workerUrl>/generate` with `Authorization: Bearer <idToken>`, and
  /// parse `items` into [FlashcardGenerationItem]s (throwing
  /// [WorkerUnreachableException] / [WorkerResponseException] as appropriate
  /// instead of a raw exception).
  Future<FlashcardGenerationResult> generateFlashcards({
    required List<String> materialIds,
    required List<DifficultyLevel> difficulties,
    required int count,
    String? customPrompt,
  }) async {
    throw UnimplementedError(
      'Worker URL pending from the teammate who owns it — contract is '
      'otherwise final, see CLAUDE.md',
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
  /// session completed, computes and stores `earnedPoints`, and adds the
  /// same amount to the student's `totalPoints` — once, here, never again
  /// outside of a fresh Retake completion.
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
      // Rank recalculation isn't wired up — no rank-threshold logic exists
      // in the codebase yet (see CLAUDE.md's 10-rank system, not yet built).
      batch.update(_studentDoc, {
        'totalPoints': FieldValue.increment(earnedPoints),
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FlashcardFailure(_messageFor(e));
    }
  }

  /// Reshuffles the session's existing flashcards into a new random order
  /// and resets its counts — see [prepareRetake]. No Worker call, no new
  /// session document.
  Future<void> retake({required String sessionId}) async {
    try {
      final cards = await fetchFlashcards(sessionId);
      final result = prepareRetake(flashcards: cards);

      final batch = _firestore.batch();
      for (final card in result.flashcards) {
        batch.update(_cardsRef(sessionId).doc(card.flashcardId), {
          'reviewStatus': card.reviewStatus?.toJson(),
          'cardIndex': card.cardIndex,
        });
      }
      final fields = result.sessionFields;
      batch.update(_sessionsRef.doc(sessionId), {
        'knownCount': fields.knownCount,
        'needsReviewCount': fields.needsReviewCount,
        'currentFlashcardIndex': fields.currentFlashcardIndex,
        'isSessionCompleted': fields.isSessionCompleted,
        'completedAt': fields.completedAt,
        'earnedPoints': fields.earnedPoints,
      });
      await batch.commit();
    } on FlashcardFailure {
      rethrow;
    } on FirebaseException catch (e) {
      throw FlashcardFailure(_messageFor(e));
    }
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
