import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../features/flashcards/logic/flashcard_logic.dart';
import '../models/enums.dart';
import '../models/flashcard.dart';
import '../models/flashcard_session.dart';
import '../models/session.dart';
import '../models/study_material.dart';
import '../utils/rank.dart';
import 'auth_service.dart';
import 'generation_topics.dart';
import 'streak_service.dart';

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
/// rather than treated as an error. [requestedCount] is the count the
/// caller asked for, carried alongside [items] so a screen can tell
/// whether generation fell short without needing to keep its own copy.
class FlashcardGenerationResult {
  FlashcardGenerationResult({
    required this.items,
    required this.requestedCount,
    this.note,
    this.coveredTopics = const [],
  });

  final List<FlashcardGenerationItem> items;
  final int requestedCount;
  final String? note;

  /// Short topic strings the Worker reports this batch actually covered —
  /// stored on the session so a future retake of it can send them back as
  /// `previousTopics`. Empty if the Worker's response omitted it.
  final List<String> coveredTopics;
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
    StreakService? streakService,
  }) : _firestoreOverride = firestore,
       _httpClient = httpClient ?? http.Client(),
       _idTokenProvider = idTokenProvider ?? AuthService().getIdToken,
       _endpoint =
           endpoint ??
           Uri.parse('https://tadarab-ai-worker.tadarab.workers.dev/generate'),
       _streakService = streakService ?? StreakService();

  final String uid;
  final String courseId;
  final FirebaseFirestore? _firestoreOverride;
  final http.Client _httpClient;
  final StreakService _streakService;

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
  /// [isRetake] tells the Worker this is a retake of a previous attempt
  /// with the same settings, same as [QuizGenerationClient.generateQuiz] —
  /// see [retake], its only caller that passes `true`.
  Future<FlashcardGenerationResult> generateFlashcards({
    required List<String> materialIds,
    required List<DifficultyLevel> difficulties,
    required int count,
    String? customPrompt,
    bool isRetake = false,
    List<String> previousTopics = const [],
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
              'isRetake': isRetake,
              if (isRetake && previousTopics.isNotEmpty)
                'previousTopics': previousTopics,
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

    return FlashcardGenerationResult(
      items: items,
      requestedCount: count,
      note: body['note'] as String?,
      coveredTopics: parseCoveredTopics(body['coveredTopics']),
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
  /// Worker — same settings as the source session (materials/difficulties/
  /// count/customPrompt, all supplied by the caller, which already has them
  /// from the session doc) plus `isRetake: true` and `previousTopics` (the
  /// source session's own stored [FlashcardSession.coveredTopics], never a
  /// union across the rest of the retake group — see [buildPreviousTopics])
  /// — then creates a brand-new [FlashcardSession] document for the result,
  /// sharing the source's `rootSessionId` and pointing `retakeOfSessionId`
  /// at it. The source session and its existing cards are never written to
  /// or deleted: a retake no longer overwrites, it adds a new entry to the
  /// same retake group.
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

    final result = await generateFlashcards(
      materialIds: materialIds,
      difficulties: difficulties,
      count: count,
      customPrompt: customPrompt,
      isRetake: true,
      previousTopics: previousTopics,
    );

    if (result.items.isEmpty) {
      throw FlashcardFailure(
        result.note ??
            "Your material couldn't support any flashcards. Try adding "
                'another material.',
      );
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
