import 'dart:async';

import 'package:tadarab_app/features/flashcards/logic/flashcard_logic.dart';
import 'package:tadarab_app/models/enums.dart';
import 'package:tadarab_app/models/flashcard.dart';
import 'package:tadarab_app/models/flashcard_session.dart';
import 'package:tadarab_app/models/study_material.dart';
import 'package:tadarab_app/services/flashcard_service.dart';

/// A controllable stand-in for [FlashcardService] used across the
/// Flashcards feature's widget tests, so they never depend on a real
/// Firestore or the (still-unimplemented) Worker call.
class FakeFlashcardService extends FlashcardService {
  FakeFlashcardService({
    this.materials = const [],
    this.sessions = const [],
    this.flashcardsBySessionId = const {},
    this.generationResult,
    this.generationError,
    this.createdSessionId = 'session-new',
    this.writeError,
    this.pendingGeneration,
    this.watchSessionsError,
    this.retakeResult,
    this.pendingRetake,
  }) : super(uid: 'uid-1', courseId: 'course-1');

  List<StudyMaterial> materials;
  List<FlashcardSession> sessions;
  Map<String, List<Flashcard>> flashcardsBySessionId;
  FlashcardGenerationResult? generationResult;
  Object? generationError;
  String createdSessionId;

  /// Thrown by every write method (createSession/markFlashcard/
  /// completeSession/retake/deleteSession) when set, to test retry paths.
  FlashcardFailure? writeError;

  /// When set, `generateFlashcards` awaits this instead of resolving
  /// immediately — lets a test observe the Generating overlay before
  /// completing generation itself.
  Completer<FlashcardGenerationResult>? pendingGeneration;

  /// When set, `watchSessions()` emits this as a stream error instead of
  /// [sessions] — e.g. to simulate a Firestore `failed-precondition` from a
  /// missing composite index.
  Object? watchSessionsError;

  /// `retake`'s result when it succeeds (and [pendingRetake]/[writeError]
  /// are both unset) — defaults to a clean, no-shortfall outcome.
  RetakeOutcome? retakeResult;

  /// When set, `retake` awaits this instead of resolving immediately —
  /// lets a test observe the Sessions screen's loading state before the
  /// (real) Worker call would resolve.
  Completer<RetakeOutcome>? pendingRetake;

  int fetchMaterialsCalls = 0;
  int generateFlashcardsCalls = 0;
  int createSessionCalls = 0;
  int markFlashcardCalls = 0;
  int completeSessionCalls = 0;
  int retakeCalls = 0;
  int deleteSessionCalls = 0;

  List<String>? lastGenerateMaterialIds;
  List<DifficultyLevel>? lastGenerateDifficulties;
  int? lastGenerateCount;
  String? lastGenerateCustomPrompt;
  bool? lastGenerateIsRetake;

  List<String>? lastCreateSessionMaterialIds;
  List<String>? lastCreateSessionMaterialTitles;
  ReviewStatus? lastMarkedStatus;
  String? lastDeletedSessionId;
  String? lastRetakenSessionId;
  List<String>? lastRetakeMaterialIds;
  List<DifficultyLevel>? lastRetakeDifficulties;
  int? lastRetakeCount;
  String? lastRetakeCustomPrompt;

  @override
  Future<List<StudyMaterial>> fetchMaterials() async {
    fetchMaterialsCalls++;
    return materials;
  }

  // Broadcasts [sessions] after it's mutated (e.g. by [deleteSession]) to
  // every currently-open watchSessions() stream — mirrors the real
  // FlashcardService.watchSessions()'s live Firestore snapshot behavior,
  // so a test can delete a session and see the Sessions screen's
  // StreamBuilder reactively pick up the new list without needing a
  // manual retry. Added for the Retake Stacks "delete down to one"
  // widget tests; existing tests that never mutate `sessions` see no
  // behavior change — each watchSessions() call still just emits the
  // current snapshot immediately.
  final StreamController<List<FlashcardSession>> _sessionUpdates =
      StreamController<List<FlashcardSession>>.broadcast();

