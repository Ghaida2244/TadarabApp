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

  @override
  Stream<List<FlashcardSession>> watchSessions() {
    if (watchSessionsError != null) return Stream.error(watchSessionsError!);
    return Stream.value(sessions);
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
  }
}
