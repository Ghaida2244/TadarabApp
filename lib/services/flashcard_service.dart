import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../features/flashcards/logic/flashcard_logic.dart';
import '../models/enums.dart';
import '../models/flashcard.dart';
import '../models/flashcard_session.dart';
import '../models/study_material.dart';
import 'auth_service.dart';

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

  factory FlashcardGenerationItem.fromJson(Map<String, dynamic> json) {
    return FlashcardGenerationItem(
      frontText: json['frontText'] as String,
      backText: json['backText'] as String,
      sourceLocation: json['sourceLocation'] as String,
      difficulty: DifficultyLevelJson.fromJson(json['difficulty'] as String),
    );
  }
}

/// The Worker's successful `/generate` response for `type: "flashcard"`.
/// [note] mirrors the Quiz feature's [GenerationResult.note] — the Worker
/// sends one on every response type (fewer items than requested, or some
/// grounding-check discards), meant to be shown to the student directly
/// rather than treated as an error. Not yet wired into the Setup screen's
/// UI (out of scope for this pass); the field exists so that data isn't
/// silently dropped on the floor once something does read it.
class FlashcardGenerationResult {
  FlashcardGenerationResult({required this.items, this.note});

  final List<FlashcardGenerationItem> items;
  final String? note;
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
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
    Uri? endpoint,
  }) : _firestoreOverride = firestore,
       _httpClient = httpClient ?? http.Client(),
       _idTokenProvider = idTokenProvider ?? AuthService().getIdToken,
       _endpoint =
           endpoint ??
           Uri.parse('https://tadarab-ai-worker.tadarab.workers.dev/generate');

  final String uid;
  final String courseId;
  final FirebaseFirestore? _firestoreOverride;
  final http.Client _httpClient;

  /// Resolves the caller's Firebase ID token for the Worker's
  /// Authorization: Bearer header. Defaults to [AuthService.getIdToken] —
  /// overridable so tests never need a real Firebase app to exercise the
  /// HTTP layer (same pattern as [QuizGenerationClient]'s
  /// `idTokenProvider`, in quiz_generation_client.dart).
  final Future<String?> Function() _idTokenProvider;
  final Uri _endpoint;

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

  /// Calls the Cloudflare Worker's `POST /generate` (type: "flashcard") —
  /// the same deployed Worker and endpoint Quiz's [QuizGenerationClient]
  /// calls (see quiz_generation_client.dart), which already handles
  /// `type: "flashcard"` requests identically to `type: "quiz"` ones (same
  /// generation.js, branches on `type` throughout). Re-fetches this
  /// course's materials to get each selected one's real `extractedText`,
  /// rather than requiring the caller to pass full [StudyMaterial] objects
  /// through — [FlashcardSetupScreen] already calls this with just
  /// [materialIds], and changing that call site wasn't needed.
  ///
  /// Throws [WorkerUnreachableException] (no response at all — offline,
  /// timeout, DNS failure, or no signed-in user to get a token from) or
  /// [WorkerResponseException] (the Worker responded, but not with a
  /// usable 200) — never a raw exception, so the Setup screen's existing
  /// `on WorkerUnreachableException` / generic `catch` both work correctly.
  Future<FlashcardGenerationResult> generateFlashcards({
    required List<String> materialIds,
    required List<DifficultyLevel> difficulties,
    required int count,
    String? customPrompt,
  }) async {
    final allMaterials = await fetchMaterials();
    final materials = allMaterials
        .where((m) => materialIds.contains(m.materialId))
        .toList();

    String? token;
    try {
      token = await _idTokenProvider();
    } catch (_) {
      token = null;
    }
    if (token == null) {
      // No signed-in user to get a token from — can't even attempt the
      // call. Practically unreachable (the whole app requires sign-in
      // before this screen exists), but guarded the same way Quiz's
      // QuizGenerationClient.generateQuiz guards it, for the same reason:
      // fail locally instead of sending an obviously-invalid request.
      throw WorkerUnreachableException();
    }

    http.Response response;
    try {
      response = await _httpClient
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'type': 'flashcard',
              'count': count,
              'difficulty': difficulties.map((d) => d.toJson()).toList(),
              if (customPrompt != null && customPrompt.trim().isNotEmpty)
                'customPrompt': customPrompt.trim(),
              'materials': [
                for (final m in materials)
                  {'title': m.title, 'sourceText': m.extractedText},
              ],
            }),
          )
          .timeout(const Duration(seconds: 120));
    } catch (_) {
      throw WorkerUnreachableException();
    }

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200 || body == null || body['items'] is! List) {
      throw WorkerResponseException(response.statusCode, body);
    }

    final items = (body['items'] as List)
        .map(
          (raw) => FlashcardGenerationItem.fromJson(raw as Map<String, dynamic>),
        )
        .toList();

    return FlashcardGenerationResult(items: items, note: body['note'] as String?);
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