  @override
  Stream<List<FlashcardSession>> watchSessions() {
    if (watchSessionsError != null) return Stream.error(watchSessionsError!);
    return _watchSessions();
  }

  // An async* generator yields its first value with the same (short)
  // timing as the plain `Stream.value(sessions)` this used to be — unlike a
  // StreamController-based stream, which needs enough extra microtask hops
  // that a caller doing `await watchSessions().first` right after a
  // fire-and-forget tap (home_screen.dart's Resume flow) could still be
  // waiting when a widget test's `pumpAndSettle()` already decided nothing
  // was scheduled and stopped pumping. Confirmed by reproducing that exact
  // regression against `test/screens/home_screen_test.dart` with a
  // StreamController-based implementation, which left the awaited Future
  // resolving well after the test had already finished and failed.
  Stream<List<FlashcardSession>> _watchSessions() async* {
    yield sessions;
    yield* _sessionUpdates.stream;
  }

  @override
  Future<FlashcardGenerationResult> generateFlashcards({
    required List<String> materialIds,
    required List<DifficultyLevel> difficulties,
    required int count,
    String? customPrompt,
    bool isRetake = false,
    List<String> previousTopics = const [],
  }) async {
    generateFlashcardsCalls++;
    lastGenerateMaterialIds = materialIds;
    lastGenerateDifficulties = difficulties;
    lastGenerateCount = count;
    lastGenerateCustomPrompt = customPrompt;
    lastGenerateIsRetake = isRetake;
    if (pendingGeneration != null) return pendingGeneration!.future;
    if (generationError != null) throw generationError!;
    return generationResult!;
  }

  @override
  Future<String> createSession({
    required String email,
    required List<String> materialIds,
    required List<String> materialTitles,
    required List<DifficultyLevel> difficultyLevels,
    String? customPrompt,
    required List<FlashcardGenerationItem> items,
    List<String> coveredTopics = const [],
  }) async {
    createSessionCalls++;
    lastCreateSessionMaterialIds = materialIds;
    lastCreateSessionMaterialTitles = materialTitles;
    if (writeError != null) throw writeError!;
    return createdSessionId;
  }

  @override
  Future<List<Flashcard>> fetchFlashcards(String sessionId) async {
    return flashcardsBySessionId[sessionId] ?? const [];
  }

  @override
  Future<void> markFlashcard({
    required String sessionId,
    required String flashcardId,
    required ReviewStatus status,
    required int currentFlashcardIndex,
    required int knownCount,
    required int needsReviewCount,
  }) async {
    markFlashcardCalls++;
    lastMarkedStatus = status;
    if (writeError != null) throw writeError!;
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required String flashcardId,
    required ReviewStatus status,
    required int finalIndex,
    required int knownCount,
    required int needsReviewCount,
    required DateTime completedAt,
  }) async {
    completeSessionCalls++;
    lastMarkedStatus = status;
    if (writeError != null) throw writeError!;
  }

  @override
  Future<RetakeOutcome> retake({
    required String sessionId,
    required List<String> materialIds,
    required List<DifficultyLevel> difficulties,
    required int count,
    String? customPrompt,
  }) async {
    retakeCalls++;
    lastRetakenSessionId = sessionId;
    lastRetakeMaterialIds = materialIds;
    lastRetakeDifficulties = difficulties;
    lastRetakeCount = count;
    lastRetakeCustomPrompt = customPrompt;
    if (pendingRetake != null) return pendingRetake!.future;
    if (writeError != null) throw writeError!;
    return retakeResult ??
        (
          requestedCount: count,
          actualCount: count,
          note: null,
          newSessionId: createdSessionId,
        );
  }

  @override
  Future<void> deleteSession({required String sessionId}) async {
    deleteSessionCalls++;
    lastDeletedSessionId = sessionId;
    if (writeError != null) throw writeError!;
    sessions = sessions.where((s) => s.sessionId != sessionId).toList();
    _sessionUpdates.add(sessions);
  }
}
